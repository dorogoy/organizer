// ignore_for_file: avoid_print
//
// The catalogue continuity check freezes every shipped id's complete
// immutable tuple. Additions are legal; changing or removing a shipped value
// is an explicit catalogue evolution, never a silent baseline rewrite.
import 'dart:convert';
import 'dart:io';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/catalogue/strict_json.dart';

import 'catalogue_shared.dart';
import 'check_core_purity.dart';
import 'gen_catalogue_lookup.dart' show arbPath, deriveCatalogueKey;

const String baselinePath = 'tool/catalogue_baseline.json';
const String assetPath = 'assets/evergreen/catalogue.json';

const Set<String> _sizeTokens = {'instant', 'maintenance', 'focus'};
const Set<String> _cadenceTokens = {'daily', 'weekly', 'seasonal'};
const Set<String> _zoneTokens = {'z1', 'z2', 'z3', 'z4', 'z5'};
const Set<String> _tupleFields = {'size', 'cadence', 'zone', 'name'};

typedef _Tuple = ({String size, String cadence, String? zone, String name});

int _lineForId(String text, String id) {
  final probe = text.indexOf('"$id"');
  return probe == -1 ? 1 : lineOf(text, probe);
}

/// Diffs the baseline tuples against the asset. [assetNames] is optional to
/// retain the two-path fixture API; production supplies the ARB-resolved
/// values and consequently also verifies Spanish name continuity.
List<Finding> diffBaseline({
  required String baselineFile,
  required String baselineSource,
  required String assetFile,
  required String assetSource,
  Map<String, String>? assetNames,
}) {
  final findings = <Finding>[];
  final asset = _assetTuples(assetFile, assetSource, assetNames, findings);
  if (asset == null) {
    return findings;
  }
  final baseline = _baselineTuples(baselineFile, baselineSource, findings);
  if (baseline == null) {
    return findings;
  }

  for (final id in baseline.keys.toList()..sort()) {
    final before = baseline[id]!;
    final after = asset[id];
    if (after == null) {
      findings.add(
        Finding(
          baselineFile,
          _lineForId(baselineSource, id),
          'entry "$id" disappeared from the asset — catalogue ids are '
          'permanent once shipped; record an approved catalogue evolution',
        ),
      );
      continue;
    }
    _compareField(
      findings,
      baselineFile,
      baselineSource,
      id,
      'size',
      before.size,
      after.size,
    );
    _compareField(
      findings,
      baselineFile,
      baselineSource,
      id,
      'cadence',
      before.cadence,
      after.cadence,
    );
    _compareField(
      findings,
      baselineFile,
      baselineSource,
      id,
      'zone',
      before.zone,
      after.zone,
    );
    if (assetNames != null) {
      _compareField(
        findings,
        baselineFile,
        baselineSource,
        id,
        'Spanish name',
        before.name,
        after.name,
      );
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

void _compareField(
  List<Finding> findings,
  String file,
  String source,
  String id,
  String field,
  Object? before,
  Object? after,
) {
  if (before == after) {
    return;
  }
  findings.add(
    Finding(
      file,
      _lineForId(source, id),
      'entry "$id" changed $field: baseline ${jsonEncode(before)} != asset '
      '${jsonEncode(after)} — record an approved catalogue evolution',
    ),
  );
}

Map<String, _Tuple>? _baselineTuples(
  String file,
  String source,
  List<Finding> findings,
) {
  final decoded = _decode(file, source, findings);
  if (decoded is! Map<String, dynamic>) {
    if (decoded != null) {
      findings.add(
        Finding(
          file,
          1,
          'baseline top level is not a JSON object of id → tuple',
        ),
      );
    }
    return null;
  }
  final tuples = <String, _Tuple>{};
  for (final id in decoded.keys.toList()..sort()) {
    final raw = decoded[id];
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference(_tupleFields).isNotEmpty ||
        raw.keys.length != _tupleFields.length) {
      findings.add(
        Finding(
          file,
          _lineForId(source, id),
          'entry "$id": baseline must carry exactly size, cadence, zone and name',
        ),
      );
      continue;
    }
    final size = raw['size'];
    final cadence = raw['cadence'];
    final zone = raw['zone'];
    final name = raw['name'];
    if (size is! String ||
        !_sizeTokens.contains(size) ||
        cadence is! String ||
        !_cadenceTokens.contains(cadence) ||
        (zone != null && (zone is! String || !_zoneTokens.contains(zone))) ||
        name is! String ||
        name.trim().isEmpty) {
      findings.add(
        Finding(
          file,
          _lineForId(source, id),
          'entry "$id": baseline tuple has an invalid size, cadence, zone, or Spanish name',
        ),
      );
      continue;
    }
    if ((cadence == 'weekly') != (zone != null)) {
      findings.add(
        Finding(
          file,
          _lineForId(source, id),
          'entry "$id": baseline weekly-zone coupling is invalid',
        ),
      );
      continue;
    }
    tuples[id] = (
      size: size,
      cadence: cadence,
      zone: zone as String?,
      name: name,
    );
  }
  return findings.isEmpty ? tuples : null;
}

Map<String, _Tuple>? _assetTuples(
  String file,
  String source,
  Map<String, String>? names,
  List<Finding> findings,
) {
  try {
    final catalogue = parseCatalogue(source, nameOf: (id) => names?[id] ?? '');
    return {
      for (final entry in catalogue.entries)
        entry.id: (
          size: entry.size.name,
          cadence: entry.cadence.name,
          zone: entry.zone?.name,
          name: entry.name,
        ),
    };
  } on StrictJsonFormatException catch (error) {
    findings.add(
      Finding(file, lineForFormatException(source, error), error.message),
    );
    return null;
  } on FormatException catch (error) {
    findings.add(
      Finding(file, lineForEntryError(source, error.message), error.message),
    );
    return null;
  }
}

Object? _decode(String file, String source, List<Finding> findings) {
  try {
    return strictJsonDecode(source);
  } on StrictJsonFormatException catch (error) {
    findings.add(
      Finding(file, lineForFormatException(source, error), error.message),
    );
    return null;
  }
}

Map<String, String>? _readAssetNames({
  required File asset,
  required File arb,
  required List<Finding> findings,
}) {
  if (!arb.existsSync()) {
    findings.add(
      Finding(
        arb.path,
        1,
        'production ARB is unavailable; Spanish name continuity cannot be verified',
      ),
    );
    return null;
  }
  final String source;
  try {
    source = arb.readAsStringSync();
  } on FileSystemException catch (error) {
    findings.add(
      Finding(
        arb.path,
        1,
        'production ARB is unreadable; Spanish name continuity cannot be verified ($error)',
      ),
    );
    return null;
  }
  final decoded = _decode(arb.path, source, findings);
  if (decoded is! Map<String, dynamic>) {
    if (decoded != null) {
      findings.add(Finding(arb.path, 1, 'ARB top level is not a JSON object'));
    }
    return null;
  }
  final names = <String, String>{};
  final entries = _assetTuples(
    asset.path,
    asset.readAsStringSync(),
    null,
    findings,
  );
  if (entries == null) {
    return null;
  }
  for (final id in entries.keys) {
    final key = deriveCatalogueKey(id);
    final name = decoded[key];
    if (name is! String || name.trim().isEmpty) {
      findings.add(
        Finding(
          arb.path,
          _lineForId(source, key),
          'derived ARB key "$key" must hold a non-blank string value',
        ),
      );
      continue;
    }
    names[id] = name;
  }
  return findings.isEmpty ? names : null;
}

bool _sameFile(File left, File right) =>
    left.resolveSymbolicLinksSync() == right.resolveSymbolicLinksSync();

File _productionArbFor(File asset) =>
    File('${asset.parent.parent.parent.path}/$arbPath');

/// Runs the check against explicit baseline and asset paths. The production
/// pair also loads the canonical ARB to freeze the resolved Spanish names.
Future<int> runCheck(
  String baseline,
  String asset, {
  String? productionArbPath,
}) async {
  final baselineFile = File(baseline);
  final assetFile = File(asset);
  if (!baselineFile.existsSync()) {
    stderr.writeln('baseline not found at $baseline');
    return 2;
  }
  if (!assetFile.existsSync()) {
    stderr.writeln('catalogue asset not found at $asset');
    return 2;
  }
  final bootstrapFindings = <Finding>[];
  final isProduction =
      productionArbPath != null ||
      (_sameFile(baselineFile, File(baselinePath)) &&
          _sameFile(assetFile, File(assetPath)));
  final names = isProduction
      ? _readAssetNames(
          asset: assetFile,
          arb: File(productionArbPath ?? _productionArbFor(assetFile).path),
          findings: bootstrapFindings,
        )
      : null;
  final findings = [
    ...bootstrapFindings,
    ...diffBaseline(
      baselineFile: baseline,
      baselineSource: baselineFile.readAsStringSync(),
      assetFile: asset,
      assetSource: assetFile.readAsStringSync(),
      assetNames: names,
    ),
  ];
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'catalogue id diff check FAILED: ${findings.length} finding(s) — ids and shipped tuples are immutable',
    );
    return 1;
  }
  print('catalogue id diff check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  final baseline = args.isNotEmpty ? args.first : baselinePath;
  final asset = args.length > 1 ? args[1] : assetPath;
  exit(await runCheck(baseline, asset));
}
