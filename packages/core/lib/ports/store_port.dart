/// The store port: the core's only view of persisted facts.
///
/// Deliberately append-only — this is the port's first real surface (Story
/// 1.3): inserts of pool facts and log entries, and nothing else. Reads
/// (log and pool snapshots) wait for their first consumer (Story 1.6+); a
/// speculative read surface now would invite the collection-shaped reads
/// AD-6 exists to prevent. Corrections are new entries, never edits — the
/// database itself refuses `UPDATE` and `DELETE` on both tables (AD-2).
///
/// Adapters return inert row shapes, never domain objects (AD-5): the
/// record DTOs below are primitives and enums only, and only the core
/// constructs domain objects from them.

library;

import 'package:core/pool/pool_fact.dart';

/// An inert pool-fact DTO: a shell-minted UUIDv7 id, the origin set at
/// genesis, the taxonomy size, and the creation instant plus the local
/// offset in force (AD-4, AD-14). No owner, no date-only value.
typedef PoolFactRecord = ({
  String id,
  Origin origin,
  Size size,
  int instantUtcMicros,
  int offsetSeconds,
});

/// An inert log-entry DTO: id, kind (as its wire name — unknown kinds are
/// carried verbatim, AD-23), the instant plus the local offset in force,
/// and — where a pool item is referenced — that item's id and origin
/// (AD-14). [stack] is the crash payload and is set only on
/// `crash_recorded`, which carries stack + timestamp and nothing else
/// (AD-12).
typedef LogEntryRecord = ({
  String id,
  String kind,
  int instantUtcMicros,
  int offsetSeconds,
  String? itemId,
  Origin? itemOrigin,
  String? stack,
});

abstract interface class StorePort {
  /// Appends one pool fact. Failing to append rejects the caller's act.
  Future<void> appendPoolFact(PoolFactRecord fact);

  /// Appends one log entry. Failing to append rejects the caller's act.
  Future<void> appendLogEntry(LogEntryRecord entry);
}
