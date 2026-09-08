// The curation sub-screen's contract (Story 5.11, FR-31, AD-16,
// UX-DR23): exactly eight rows — anclas, sostén, z1–z5, fondo — each
// carrying its cluster name, its cadence as the only description in
// the support role, and a platform switch whose whole band is the
// control; one flip appending exactly one `cluster_curation_changed`
// row with no confirmation, count or summary of any kind; the switch
// following the derivation on every re-read; and the camera row's
// own lifecycle grammar — the unread window's all-active default, the
// pre-read tap that writes nothing, the equal-value no-op.
import 'dart:async';
import 'dart:ui' as ui show Size;
import 'dart:ui' show Tristate;

import 'package:core/curation/curation.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/settings/settings_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/settings/curation_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

/// The recording store (the settings suite's own contract): appends
/// land in order and every read replays them.
class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> facts = [];

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => facts.add(fact);

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => entries.add(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// A store whose every `readLogEntries` parks until released — the
/// unread window, held open however many reads the surface fires.
class _AllReadsGatedStore extends _RecordingStore {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<List<LogEntryRecord>> readLogEntries() =>
      _gate.future.then((_) => super.readLogEntries());
}

/// A store whose first `appendLogEntry` fails — the write path's
/// quiet-failure arm (the camera row group's own `_FailFirstSetting
/// AppendStore` grammar): nothing is written, nothing surfaces, and
/// the switch returns to the derived state on the re-read.
class _FailFirstAppendStore extends _RecordingStore {
  var _appends = 0;

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (_appends++ == 0) {
      throw StateError('append failed');
    }
    await super.appendLogEntry(entry);
  }
}

/// A store whose every `appendLogEntry` parks until released — the
/// in-flight write, held open so a second tap lands while the first
/// flip's write is still running.
class _GatedFirstAppendStore extends _RecordingStore {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) =>
      _gate.future.then((_) => super.appendLogEntry(entry));
}

/// A store whose reads succeed until the first append, then throw —
/// a successful write whose re-read fails.
class _FailReadAfterAppendStore extends _RecordingStore {
  var _appended = false;

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    await super.appendLogEntry(entry);
    _appended = true;
  }

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (_appended) {
      throw StateError('read failed');
    }
    return super.readLogEntries();
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

/// A curation row seed: one `cluster_curation_changed` record, on the
/// fixed clock's own domestic day (Saturday 2026-08-29), offset zero.
LogEntryRecord _seedRow(
  String id,
  CurationCluster cluster,
  bool enabled, {
  int hour = 10,
}) => (
  id: id,
  kind: LogKind.clusterCurationChanged.name,
  instantUtcMicros: DateTime.utc(2026, 8, 29, hour).microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: null,
  reportWeek: null,
  permission: null,
  sliceCause: null,
  cluster: cluster.name,
  enabled: enabled,
);

