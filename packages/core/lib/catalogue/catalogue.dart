/// The shipped Evergreen catalogue contract (AD-16): a versioned,
/// read-only JSON asset whose entries each carry exactly four fields — a
/// permanent kebab-case id, a size from the 1-3-5 taxonomy, a cadence, and
/// a zone-or-none (weekly entries carry one; no other cadence does,
/// A12.4). The Spanish task name is deliberately not in the asset; it is
/// an ARB entry keyed by the id (AD-15), resolved by the named shell
/// loader at load time and handed to the core alongside the four fields,
/// as inert data.
///
/// The parser is pure (AD-3, AD-5): it takes a String and an injectable
/// name resolver, touches no ambient source, and either returns inert
/// entries or throws a [FormatException] naming the entry id and the
/// offending field. Ids are permanent once shipped (AD-23) — uniqueness is
/// therefore structural, and a duplicate fails the parse.

library;

import 'dart:convert';

import 'package:core/pool/pool_fact.dart';

import 'strict_json.dart';

/// The three cadences a shipped entry recurs on (FR-31, A12): daily
/// anchors and upkeep, weekly zone routines, monthly/seasonal depth work.
enum Cadence {
  /// Anchors and Baseline Upkeep — every day, no zone.
  daily,

  /// Zone routines — exactly one FlyLady zone active per day (A12.4).
  weekly,

  /// The `fondo` cluster — monthly and seasonal depth work (A12.5).
  seasonal,
}

/// The five weekly zones (A12.4). Daily and seasonal entries carry none.
enum Zone { z1, z2, z3, z4, z5 }

/// One inert catalogue entry: the four asset fields plus the Spanish name
/// the shell loader resolved at load time (AD-16). Nothing here is ever
/// written back; the asset is read-only by construction.
final class CatalogueEntry {
  const CatalogueEntry({
    required this.id,
    required this.size,
    required this.cadence,
    required this.name,
    this.zone,
  });

  /// The permanent kebab-case Spanish slug — AD-3's least-recently-dealt
  /// tie-break and AD-23's id-continuity check both need this stable
  /// referent. Never rendered, never enumerated, never reaches a surface.
  final String id;

  /// The 1-3-5 taxonomy size (FR-27) — the Focus Chunk is the "1",
  /// Micro-maintenance the "3", Instant Habits the "5".
  final Size size;

  final Cadence cadence;

  /// The weekly zone, or absent for daily and seasonal entries.
  final Zone? zone;

  /// The resolved Spanish name (AD-15): the entry's ARB value, handed over
  /// as inert data by the shell loader.
  final String name;
}

/// A parsed catalogue: the asset version plus its entries, in asset order.
final class Catalogue {
  Catalogue({required this.version, required List<CatalogueEntry> entries})
    : entries = List.unmodifiable(entries);

  final int version;

  /// Unmodifiable: the catalogue is read-only by construction (AD-16), so
  /// a mutation attempt throws instead of drifting a copy.
  final List<CatalogueEntry> entries;
}

const Set<String> _topLevelFields = {'version', 'entries'};
const Set<String> _sizeTokens = {'instant', 'maintenance', 'focus'};
const Set<String> _cadenceTokens = {'daily', 'weekly', 'seasonal'};
const Set<String> _zoneTokens = {'z1', 'z2', 'z3', 'z4', 'z5'};
const Set<String> _entryFields = {'id', 'size', 'cadence', 'zone'};

