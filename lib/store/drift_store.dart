import 'package:core/ports/store_port.dart';
import 'package:drift/drift.dart';

import 'substrate.dart';

/// The drift adapter over the insert-only substrate — the only module where
/// persistence APIs are legal (AD-21's store seal). Implements the port's
/// append-only surface; the database itself refuses anything else (AD-2).
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
}
