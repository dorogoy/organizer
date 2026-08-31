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

LogEntryRecord _entry({
  String? id,
  String kind = 'card_done',
  int? pocketMinutes,
  int? reportValue,
  int? reportWeek,
}) => (
  id: id ?? const Uuid().v7(),
  kind: kind,
  instantUtcMicros: 1758900000654321,
  offsetSeconds: 7200,
  itemId: '0192cccc-0000-7000-8000-000000000001',
  itemOrigin: Origin.shipped,
  stack: null,
  settingKey: null,
  settingValue: null,
  pocketMinutes: pocketMinutes,
  energyLevel: null,
  reportValue: reportValue,
  reportWeek: reportWeek,
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
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
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
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
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
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
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
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
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
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
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

    test('log_entries holds exactly its thirteen declared columns — the two '
        'nullable setting columns are schema v2\'s additive pair (Story '
        '2.1), the nullable pocket column is schema v3\'s (Story 2.2, '
        'AD-23), the nullable energy level column is schema v4\'s '
        '(Story 2.5) and the two nullable report columns are schema '
        'v5\'s additive pair (Story 2.6)', () async {
      await store.appendLogEntry(_entry());
      expect(await columns('log_entries'), [
        'energy_level',
        'id',
        'instant_utc_micros',
        'item_id',
        'item_origin',
        'kind',
        'offset_seconds',
        'pocket_minutes',
        'report_value',
        'report_week',
        'setting_key',
        'setting_value',
        'stack',
      ]);
    });

    test('a setting-shaped log entry round-trips through the adapter '
        '(Story 2.1)', () async {
      final id = const Uuid().v7();
      await store.appendLogEntry((
        id: id,
        kind: LogKind.settingChanged.name,
        instantUtcMicros: 1758900000111222,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: 'time_bag',
        settingValue: 25,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      final row = await (db.select(
        db.logEntries,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.kind, 'setting_changed');
      expect(row.settingKey, 'time_bag');
      expect(row.settingValue, 25);
      expect(row.itemId, isNull);

      final snapshot = await store.readLogEntries();
      expect(snapshot.single.settingKey, 'time_bag');
      expect(snapshot.single.settingValue, 25);
    });

    test('a pocketed session start round-trips through the adapter '
        '(Story 2.2) — the pocket rides only its own kind, verbatim '
        'whatever its value', () async {
      final id = const Uuid().v7();
      await store.appendLogEntry((
        id: id,
        kind: LogKind.sessionStarted.name,
        instantUtcMicros: 1758900000222333,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: 15,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      // An out-of-range pocket stays stored verbatim too — the entry
      // stays in the log and the derivation reads it as absent, never
      // a repair write (AD-23).
      await store.appendLogEntry(_entry(id: 'imported-90', pocketMinutes: 90));

      final rows = await store.readLogEntries();
      expect(rows.first.kind, 'session_started');
      expect(rows.first.pocketMinutes, 15);
      expect(rows.first.settingKey, isNull);
      expect(rows.last.id, 'imported-90');
      expect(rows.last.pocketMinutes, 90);
    });

    test('an energy row round-trips through the adapter (Story 2.5) — '
        'the level\'s stable wire int rides only its own kind, verbatim '
        'whatever its value', () async {
      final id = const Uuid().v7();
      await store.appendLogEntry((
        id: id,
        kind: LogKind.energySet.name,
        instantUtcMicros: 1758900000333444,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: 2,
        reportValue: null,
        reportWeek: null,
      ));
      // An out-of-range level stays stored verbatim too — the entry
      // stays in the log and the core's read boundary excludes it,
      // never a repair write (AD-23).
      await db.customInsert(
        'INSERT INTO log_entries '
        '(id, kind, instant_utc_micros, offset_seconds, energy_level) '
        "VALUES ('imported-9', 'energy_set', 100, 0, 9)",
      );

      final rows = await store.readLogEntries();
      // Replay order is by recorded instant: the raw-seeded 1970 row
      // leads, the appended row follows.
      expect(rows.first.id, 'imported-9');
      expect(rows.first.energyLevel, 9);
      expect(rows.last.kind, 'energy_set');
      expect(rows.last.energyLevel, 2);
      expect(rows.last.pocketMinutes, isNull);
    });

    test('an out-of-scale answer row rides both production layers — '
        'stored verbatim by DriftStore, then excluded by the core\'s '
        'read boundary as reportValueAbsent (Story 2.6, AD-23)', () async {
      // The composed path a future import or foreign build exercises:
      // the adapter stores what it is handed without judgment, and the
      // boundary — the only place with judgment — drops the row
      // quietly. Never a repair write anywhere.
      final id = const Uuid().v7();
      await store.appendLogEntry((
        id: id,
        kind: LogKind.reportAnswered.name,
        instantUtcMicros: 1758900000444555,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 9,
        reportWeek: 1394,
      ));

      final snapshot = await store.readLogEntries();
      expect(snapshot, hasLength(1));
      expect(snapshot.single.id, id);
      expect(snapshot.single.reportValue, 9);
      expect(snapshot.single.reportWeek, 1394);

      final conversion = convertLogEntryRecord(snapshot.single);
      expect(conversion.entry, isNull);
      expect(conversion.flaw, LogRecordFlaw.reportValueAbsent);
      expect(logEntriesOf(snapshot), isEmpty);
    });
  });

  group('the v1→v5 upgrade (Stories 2.1–2.6, AD-23 — additive, ALTER-only)', () {
    /// Takes over the group's database slot with one opened over a memory
    /// executor pre-seeded with the exact v1 schema (two tables, four
    /// triggers, `user_version` 1) — the state a v1 install presents. The
    /// setup callback runs on the raw database before drift initializes,
    /// so drift's migration runner then sees version 1 and upgrades; the
    /// group's tearDown closes the takeover instance like any other.
    Future<void> takeOverWithV1(void Function(dynamic db) seed) async {
      await db.close();
      db = SubstrateDatabase(NativeDatabase.memory(setup: seed));
      store = DriftStore(db);
    }

    void seedV1(dynamic db) {
      for (final statement in [
        'CREATE TABLE pool_facts ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'origin TEXT NOT NULL, '
            'size TEXT NOT NULL, '
            'instant_utc_micros INTEGER NOT NULL, '
            'offset_seconds INTEGER NOT NULL)',
        'CREATE TABLE log_entries ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'kind TEXT NOT NULL, '
            'instant_utc_micros INTEGER NOT NULL, '
            'offset_seconds INTEGER NOT NULL, '
            'item_id TEXT NULL, '
            'item_origin TEXT NULL, '
            'stack TEXT NULL)',
        'CREATE TRIGGER pool_facts_refuse_update BEFORE UPDATE ON '
            "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
            "insert-only (AD-2)'); END",
        'CREATE TRIGGER pool_facts_refuse_delete BEFORE DELETE ON '
            "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
            "insert-only (AD-2)'); END",
        'CREATE TRIGGER log_entries_refuse_update BEFORE UPDATE ON '
            "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
            "insert-only (AD-2)'); END",
        'CREATE TRIGGER log_entries_refuse_delete BEFORE DELETE ON '
            "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
            "insert-only (AD-2)'); END",
        "INSERT INTO pool_facts VALUES ('old-fact', 'manual', "
            "'maintenance', 100, 3600)",
        "INSERT INTO log_entries VALUES ('old-entry', 'card_done', 200, "
            "3600, 'man-a', 'shipped', NULL)",
        'PRAGMA user_version = 1',
      ]) {
        db.execute(statement);
      }
    }

    test('a seeded v1 database upgrades in place: the ALTERs add the '
        'setting, pocket, energy and report columns, the old rows read '
        'unchanged with null payload fields, and the refusal triggers '
        'survive the migration', () async {
      await takeOverWithV1(seedV1);

      expect(db.schemaVersion, 5);
      expect(
        (await db.customSelect('PRAGMA table_info(log_entries)').get())
            .map((row) => row.read<String>('name'))
            .toList()
          ..sort(),
        [
          'energy_level',
          'id',
          'instant_utc_micros',
          'item_id',
          'item_origin',
          'kind',
          'offset_seconds',
          'pocket_minutes',
          'report_value',
          'report_week',
          'setting_key',
          'setting_value',
          'stack',
        ],
      );
      expect(await _objects(db, 'table'), ['log_entries', 'pool_facts']);
      expect(await _objects(db, 'trigger'), [
        'log_entries_refuse_delete',
        'log_entries_refuse_update',
        'pool_facts_refuse_delete',
        'pool_facts_refuse_update',
      ]);

      // Old rows read unchanged: the v1 log row derives as its own kind
      // with null setting and pocket fields, never coerced.
      final snapshot = await store.readLogEntries();
      expect(snapshot, hasLength(1));
      expect(snapshot.single.id, 'old-entry');
      expect(snapshot.single.kind, 'card_done');
      expect(snapshot.single.settingKey, isNull);
      expect(snapshot.single.settingValue, isNull);
      expect(snapshot.single.pocketMinutes, isNull);
      expect(snapshot.single.energyLevel, isNull);
      expect(snapshot.single.reportValue, isNull);
      expect(snapshot.single.reportWeek, isNull);
      expect(await store.readPoolFacts(), hasLength(1));

      // Insert-only survives the migration on both tables.
      await expectLater(
        db.customUpdate(
          "UPDATE log_entries SET kind = 'card_skipped' WHERE id = 'old-entry'",
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );

      // The upgraded schema accepts new payload rows beside the old.
      await store.appendLogEntry((
        id: 'new-setting',
        kind: LogKind.settingChanged.name,
        instantUtcMicros: 300,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: 'time_bag',
        settingValue: 10,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      await store.appendLogEntry((
        id: 'new-pocket',
        kind: LogKind.sessionStarted.name,
        instantUtcMicros: 400,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: 15,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      await store.appendLogEntry((
        id: 'new-energy',
        kind: LogKind.energySet.name,
        instantUtcMicros: 500,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: 1,
        reportValue: null,
        reportWeek: null,
      ));
      await store.appendLogEntry((
        id: 'new-report',
        kind: LogKind.reportAnswered.name,
        instantUtcMicros: 600,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 3,
        reportWeek: 1394,
      ));
      final after = await store.readLogEntries();
      expect(after, hasLength(5));
      expect(after[1].settingValue, 10);
      expect(after[2].pocketMinutes, 15);
      expect(after[3].energyLevel, 1);
      expect(after[4].reportValue, 3);
      expect(after[4].reportWeek, 1394);
    });

    test('a fresh create carries the setting, pocket, energy and report '
        'columns from the start', () async {
      expect(db.schemaVersion, 5);
      final columns =
          (await db.customSelect('PRAGMA table_info(log_entries)').get())
              .map((row) => row.read<String>('name'))
              .toList()
            ..sort();
      expect(columns, contains('setting_key'));
      expect(columns, contains('setting_value'));
      expect(columns, contains('pocket_minutes'));
      expect(columns, contains('energy_level'));
      expect(columns, contains('report_value'));
      expect(columns, contains('report_week'));
    });
  });

  group('the v2→v3 upgrade (Story 2.2, AD-23 — additive, ALTER-only)', () {
    /// The v2 schema exactly as a v2 install presents it: the v1 shape
    /// plus the two setting columns, `user_version` 2 — seeded over a
    /// memory executor so drift's runner sees version 2 and upgrades.
    Future<void> takeOverWithV2() async {
      await db.close();
      db = SubstrateDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            for (final statement in [
              'CREATE TABLE pool_facts ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'origin TEXT NOT NULL, '
                  'size TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL)',
              'CREATE TABLE log_entries ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'kind TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL, '
                  'item_id TEXT NULL, '
                  'item_origin TEXT NULL, '
                  'stack TEXT NULL, '
                  'setting_key TEXT NULL, '
                  'setting_value INTEGER NULL)',
              'CREATE TRIGGER pool_facts_refuse_update BEFORE UPDATE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER pool_facts_refuse_delete BEFORE DELETE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_update BEFORE UPDATE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_delete BEFORE DELETE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              "INSERT INTO log_entries VALUES ('v2-open', "
                  "'session_started', 100, 3600, NULL, NULL, NULL, NULL, "
                  "NULL)",
              "INSERT INTO log_entries VALUES ('v2-bag', "
                  "'setting_changed', 200, 3600, NULL, NULL, NULL, "
                  "'time_bag', 25)",
              'PRAGMA user_version = 2',
            ]) {
              rawDb.execute(statement);
            }
          },
        ),
      );
      store = DriftStore(db);
    }

    test(
      'a seeded v2 database upgrades in place: one ALTER adds the '
      'pocket column, the v2 rows — settings intact, sessions pocketless '
      '— read back unchanged, and a pocketed start appends beside them',
      () async {
        await takeOverWithV2();

        expect(db.schemaVersion, 5);
        expect(
          (await db.customSelect('PRAGMA table_info(log_entries)').get())
              .map((row) => row.read<String>('name'))
              .toList()
            ..sort(),
          [
            'energy_level',
            'id',
            'instant_utc_micros',
            'item_id',
            'item_origin',
            'kind',
            'offset_seconds',
            'pocket_minutes',
            'report_value',
            'report_week',
            'setting_key',
            'setting_value',
            'stack',
          ],
        );
        expect(await _objects(db, 'table'), ['log_entries', 'pool_facts']);
        expect(await _objects(db, 'trigger'), [
          'log_entries_refuse_delete',
          'log_entries_refuse_update',
          'pool_facts_refuse_delete',
          'pool_facts_refuse_update',
        ]);

        // The v2 rows ride the migration untouched: the setting keeps its
        // payload and the session start reads as an unbounded sitting.
        final before = await store.readLogEntries();
        expect(before, hasLength(2));
        expect(before.first.id, 'v2-open');
        expect(before.first.pocketMinutes, isNull);
        expect(before.last.settingKey, 'time_bag');
        expect(before.last.settingValue, 25);

        // Insert-only survives this migration too.
        await expectLater(
          db.customUpdate(
            "UPDATE log_entries SET kind = 'card_skipped' WHERE id = 'v2-open'",
          ),
          throwsA(
            isA<SqliteException>().having(
              (e) => e.message,
              'message',
              contains('insert-only (AD-2)'),
            ),
          ),
        );

        // The upgraded schema accepts a pocketed start beside the old rows.
        await store.appendLogEntry((
          id: 'v3-pocket',
          kind: LogKind.sessionStarted.name,
          instantUtcMicros: 300,
          offsetSeconds: 3600,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          pocketMinutes: 20,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
        ));
        // ...and a v5 answer row lands beside them just the same.
        await store.appendLogEntry((
          id: 'v5-report',
          kind: LogKind.reportAnswered.name,
          instantUtcMicros: 400,
          offsetSeconds: 3600,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: 4,
          reportWeek: 1394,
        ));
        final after = await store.readLogEntries();
        expect(after, hasLength(4));
        expect(after[2].pocketMinutes, 20);
        expect(after.last.kind, 'report_answered');
        expect(after.last.reportValue, 4);
        expect(after.last.reportWeek, 1394);
      },
    );
  });

  group('the v3→v4 upgrade (Story 2.5, AD-23 — additive, ALTER-only)', () {
    /// The v3 schema exactly as a v3 install presents it: the v2 shape
    /// plus the pocket column, `user_version` 3 — seeded over a memory
    /// executor so drift's runner sees version 3 and upgrades.
    Future<void> takeOverWithV3() async {
      await db.close();
      db = SubstrateDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            for (final statement in [
              'CREATE TABLE pool_facts ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'origin TEXT NOT NULL, '
                  'size TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL)',
              'CREATE TABLE log_entries ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'kind TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL, '
                  'item_id TEXT NULL, '
                  'item_origin TEXT NULL, '
                  'stack TEXT NULL, '
                  'setting_key TEXT NULL, '
                  'setting_value INTEGER NULL, '
                  'pocket_minutes INTEGER NULL)',
              'CREATE TRIGGER pool_facts_refuse_update BEFORE UPDATE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER pool_facts_refuse_delete BEFORE DELETE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_update BEFORE UPDATE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_delete BEFORE DELETE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              "INSERT INTO log_entries VALUES ('v3-open', "
                  "'session_started', 100, 3600, NULL, NULL, NULL, NULL, "
                  "NULL, 15)",
              "INSERT INTO log_entries VALUES ('v3-bag', "
                  "'setting_changed', 200, 3600, NULL, NULL, NULL, "
                  "'time_bag', 25, NULL)",
              'PRAGMA user_version = 3',
            ]) {
              rawDb.execute(statement);
            }
          },
        ),
      );
      store = DriftStore(db);
    }

    test('a seeded v3 database upgrades in place: one ALTER adds the energy '
        'level column, the v3 rows — pockets intact, settings intact, '
        'levels null — read back unchanged, and an energy row appends '
        'beside them', () async {
      await takeOverWithV3();

      expect(db.schemaVersion, 5);
      expect(
        (await db.customSelect('PRAGMA table_info(log_entries)').get())
            .map((row) => row.read<String>('name'))
            .toList()
          ..sort(),
        [
          'energy_level',
          'id',
          'instant_utc_micros',
          'item_id',
          'item_origin',
          'kind',
          'offset_seconds',
          'pocket_minutes',
          'report_value',
          'report_week',
          'setting_key',
          'setting_value',
          'stack',
        ],
      );
      expect(await _objects(db, 'table'), ['log_entries', 'pool_facts']);
      expect(await _objects(db, 'trigger'), [
        'log_entries_refuse_delete',
        'log_entries_refuse_update',
        'pool_facts_refuse_delete',
        'pool_facts_refuse_update',
      ]);

      // The v3 rows ride the migration untouched: the pocket keeps its
      // payload and every row reads as a level-less day — deriving
      // unanswered, defaulting 🟢.
      final before = await store.readLogEntries();
      expect(before, hasLength(2));
      expect(before.first.id, 'v3-open');
      expect(before.first.pocketMinutes, 15);
      expect(before.first.energyLevel, isNull);
      expect(before.first.reportValue, isNull);
      expect(before.first.reportWeek, isNull);
      expect(before.last.settingKey, 'time_bag');
      expect(before.last.settingValue, 25);

      // Insert-only survives this migration too.
      await expectLater(
        db.customUpdate(
          "UPDATE log_entries SET kind = 'card_skipped' "
          "WHERE id = 'v3-open'",
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );

      // The upgraded schema accepts an energy row beside the old rows.
      await store.appendLogEntry((
        id: 'v4-energy',
        kind: LogKind.energySet.name,
        instantUtcMicros: 300,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: 2,
        reportValue: null,
        reportWeek: null,
      ));
      // ...and a v5 answer row lands beside them just the same.
      await store.appendLogEntry((
        id: 'v5-report',
        kind: LogKind.reportAnswered.name,
        instantUtcMicros: 400,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 4,
        reportWeek: 1394,
      ));
      final after = await store.readLogEntries();
      expect(after, hasLength(4));
      expect(after[2].energyLevel, 2);
      expect(after.last.kind, 'report_answered');
      expect(after.last.reportValue, 4);
      expect(after.last.reportWeek, 1394);
    });
  });

  group('the v4→v5 upgrade (Story 2.6, AD-23 — additive, ALTER-only)', () {
    /// The v4 schema exactly as a v4 install presents it: the v3 shape
    /// plus the energy level column, `user_version` 4 — seeded over a
    /// memory executor so drift's runner sees version 4 and upgrades.
    Future<void> takeOverWithV4() async {
      await db.close();
      db = SubstrateDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            for (final statement in [
              'CREATE TABLE pool_facts ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'origin TEXT NOT NULL, '
                  'size TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL)',
              'CREATE TABLE log_entries ('
                  'id TEXT NOT NULL PRIMARY KEY, '
                  'kind TEXT NOT NULL, '
                  'instant_utc_micros INTEGER NOT NULL, '
                  'offset_seconds INTEGER NOT NULL, '
                  'item_id TEXT NULL, '
                  'item_origin TEXT NULL, '
                  'stack TEXT NULL, '
                  'setting_key TEXT NULL, '
                  'setting_value INTEGER NULL, '
                  'pocket_minutes INTEGER NULL, '
                  'energy_level INTEGER NULL)',
              'CREATE TRIGGER pool_facts_refuse_update BEFORE UPDATE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER pool_facts_refuse_delete BEFORE DELETE ON '
                  "pool_facts BEGIN SELECT RAISE(ABORT, 'pool_facts is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_update BEFORE UPDATE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              'CREATE TRIGGER log_entries_refuse_delete BEFORE DELETE ON '
                  "log_entries BEGIN SELECT RAISE(ABORT, 'log_entries is "
                  "insert-only (AD-2)'); END",
              "INSERT INTO log_entries VALUES ('v4-energy', "
                  "'energy_set', 100, 3600, NULL, NULL, NULL, NULL, "
                  "NULL, NULL, 2)",
              "INSERT INTO log_entries VALUES ('v4-bag', "
                  "'setting_changed', 200, 3600, NULL, NULL, NULL, "
                  "'time_bag', 25, NULL, NULL)",
              'PRAGMA user_version = 4',
            ]) {
              rawDb.execute(statement);
            }
          },
        ),
      );
      store = DriftStore(db);
    }

    test('a seeded v4 database upgrades in place: two ALTERs add the report '
        'columns, the v4 rows — levels intact, settings intact, report '
        'fields null — read back unchanged, and an answer row appends '
        'beside them', () async {
      await takeOverWithV4();

      expect(db.schemaVersion, 5);
      expect(
        (await db.customSelect('PRAGMA table_info(log_entries)').get())
            .map((row) => row.read<String>('name'))
            .toList()
          ..sort(),
        [
          'energy_level',
          'id',
          'instant_utc_micros',
          'item_id',
          'item_origin',
          'kind',
          'offset_seconds',
          'pocket_minutes',
          'report_value',
          'report_week',
          'setting_key',
          'setting_value',
          'stack',
        ],
      );
      expect(await _objects(db, 'table'), ['log_entries', 'pool_facts']);
      expect(await _objects(db, 'trigger'), [
        'log_entries_refuse_delete',
        'log_entries_refuse_update',
        'pool_facts_refuse_delete',
        'pool_facts_refuse_update',
      ]);

      // The v4 rows ride the migration untouched: the energy row keeps
      // its level and every row reads as report-less — no week gains
      // or loses a data point.
      final before = await store.readLogEntries();
      expect(before, hasLength(2));
      expect(before.first.id, 'v4-energy');
      expect(before.first.energyLevel, 2);
      expect(before.first.reportValue, isNull);
      expect(before.first.reportWeek, isNull);
      expect(before.last.settingKey, 'time_bag');
      expect(before.last.settingValue, 25);

      // Insert-only survives this migration too.
      await expectLater(
        db.customUpdate(
          "UPDATE log_entries SET kind = 'card_skipped' "
          "WHERE id = 'v4-energy'",
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('insert-only (AD-2)'),
          ),
        ),
      );

      // The upgraded schema accepts an answer row beside the old rows,
      // and an out-of-scale value stays stored verbatim — the entry
      // stays in the log and the core's read boundary excludes it,
      // never a repair write (AD-23).
      await store.appendLogEntry((
        id: 'v5-report',
        kind: LogKind.reportAnswered.name,
        instantUtcMicros: 300,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 3,
        reportWeek: 1394,
      ));
      await db.customInsert(
        'INSERT INTO log_entries '
        '(id, kind, instant_utc_micros, offset_seconds, report_value, '
        'report_week) '
        "VALUES ('imported-9', 'report_answered', 50, 0, 9, 1394)",
      );

      final after = await store.readLogEntries();
      // Replay order is by recorded instant: the raw-seeded 1970 row
      // leads, the v4 rows follow, the appended answer closes.
      expect(after, hasLength(4));
      expect(after.first.id, 'imported-9');
      expect(after.first.reportValue, 9);
      expect(after.first.reportWeek, 1394);
      expect(after.last.id, 'v5-report');
      expect(after.last.kind, 'report_answered');
      expect(after.last.reportValue, 3);
      expect(after.last.reportWeek, 1394);
      expect(after.last.energyLevel, isNull);
    });
  });
}