void main() {
  final es = AppStringsEs();

  Widget harnessFor(StorePort store) {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: CurationScreen(
        controller: SettingsController(store: store, nowOf: _fixedClock),
      ),
    );
  }

  /// The null-controller seam (the camera row group's own grammar): the
  /// rows render and writes go nowhere.
  Widget nullHarness() {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: const CurationScreen(controller: null),
    );
  }

  /// The texts the whole tree carries, every channel included — the
  /// quietness census: nothing beyond the authored strings may render.
  List<String> textsOf(WidgetTester tester) {
    final texts = <String?>[
      for (final text in tester.widgetList<Text>(find.byType(Text))) text.data,
      for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
        rich.text.toPlainText(),
      for (final semantics in tester.widgetList<Semantics>(
        find.byType(Semantics),
      ))
        semantics.properties.label,
    ];
    return [
      for (final value in texts)
        if (value != null && value.isNotEmpty) value,
    ];
  }

  /// The switch finder [switchOf] reads — the row's own switch, never
  /// any other.
  Finder switchFinderOf(CurationCluster cluster) {
    final label = switch (cluster) {
      CurationCluster.anclas => es.curationClusterAnclas,
      CurationCluster.sosten => es.curationClusterSosten,
      CurationCluster.z1 => es.zoneZ1,
      CurationCluster.z2 => es.zoneZ2,
      CurationCluster.z3 => es.zoneZ3,
      CurationCluster.z4 => es.zoneZ4,
      CurationCluster.z5 => es.zoneZ5,
      CurationCluster.fondo => es.curationClusterFondo,
    };
    final band = find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first;
    return find.descendant(of: band, matching: find.byType(Switch));
  }

  /// The switch of [cluster]'s row — the row whose merged semantics
  /// node carries the cluster's label.
  Switch switchOf(WidgetTester tester, CurationCluster cluster) =>
      tester.widget<Switch>(switchFinderOf(cluster));

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const ui.Size(320, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('renders exactly eight rows in the cluster order — name, '
      'cadence in the support role, switch — and nothing else '
      '(UX-DR23, FR-31)', (tester) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    // The quiet census is the sub-screen header, the three authored
    // names, the five canonical zone names and the three cadence
    // words — no counts, no task names, no other copy.
    expect(textsOf(tester).toSet(), {
      es.settingsCurationGroups,
      es.curationClusterAnclas,
      es.curationClusterSosten,
      es.zoneZ1,
      es.zoneZ2,
      es.zoneZ3,
      es.zoneZ4,
      es.zoneZ5,
      es.curationClusterFondo,
      es.curationCadenceDaily,
      es.curationCadenceWeekly,
      es.curationCadenceSeasonal,
    });
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Switch), findsNWidgets(8));

    // The row order is the cluster enum's own: anclas, sostén, the
    // five zones, fondo.
    final order = [
      es.curationClusterAnclas,
      es.curationClusterSosten,
      es.zoneZ1,
      es.zoneZ2,
      es.zoneZ3,
      es.zoneZ4,
      es.zoneZ5,
      es.curationClusterFondo,
    ];
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .toList();
    for (final (index, label) in order.indexed) {
      expect(labels.indexOf(label), greaterThan(-1), reason: label);
      if (index > 0) {
        expect(
          labels.lastIndexOf(order[index - 1]),
          lessThan(labels.lastIndexOf(label)),
          reason: '$label follows ${order[index - 1]}',
        );
      }
    }

    // The cadence sits in the support role beneath its name: quiet
    // ink-secondary prose at the support size.
    final cadence = tester.widget<Text>(
      find.text(es.curationCadenceDaily).first,
    );
    expect(cadence.style!.color, FieldPalette.inkSecondary);
    expect(cadence.style!.fontSize, 13);
    // And the name in the action-secondary role.
    final name = tester.widget<Text>(find.text(es.curationClusterFondo));
    expect(name.style!.fontSize, 15);

    // The default derivation: every cluster active (FR-31).
    for (final cluster in CurationCluster.values) {
      expect(switchOf(tester, cluster).value, isTrue, reason: cluster.name);
    }
  });

  testWidgets('the title override renders in the header\'s place — the '
      'E1 surface is the same screen, only the string differing, the '
      'default header regression already pinned above (Story 5.12)', (
    tester,
  ) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: CurationScreen(
          controller: SettingsController(store: store, nowOf: _fixedClock),
          title: es.curationHouseGroups,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The house title stands where the sub-screen's own header stood —
    // and nothing else about the surface changed: the same census with
    // the one string swapped, the same eight switches.
    expect(find.text(es.curationHouseGroups), findsOneWidget);
    expect(find.text(es.settingsCurationGroups), findsNothing);
    expect(textsOf(tester).toSet(), {
      es.curationHouseGroups,
      es.curationClusterAnclas,
      es.curationClusterSosten,
      es.zoneZ1,
      es.zoneZ2,
      es.zoneZ3,
      es.zoneZ4,
      es.zoneZ5,
      es.curationClusterFondo,
      es.curationCadenceDaily,
      es.curationCadenceWeekly,
      es.curationCadenceSeasonal,
    });
    expect(find.byType(Switch), findsNWidgets(8));
  });

  testWidgets('the whole band taps: one flip appends exactly one '
      'cluster_curation_changed row and the switch follows the '
      'derivation — no confirmation, no other feedback (FR-31, AD-21)', (
    tester,
  ) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    // Tap the LABEL, not the switch: the whole band is the control.
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();

    final rows = store.entries
        .where((entry) => entry.kind == LogKind.clusterCurationChanged.name)
        .toList();
    expect(rows, hasLength(1));
    expect(rows.single.cluster, 'anclas');
    expect(rows.single.enabled, isFalse);
    expect(
      rows.single.settingKey,
      isNull,
      reason: 'the payload rides its own columns, never a setting key',
    );
    expect(rows.single.itemId, isNull);
    expect(switchOf(tester, CurationCluster.anclas).value, isFalse);

    // Every other switch stands: one row, one cluster.
    for (final cluster in CurationCluster.values) {
      if (cluster == CurationCluster.anclas) {
        continue;
      }
      expect(switchOf(tester, cluster).value, isTrue, reason: cluster.name);
    }
    expect(find.byType(SnackBar), findsNothing);
    expect(textsOf(tester).where((text) => text.contains('!')), isEmpty);

    // And the switch itself taps too — the shared handler's other half.
    await tester.tap(switchFinderOf(CurationCluster.anclas));
    await tester.pumpAndSettle();
    expect(
      store.entries
          .where((entry) => entry.kind == LogKind.clusterCurationChanged.name)
          .toList()
          .last
          .enabled,
      isTrue,
      reason: 'the platform switch is the same one control as the band',
    );
    expect(switchOf(tester, CurationCluster.anclas).value, isTrue);
  });

  testWidgets('a seeded derivation renders: anclas off from a stored row, '
      'everything else on — the log is the only source of truth (AD-1)', (
    tester,
  ) async {
    await useTallSurface(tester);
    final store = _RecordingStore()
      ..entries.add(_seedRow('seed', CurationCluster.anclas, false));
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    expect(switchOf(tester, CurationCluster.anclas).value, isFalse);
    for (final cluster in CurationCluster.values) {
      if (cluster == CurationCluster.anclas) {
        continue;
      }
      expect(switchOf(tester, cluster).value, isTrue, reason: cluster.name);
    }
  });

  testWidgets('a weekly-zone flip stands on the switch as declared — '
      'AD-16’s two speeds live in composition, never in the control', (
    tester,
  ) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    // A z1 flip mid-week writes its row and the switch holds the
    // declaration: composition keeps serving z1 until next Monday
    // 04:00 (the weave’s own timing tests pin that half), and the
    // control never springs back — a bounced switch reads as a
    // refused act, and no copy may explain the delay (UX-DR23).
    await tester.tap(find.text(es.zoneZ1));
    await tester.pumpAndSettle();
    final rows = store.entries
        .where((entry) => entry.kind == LogKind.clusterCurationChanged.name)
        .toList();
    expect(rows, hasLength(1));
    expect(rows.single.cluster, 'z1');
    expect(rows.single.enabled, isFalse);
    expect(
      switchOf(tester, CurationCluster.z1).value,
      isFalse,
      reason: 'the switch shows the declaration; the week keeps its zone',
    );
    // Re-proposing the declared value is the guard’s quiet no-op —
    // even mid-week, even for a zone (the matrix’s equal-value row).
    final row = tester.widget<CurationRow>(
      find.ancestor(
        of: find.text(es.zoneZ1),
        matching: find.byType(CurationRow),
      ),
    );
    row.onChanged!(false);
    await tester.pumpAndSettle();
    expect(store.entries, hasLength(1));
  });

  testWidgets('a value equal to the derivation writes nothing — no '
      'redundant row', (tester) async {
    await useTallSurface(tester);
    final store = _RecordingStore()
      ..entries.add(_seedRow('seed', CurationCluster.fondo, false));
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();
    expect(switchOf(tester, CurationCluster.fondo).value, isFalse);

    // The derivation already holds fondo off: a tap proposing the
    // same value again is nothing (the row's handler, driven straight
    // — a switch tap always proposes the opposite, so the guard's own
    // arm is what this reaches).
    final row = tester.widget<CurationRow>(find.byType(CurationRow).last);
    row.onChanged!(false);
    await tester.pumpAndSettle();
    expect(
      store.entries,
      hasLength(1),
      reason: 'the seed alone — re-choosing what is in force writes nothing',
    );
    // A real flip after the no-op still lands.
    await tester.tap(find.text(es.curationClusterFondo));
    await tester.pumpAndSettle();
    expect(store.entries, hasLength(2));
    expect(store.entries.last.enabled, isTrue);
  });

  testWidgets('the unread window renders all-active — no off flash — and '
      'a tap before the read lands writes nothing (FR-31)', (tester) async {
    await useTallSurface(tester);
    final store = _AllReadsGatedStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pump();

    for (final cluster in CurationCluster.values) {
      expect(
        switchOf(tester, cluster).value,
        isTrue,
        reason: '${cluster.name}: the unread window carries the default',
      );
    }
    await tester.tap(find.text(es.curationClusterSosten));
    await tester.pump();
    expect(
      store.entries,
      isEmpty,
      reason: 'no derived state, no write — the tap guessed nothing',
    );

    // The read lands: the switches still read on (the derivation
    // agrees over an empty log), and the write path is armed.
    store.release();
    await tester.pumpAndSettle();
    expect(switchOf(tester, CurationCluster.sosten).value, isTrue);
  });

  testWidgets('two rapid flips land exactly two rows in tap order and the '
      'derivation reads the newest — the serialized write chain', (
    tester,
  ) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();

    final rows = store.entries
        .where((entry) => entry.kind == LogKind.clusterCurationChanged.name)
        .toList();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.enabled).toList(), [false, true]);
    expect(
      switchOf(tester, CurationCluster.anclas).value,
      isTrue,
      reason: 'the last row wins',
    );
  });

  testWidgets('a failed append is quiet: nothing written, nothing '
      'surfaced, and the switch returns to the derived state on the '
      're-read (the matrix’s error arm)', (tester) async {
    await useTallSurface(tester);
    final store = _FailFirstAppendStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    // The flip lands on a failing append — one attempt, zero rows.
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();
    expect(
      store.entries.where(
        (entry) => entry.kind == LogKind.clusterCurationChanged.name,
      ),
      isEmpty,
      reason: 'the failed append wrote nothing',
    );
    // The re-read derives from the rows that exist — none — so the
    // switch returns to the all-active default: the act was refused
    // by the store, and the surface never says a word about it.
    expect(switchOf(tester, CurationCluster.anclas).value, isTrue);
  });

  testWidgets('a second tap on the same row while a flip is in flight '
      'does not append a duplicate — the write-queue equal-value '
      'guard is the only lock', (tester) async {
    await useTallSurface(tester);
    final store = _GatedFirstAppendStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    // The first flip parks inside its append; a second tap on the
    // same row lands while the flight is running. The controlled
    // switch still shows on, so both taps propose off; the second
    // write no-ops once the first row is in the log.
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pump();
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pump();
    store.release();
    await tester.pumpAndSettle();

    expect(
      store.entries.where(
        (entry) => entry.kind == LogKind.clusterCurationChanged.name,
      ),
      hasLength(1),
      reason: 'the queued equal-value guard swallowed the duplicate intent',
    );
    expect(switchOf(tester, CurationCluster.anclas).value, isFalse);
  });

  testWidgets('a second cluster flip while another is in flight still '
      'lands — the write queue serializes independent acts', (tester) async {
    await useTallSurface(tester);
    final store = _GatedFirstAppendStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pump();
    await tester.tap(find.text(es.curationClusterFondo));
    await tester.pump();
    store.release();
    await tester.pumpAndSettle();

    final rows = store.entries
        .where((entry) => entry.kind == LogKind.clusterCurationChanged.name)
        .toList();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.cluster).toList(), ['anclas', 'fondo']);
    expect(rows.every((row) => row.enabled == false), isTrue);
    expect(switchOf(tester, CurationCluster.anclas).value, isFalse);
    expect(switchOf(tester, CurationCluster.fondo).value, isFalse);
  });

  testWidgets('a successful write whose re-read fails still lands the '
      'declared bit on the switch — the row just written is the '
      'truth', (tester) async {
    await useTallSurface(tester);
    final store = _FailReadAfterAppendStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();
    expect(
      store.entries.where(
        (entry) => entry.kind == LogKind.clusterCurationChanged.name,
      ),
      hasLength(1),
    );
    expect(
      switchOf(tester, CurationCluster.anclas).value,
      isFalse,
      reason: 'the switch follows the written row even if the re-read throws',
    );
  });

  testWidgets('a tap in the unread window retries the read and writes '
      'nothing — the recovery path for a failed first read', (tester) async {
    await useTallSurface(tester);
    final store = _AllReadsGatedStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pump();

    // The first read is still parked: the tap becomes a retry, never
    // a write.
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pump();
    expect(store.entries, isEmpty);

    // The reads resolve: the default stands, the switch lands, and a
    // real flip still works afterwards.
    store.release();
    await tester.pumpAndSettle();
    expect(switchOf(tester, CurationCluster.anclas).value, isTrue);
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();
    expect(
      store.entries.where(
        (entry) => entry.kind == LogKind.clusterCurationChanged.name,
      ),
      hasLength(1),
    );
  });

  testWidgets('the row\'s merged semantics node speaks name and cadence as '
      'one button — the only description is not swallowed (UX-DR23)', (
    tester,
  ) async {
    await useTallSurface(tester);
    final handle = tester.ensureSemantics();
    final store = _RecordingStore();
    await tester.pumpWidget(harnessFor(store));
    await tester.pumpAndSettle();

    final row = tester.getSemantics(switchFinderOf(CurationCluster.z1));
    final data = row.getSemanticsData();
    expect(data.label, contains(es.zoneZ1));
    expect(
      data.label,
      contains(es.curationCadenceWeekly),
      reason: 'the cadence is the row\'s only description — it must speak',
    );
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isToggled, isNot(Tristate.none));
    expect(data.flagsCollection.isToggled, Tristate.isTrue);
    handle.dispose();
  });

  test('the controller\'s own equal-value guard: a write already in force '
      'appends nothing — the seam 5.12\'s homes will cross', () async {
    final store = _RecordingStore()
      ..entries.add(_seedRow('seed', CurationCluster.anclas, false));
    final controller = SettingsController(store: store, nowOf: _fixedClock);

    // Already off: nothing.
    await controller.writeClusterCuration(CurationCluster.anclas, false);
    expect(store.entries, hasLength(1));
    // A real change: one row.
    await controller.writeClusterCuration(CurationCluster.anclas, true);
    expect(store.entries, hasLength(2));
    expect(store.entries.last.enabled, isTrue);
    // And back: one row.
    await controller.writeClusterCuration(CurationCluster.anclas, false);
    expect(store.entries, hasLength(3));
  });

  test('a mid-week zone re-enable writes a second row — the guard '
      'reads declared state, not composition timing', () async {
    final store = _RecordingStore();
    final controller = SettingsController(store: store, nowOf: _fixedClock);

    await controller.writeClusterCuration(CurationCluster.z1, false);
    expect(store.entries, hasLength(1));
    await controller.writeClusterCuration(CurationCluster.z1, true);
    expect(
      store.entries,
      hasLength(2),
      reason: 'composition still holds z1 this week; the switch must bounce',
    );
    expect(store.entries.last.cluster, 'z1');
    expect(store.entries.last.enabled, isTrue);
  });

  testWidgets('the null-controller chain: the rows render on the '
      'all-active default and a write goes nowhere (the documented test '
      'seam)', (tester) async {
    await useTallSurface(tester);
    final store = _RecordingStore();
    await tester.pumpWidget(nullHarness());
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNWidgets(8));
    for (final cluster in CurationCluster.values) {
      expect(switchOf(tester, cluster).value, isTrue);
    }
    await tester.tap(find.text(es.curationClusterAnclas));
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.byType(ErrorWidget), findsNothing);
  });
}
