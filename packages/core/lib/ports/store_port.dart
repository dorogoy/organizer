/// The store port: the core's only view of persisted facts.
///
/// Writes are deliberately append-only (Story 1.3): inserts of pool facts
/// and log entries, and nothing else — corrections are new entries, never
/// edits, and the database itself refuses `UPDATE` and `DELETE` on both
/// tables (AD-2). Reads (Story 1.6) are ordered snapshots of inert
/// records: the log and pool as they were appended, replayable inputs for
/// the derivations, never collection-shaped work surfaces (AD-6 — the one
/// work read is the facade's `nextCard()`).
///
/// Adapters return inert row shapes, never domain objects (AD-5): the
/// record DTOs below are primitives and enums only, and only the core
/// constructs domain objects from them.

library;

import 'package:core/pool/pool_fact.dart';

/// An inert pool-fact DTO: a shell-minted UUIDv7 id, the origin set at
/// genesis, the taxonomy size, and the creation instant plus the local
/// offset in force (AD-4, AD-14) — and, additively since schema v6
/// (Story 3.2), the nullable Origin Context: a manual capture's own
/// single line, null for origins whose context lives elsewhere.
/// Additively since schema v7 (Story 3.4), the nullable dictation
/// boolean: `true` whenever dictation authored the line, `false` when
/// the keyboard did, null on old rows. No owner, no date-only value.
typedef PoolFactRecord = ({
  String id,
  Origin origin,
  Size size,
  int instantUtcMicros,
  int offsetSeconds,
  String? originContext,
  bool? dictated,
});

/// An inert log-entry DTO: id, kind (as its wire name — unknown kinds are
/// carried verbatim, AD-23), the instant plus the local offset in force,
/// and — where a pool item is referenced — that item's id and origin
/// (AD-14). [stack] is the crash payload and is set only on
/// `crash_recorded`, which carries stack + timestamp and nothing else
/// (AD-12). [settingKey]/[settingValue] are the settings payload's key
/// and int value and are set only on `setting_changed`, additively since
/// schema v2 (AD-1, AD-23); [settingTextValue] is the payload's text
/// value (the selected AI provider's id) and is set only on
/// `setting_changed` too, additively since schema v8 (Story 4.3,
/// AD-22, AD-23) — a setting row carries exactly one of the two values,
/// never both, never neither. [pocketMinutes] is the declared pocket
/// and is set only on `session_started`, additively since schema v3
/// (Story 2.2, AD-19).
/// [energyLevel] is the tapped level's stable wire int (0/1/2) and is
/// set only on `energy_set`, additively since schema v4 (Story 2.5,
/// AD-4). [reportValue]/[reportWeek] are the weekly self-report's
/// payload — the tapped answer on SM-2's 1–5 scale and the answered
/// week's `Week.weekOrdinal` — and are set only on `report_answered`,
/// additively since schema v5 (Story 2.6, AD-21, AD-23). [permission]
/// is the refused permission's wire name (one of the three the core's
/// `Permission` enum names) and is set only on `permission_refused`,
/// additively since schema v7 (Story 3.4, AD-17, AD-23).
typedef LogEntryRecord = ({
  String id,
  String kind,
  int instantUtcMicros,
  int offsetSeconds,
  String? itemId,
  Origin? itemOrigin,
  String? stack,
  String? settingKey,
  int? settingValue,
  String? settingTextValue,
  int? pocketMinutes,
  int? energyLevel,
  int? reportValue,
  int? reportWeek,
  String? permission,
});

/// The pool-fact snapshot's domain objects, in snapshot order — the
/// records' one-to-one mapping into facts, the pool's own
/// `logEntriesOf` inverted to live here (`pool_fact.dart` cannot host
/// it: the fact would have to import its own record, a cycle through
/// this port). Nothing is validated: the record is field-identical to
/// the fact (AD-5), and a row this build could not parse never reached
/// the snapshot (the adapter excluded it at the read).
List<PoolFact> poolFactsOf(List<PoolFactRecord> records) => [
  for (final record in records)
    PoolFact(
      id: record.id,
      origin: record.origin,
      size: record.size,
      instantUtcMicros: record.instantUtcMicros,
      offsetSeconds: record.offsetSeconds,
      originContext: record.originContext,
      dictated: record.dictated,
    ),
];

abstract interface class StorePort {
  /// Appends one pool fact. Failing to append rejects the caller's act.
  Future<void> appendPoolFact(PoolFactRecord fact);

  /// Appends one log entry. Failing to append rejects the caller's act.
  Future<void> appendLogEntry(LogEntryRecord entry);

  /// Reads the pool-fact snapshot in replay order: by recorded instant,
  /// then append sequence — derivations read recorded act instants and
  /// never id bit patterns (AD-3). A row whose `origin` or `size` token
  /// this build cannot parse stays outside the snapshot: the enum-typed
  /// record cannot carry it, and the pool's first real writer is where
  /// AD-23's additive tolerance lands for these columns.
  Future<List<PoolFactRecord>> readPoolFacts();

  /// Reads the log-entry snapshot in replay order: by recorded instant,
  /// then append sequence — one shell batch mints one instant for several
  /// records, and append order breaks that tie. Records are inert and
  /// verbatim, malformed rows included: shape validation is the core's
  /// read boundary (AD-23), never the adapter's.
  Future<List<LogEntryRecord>> readLogEntries();
}
