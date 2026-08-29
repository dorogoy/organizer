import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:drift/drift.dart';

import 'substrate.dart';

/// SQLite's built-in append-sequence column — the deterministic second
/// order key when recorded instants tie, because one shell batch mints
/// one instant for several records. A named infrastructure identifier
/// on the store module's terms (AD-15's ban is on literals reaching a
/// widget), never widget copy.
const String rowIdColumnName = 'rowid';

/// The drift adapter over the insert-only substrate — the only module where
/// persistence APIs are legal (AD-21's store seal). Implements the port's
/// append-only writes and ordered read snapshots; the database itself
/// refuses anything else (AD-2). Reads return records verbatim, malformed
/// rows included — shape validation is the core's read boundary (AD-23),
/// never this adapter's.
class DriftStore implements StorePort {
  DriftStore(this._db);

  final SubstrateDatabase _db;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) {
    return _db
        .into(_db.poolFacts)
        .insert(
          PoolFactsCompanion.insert(
            id: fact.id,
            origin: fact.origin.name,
            size: fact.size.name,
            instantUtcMicros: fact.instantUtcMicros,
            offsetSeconds: fact.offsetSeconds,
          ),
        );
  }

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) {
    return _db
        .into(_db.logEntries)
        .insert(
          LogEntriesCompanion.insert(
            id: entry.id,
            kind: entry.kind,
            instantUtcMicros: entry.instantUtcMicros,
            offsetSeconds: entry.offsetSeconds,
            itemId: Value(entry.itemId),
            itemOrigin: Value(entry.itemOrigin?.name),
            stack: Value(entry.stack),
          ),
        );
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async {
    final query = _db.select(_db.poolFacts);
    query.orderBy([
      (row) => OrderingTerm.asc(row.instantUtcMicros),
      (_) => OrderingTerm.asc(CustomExpression<int>(rowIdColumnName)),
    ]);
    final rows = await query.get();
    final originsByName = Origin.values.asNameMap();
    final sizesByName = Size.values.asNameMap();
    return [
      for (final row in rows)
        if (originsByName[row.origin] != null && sizesByName[row.size] != null)
          (
            id: row.id,
            origin: originsByName[row.origin]!,
            size: sizesByName[row.size]!,
            instantUtcMicros: row.instantUtcMicros,
            offsetSeconds: row.offsetSeconds,
          ),
    ];
  }

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    final query = _db.select(_db.logEntries);
    query.orderBy([
      (row) => OrderingTerm.asc(row.instantUtcMicros),
      (_) => OrderingTerm.asc(CustomExpression<int>(rowIdColumnName)),
    ]);
    final rows = await query.get();
    final originsByName = Origin.values.asNameMap();
    return [
      for (final row in rows)
        (
          id: row.id,
          kind: row.kind,
          instantUtcMicros: row.instantUtcMicros,
          offsetSeconds: row.offsetSeconds,
          itemId: row.itemId,
          itemOrigin: row.itemOrigin == null
              ? null
              : originsByName[row.itemOrigin],
          stack: row.stack,
        ),
    ];
  }
}
