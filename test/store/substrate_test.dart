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

    test(
      'INSERT OR REPLACE on pool_facts raises and leaves the row unchanged',
      () async {
        final id = const Uuid().v7();
        await store.appendPoolFact(_fact(id: id));
        await expectLater(
          db.customUpdate(
            "INSERT OR REPLACE INTO pool_facts "
            "(id, origin, size, instant_utc_micros, offset_seconds) "
            "VALUES (?, 'cloud', 'focus', 1, 0)",
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
      },
    );

    test(
      'INSERT OR REPLACE on log_entries raises and leaves the row unchanged',
      () async {
        final id = const Uuid().v7();
        await store.appendLogEntry(_entry(id: id));
        await expectLater(
          db.customUpdate(
            "INSERT OR REPLACE INTO log_entries "
            "(id, kind, instant_utc_micros, offset_seconds) "
            "VALUES (?, 'card_skipped', 1, 0)",
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
      },
    );
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

  group('ordered read snapshots (Story 1.6)', () {
    LogEntryRecord at(int micros, String id) => (
      id: id,
      kind: 'card_dealt',
      instantUtcMicros: micros,
      offsetSeconds: 7200,
      itemId: null,
      itemOrigin: null,
      stack: null,
    );

    test(
      'the instant tie-break is append sequence, never id order (AD-3) — '
      'same-instant rows appended in reverse id order replay appended-first',
      () async {
        // Deliberately reverse-lexicographic ids: an ORDER BY id — the
        // exact thing AD-3 bans — would return them sorted and keep
        // this suite green; append sequence must win instead.
        await store.appendLogEntry(at(500, 'zz-appended-first'));
        await store.appendLogEntry(at(500, 'aa-appended-second'));
        final logSnapshot = await store.readLogEntries();
        expect(logSnapshot.map((row) => row.id).toList(), [
          'zz-appended-first',
          'aa-appended-second',
        ]);

        Future<void> fact(String id) => store.appendPoolFact((
          id: id,
          origin: Origin.manual,
          size: Size.maintenance,
          instantUtcMicros: 500,
          offsetSeconds: 7200,
        ));

        await fact('zz-fact-appended-first');
        await fact('aa-fact-appended-second');
        final poolSnapshot = await store.readPoolFacts();
        expect(poolSnapshot.map((row) => row.id).toList(), [
          'zz-fact-appended-first',
          'aa-fact-appended-second',
        ]);
      },
    );

    test('readLogEntries replays by recorded instant, append order breaking '
        'ties (AD-3)', () async {
      await store.appendLogEntry(at(300, 'third'));
      await store.appendLogEntry(at(100, 'first'));
      // One shell batch mints one instant for several records: the tie
      // breaks by append sequence, never by id bits.
      await store.appendLogEntry(at(200, 'tie-early'));
      await store.appendLogEntry(at(200, 'tie-late'));

      final snapshot = await store.readLogEntries();
      expect(snapshot.map((row) => row.id).toList(), [
        'first',
        'tie-early',
        'tie-late',
        'third',
      ]);
      expect(snapshot.every((row) => row.offsetSeconds == 7200), isTrue);
    });

    test('a malformed record round-trips verbatim — never coerced (AD-23: '
        'validation is the core\'s read boundary)', () async {
      // Half item pair: the adapter returns it exactly as appended.
      await store.appendLogEntry((
        id: 'half-pair',
        kind: 'card_done',
        instantUtcMicros: 100,
        offsetSeconds: 0,
        itemId: 'man-a',
        itemOrigin: null,
        stack: null,
      ));
      // stack on a moment kind.
      await store.appendLogEntry((
        id: 'stack-off-kind',
        kind: 'session_started',
        instantUtcMicros: 200,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: '#0      build',
      ));
      // An unknown kind.
      await store.appendLogEntry((
        id: 'unknown-kind',
        kind: 'future_kind',
        instantUtcMicros: 300,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
      ));

      final snapshot = await store.readLogEntries();
      expect(snapshot, hasLength(3));
      expect(snapshot[0].id, 'half-pair');
      expect(snapshot[0].itemId, 'man-a');
      expect(snapshot[0].itemOrigin, isNull);
      expect(snapshot[1].id, 'stack-off-kind');
      expect(snapshot[1].stack, '#0      build');
      expect(snapshot[2].id, 'unknown-kind');
      expect(snapshot[2].kind, 'future_kind');
    });

    test('an origin token this build does not know reads back '
        'uninterpretable, never fatal', () async {
      await db.customInsert(
        'INSERT INTO log_entries '
        '(id, kind, instant_utc_micros, offset_seconds, item_id, '
        'item_origin, stack) '
        "VALUES ('future-origin', 'card_done', 100, 0, 'man-a', "
        "'future_origin', NULL)",
      );
      final snapshot = await store.readLogEntries();
      expect(snapshot, hasLength(1));
      expect(snapshot.single.itemId, 'man-a');
      expect(
        snapshot.single.itemOrigin,
        isNull,
        reason:
            'the enum-typed record cannot carry an unknown token — the '
            'core boundary rejects the resulting half pair distinctly',
      );
    });

    test('readPoolFacts replays ordered, verbatim', () async {
      Future<void> fact(String id, int micros) => store.appendPoolFact((
        id: id,
        origin: Origin.manual,
        size: Size.maintenance,
        instantUtcMicros: micros,
        offsetSeconds: 7200,
      ));

      await fact('late', 300);
      await fact('early', 100);
      await fact('tie', 100);

      final snapshot = await store.readPoolFacts();
      expect(snapshot.map((row) => row.id).toList(), ['early', 'tie', 'late']);
      expect(snapshot.first.origin, Origin.manual);
      expect(snapshot.first.size, Size.maintenance);
    });

    test('a pool row whose size token this build does not know stays outside '
        'the snapshot', () async {
      await store.appendPoolFact((
        id: 'known',
        origin: Origin.manual,
        size: Size.maintenance,
        instantUtcMicros: 100,
        offsetSeconds: 0,
      ));
      await db.customInsert(
        'INSERT INTO pool_facts '
        '(id, origin, size, instant_utc_micros, offset_seconds) '
        "VALUES ('unknown', 'manual', 'gigantic', 200, 0)",
      );
      final snapshot = await store.readPoolFacts();
      expect(snapshot.map((row) => row.id), ['known']);
    });
  });

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
