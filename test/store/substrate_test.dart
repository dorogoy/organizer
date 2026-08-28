import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/store_port.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/store/drift_store.dart';
import 'package:organizer/store/substrate.dart';

SubstrateDatabase _open() => SubstrateDatabase(NativeDatabase.memory());

PoolFactRecord _fact({String? id}) => (
  id: id ?? const Uuid().v7(),
  origin: Origin.manual,
  size: Size.maintenance,
  instantUtcMicros: 1758900000123456,
  offsetSeconds: 7200,
);

LogEntryRecord _entry({String? id, String kind = 'card_done'}) => (
  id: id ?? const Uuid().v7(),
  kind: kind,
  instantUtcMicros: 1758900000654321,
  offsetSeconds: 7200,
  itemId: '0192cccc-0000-7000-8000-000000000001',
  itemOrigin: Origin.shipped,
  stack: null,
);

Future<List<String>> _objects(SubstrateDatabase db, String type) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = ? AND name NOT LIKE 'sqlite_%'",
        variables: [Variable.withString(type)],
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toList()..sort();
}

void main() {
  late SubstrateDatabase db;
  late DriftStore store;

  setUp(() {
    db = _open();
    store = DriftStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'a fresh install holds exactly two tables and the four triggers',
    () async {
      await store.appendPoolFact(_fact());
      expect(await _objects(db, 'table'), ['log_entries', 'pool_facts']);
      expect(await _objects(db, 'trigger'), [
        'log_entries_refuse_delete',
        'log_entries_refuse_update',
        'pool_facts_refuse_delete',
        'pool_facts_refuse_update',
      ]);
    },
  );

  test('inserts succeed on both tables and carry id, origin, size, instant + offset', () async {
    final factId = const Uuid().v7();
    await store.appendPoolFact(_fact(id: factId));
    final entryId = const Uuid().v7();
    await store.appendLogEntry(_entry(id: entryId));

    final factRow = await (db.select(
      db.poolFacts,
    )..where((row) => row.id.equals(factId))).getSingle();
    expect(factRow.id, factId);
    expect(factRow.origin, 'manual');
    expect(factRow.size, 'maintenance');
    expect(factRow.instantUtcMicros, 1758900000123456);
    expect(factRow.offsetSeconds, 7200);

    final entryRow = await (db.select(
      db.logEntries,
    )..where((row) => row.id.equals(entryId))).getSingle();
    expect(entryRow.id, entryId);
    expect(entryRow.kind, 'card_done');
    expect(entryRow.instantUtcMicros, 1758900000654321);
    expect(entryRow.offsetSeconds, 7200);
    expect(entryRow.itemId, '0192cccc-0000-7000-8000-000000000001');
    expect(entryRow.itemOrigin, 'shipped');
    expect(entryRow.stack, isNull);
  });

  test('a UUIDv7 id is the text primary key of both tables', () async {
    final v7 = RegExp(
      '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$',
    );
    final factId = const Uuid().v7();
    final entryId = const Uuid().v7();
    await store.appendPoolFact(_fact(id: factId));
    await store.appendLogEntry(_entry(id: entryId));
    expect(factId, matches(v7));
    expect(entryId, matches(v7));
    expect(
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM pool_facts WHERE id = ?',
                variables: [Variable.withString(factId)],
              )
              .getSingle())
          .read<int>('n'),
      1,
    );
  });

  group('the database refuses rewrites on both tables (AD-2)', () {
    test('UPDATE on pool_facts raises and leaves the row unchanged', () async {
      final id = const Uuid().v7();
      await store.appendPoolFact(_fact(id: id));
      await expectLater(
        db.customUpdate(
          "UPDATE pool_facts SET origin = 'cloud' WHERE id = ?",
          variables: [Variable.withString(id)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );
      final row = await (db.select(
        db.poolFacts,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.origin, 'manual');
    });

    test('DELETE on pool_facts raises and leaves the row unchanged', () async {
      final id = const Uuid().v7();
      await store.appendPoolFact(_fact(id: id));
      await expectLater(
        db.customUpdate(
          'DELETE FROM pool_facts WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );
      final count =
          (await db
                  .customSelect(
                    'SELECT COUNT(*) AS n FROM pool_facts WHERE id = ?',
                    variables: [Variable.withString(id)],
                  )
                  .getSingle())
              .read<int>('n');
      expect(count, 1);
    });

    test('UPDATE on log_entries raises and leaves the row unchanged', () async {
      final id = const Uuid().v7();
      await store.appendLogEntry(_entry(id: id));
      await expectLater(
        db.customUpdate(
          "UPDATE log_entries SET kind = 'card_skipped' WHERE id = ?",
          variables: [Variable.withString(id)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );
      final row = await (db.select(
        db.logEntries,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.kind, 'card_done');
    });

    test('DELETE on log_entries raises and leaves the row unchanged', () async {
      final id = const Uuid().v7();
      await store.appendLogEntry(_entry(id: id));
      await expectLater(
        db.customUpdate(
          'DELETE FROM log_entries WHERE id = ?',
          variables: [Variable.withString(id)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );
      final count =
          (await db
                  .customSelect(
                    'SELECT COUNT(*) AS n FROM log_entries WHERE id = ?',
                    variables: [Variable.withString(id)],
                  )
                  .getSingle())
              .read<int>('n');
      expect(count, 1);
    });
  });

  test(
    'an unknown log kind is stored verbatim — carried, never fatal (AD-23)',
    () async {
      final id = const Uuid().v7();
      await store.appendLogEntry(_entry(id: id, kind: 'future_kind'));
      final row = await (db.select(
        db.logEntries,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.kind, 'future_kind');
    },
  );

  test(
    'a crash-shaped log entry round-trips through the adapter (AD-12)',
    () async {
      const stack =
          '#0      build (package:organizer/x.dart:9)\n'
          '#1      main (package:organizer/main.dart:23)';
      final id = const Uuid().v7();
      await store.appendLogEntry((
        id: id,
        kind: LogKind.crashRecorded.name,
        instantUtcMicros: 1758900000999999,
        offsetSeconds: -1800,
        itemId: null,
        itemOrigin: null,
        stack: stack,
      ));
      final row = await (db.select(
        db.logEntries,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.kind, 'crash_recorded');
      expect(row.stack, stack);
      expect(row.itemId, isNull);
      expect(row.itemOrigin, isNull);
    },
  );

  group('column audit: no owner column, no date-only column (AD-1)', () {
    Future<List<String>> columns(String table) => db
        .customSelect('PRAGMA table_info($table)')
        .get()
        .then(
          (rows) =>
              rows.map((row) => row.read<String>('name')).toList()..sort(),
        );

    test('pool_facts holds exactly its five declared columns', () async {
      await store.appendPoolFact(_fact());
      expect(await columns('pool_facts'), [
        'id',
        'instant_utc_micros',
        'offset_seconds',
        'origin',
        'size',
      ]);
    });

    test('log_entries holds exactly its seven declared columns', () async {
      await store.appendLogEntry(_entry());
      expect(await columns('log_entries'), [
        'id',
        'instant_utc_micros',
        'item_id',
        'item_origin',
        'kind',
        'offset_seconds',
        'stack',
      ]);
    });
  });
}