/// The permanent id grammar: a kebab-case slug of lowercase words and
/// digits, single inner hyphens, none leading or trailing.
final RegExp _idGrammar = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Parses the shipped catalogue asset (AD-16).
///
/// Validates the top-level shape — exactly `version` (1) and `entries` —
/// each entry's exact field set (`id`, `size`, `cadence`, plus `zone` on a
/// weekly entry and absent otherwise), the token domains of `size`,
/// `cadence` and `zone`, the kebab-case id grammar, and id uniqueness.
/// Every failure throws a [FormatException]; entry-level failures start
/// with `entry "<id>":` and name the offending field — a wording the
/// build-time catalogue checks locate lines by, so it is a cross-tool
/// contract, not prose. Names are resolved through [nameOf] — ARB
/// knowledge stays shell-side while the entry the core receives already
/// carries its resolved name.
Catalogue parseCatalogue(
  String json, {
  required String Function(String id) nameOf,
}) {
  final decoded = strictJsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'catalogue asset top level is not a JSON object',
    );
  }
  final unknownTopLevel =
      decoded.keys.where((key) => !_topLevelFields.contains(key)).toList()
        ..sort();
  if (unknownTopLevel.isNotEmpty) {
    throw FormatException(
      'unknown top-level field "${unknownTopLevel.first}" — the asset '
      'holds exactly version and entries',
    );
  }
  final version = decoded['version'];
  if (version is! int || version != 1) {
    throw FormatException(
      'catalogue asset version must be 1, got ${jsonEncode(version)}',
    );
  }
  final rawEntries = decoded['entries'];
  if (rawEntries is! List) {
    throw const FormatException(
      'catalogue asset "entries" is not a JSON array',
    );
  }

  final entries = <CatalogueEntry>[];
  final seenIds = <String>{};
  for (var i = 0; i < rawEntries.length; i++) {
    final raw = rawEntries[i];
    if (raw is! Map<String, dynamic>) {
      throw FormatException('entry #$i is not a JSON object');
    }
    final label = _entryLabel(raw, i);

    final unexpected =
        raw.keys.where((key) => !_entryFields.contains(key)).toList()..sort();
    if (unexpected.isNotEmpty) {
      throw FormatException(
        'entry "$label": unknown field "${unexpected.first}" '
        '(an entry carries exactly id, size, cadence and zone-or-none)',
      );
    }
    for (final requiredField in const ['id', 'size', 'cadence']) {
      if (!raw.containsKey(requiredField)) {
        throw FormatException('entry "$label": missing field "$requiredField"');
      }
    }

    final id = raw['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException(
        'entry "$label": field "id" is not a non-empty string',
      );
    }
    if (!_idGrammar.hasMatch(id)) {
      throw FormatException(
        'entry "$id": field "id" is not a kebab-case slug (lowercase '
        'words and digits, single inner hyphens)',
      );
    }
    final size = raw['size'];
    if (size is! String || !_sizeTokens.contains(size)) {
      throw FormatException(
        'entry "$id": unknown size token ${jsonEncode(size)} '
        '(expected one of instant, maintenance, focus)',
      );
    }
    final cadence = raw['cadence'];
    if (cadence is! String || !_cadenceTokens.contains(cadence)) {
      throw FormatException(
        'entry "$id": unknown cadence token ${jsonEncode(cadence)} '
        '(expected one of daily, weekly, seasonal)',
      );
    }
    Zone? zone;
    if (raw.containsKey('zone')) {
      final rawZone = raw['zone'];
      if (rawZone is! String || !_zoneTokens.contains(rawZone)) {
        throw FormatException(
          'entry "$id": unknown zone token ${jsonEncode(rawZone)} '
          '(expected one of z1, z2, z3, z4, z5, or the field absent)',
        );
      }
      zone = Zone.values.byName(rawZone);
    }
    if (cadence == 'weekly' && zone == null) {
      throw FormatException(
        'entry "$id": missing field "zone" — a weekly entry carries one '
        '(A12.4)',
      );
    }
    if (cadence != 'weekly' && zone != null) {
      throw FormatException(
        'entry "$id": field "zone" is legal only on a weekly entry (A12.4)',
      );
    }

    if (!seenIds.add(id)) {
      throw FormatException('duplicate entry id "$id"');
    }
    entries.add(
      CatalogueEntry(
        id: id,
        size: Size.values.byName(size),
        cadence: Cadence.values.byName(cadence),
        zone: zone,
        name: nameOf(id),
      ),
    );
  }
  return Catalogue(version: version, entries: entries);
}

/// The name a failure reports: the entry's id when it is already readable,
/// otherwise the index — the id is the permanent referent, so it leads.
String _entryLabel(Map<String, dynamic> raw, int index) {
  final id = raw['id'];
  return id is String && id.isNotEmpty ? id : '#$index';
}
