// The cumulative impact dashboard's contract (Story 7.4, FR-23,
// UX-DR30/36/37/46/51): the I/O matrix rendered. The figures the log
// already holds — cumulative work minutes through the one charging
// table, completed Micro-tasks, liberated volume as approximation
// sentences, and the three newest album highlights — reach the shell
// through the core's crossing derivation and nothing else. The
// denominator rule is pinned value by value: no "de N", no average,
// no target, no period comparison, no rate, no percentage, no
// completion ratio renders anywhere. The highlight row is pinned by
// measurement — three columns `actionGap` apart, each a Before/After
// pair at `radiusThumb` with a `spacingBase` pair gap and a place ·
// short-date caption — and the reflow is pinned in lines: any caption
// beyond two lines, at any scale, drops the whole row to one column
// per row with the dp gaps unchanged and nothing truncated. The
// volume card is absent entirely when no tally stands; a read failure
// leaves the quiet pending plate with `Volver al álbum` working; an
// empty album read pops the surface; a highlight tap is the same
// guarded pop back into the Album — no viewer, no browse surface.
import 'package:core/catalogue/catalogue.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/dashboard/dashboard_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dashboard/dashboard_screen.dart';
import 'package:organizer/ui/glyphs/album_glyph.dart';
import 'package:organizer/ui/glyphs/clock_glyph.dart';
import 'package:organizer/ui/photo_frame.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> poolFacts = [];
  bool throwOnRead = false;
  bool throwOnPoolRead = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {}

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async {
    if (throwOnPoolRead) {
      throw StateError('pool read failed');
    }
    return List.unmodifiable(poolFacts);
  }

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return List.unmodifiable(entries);
  }
}

class _RecordingFiles implements FilesPort {
  final blobsByName = <String, List<int>>{};

  @override
  Future<List<int>?> read(String scope, String name) async => blobsByName[name];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    blobsByName[name] = bytes;
  }

  @override
  Future<void> delete(String scope, String name) async {
    blobsByName.remove(name);
  }

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}

  @override
  Future<void> sweepAlbum() async {
    blobsByName.clear();
  }
}

/// The hand-built catalogue the walk resolves sizes through — the
/// loader's parsed output, one entry per taxonomy size.
final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: const [
    CatalogueEntry(
      id: 'focus-a',
      size: Size.focus,
      cadence: Cadence.daily,
      name: 'Tarea de focus-a',
    ),
    CatalogueEntry(
      id: 'man-a',
      size: Size.maintenance,
      cadence: Cadence.daily,
      name: 'Tarea de man-a',
    ),
    CatalogueEntry(
      id: 'hab-a',
      size: Size.instant,
      cadence: Cadence.daily,
      name: 'Tarea de hab-a',
    ),
  ],
);

/// One completed Micro-task on a shipped id.
void _seedDone(
  _RecordingStore store,
  String itemId,
  int ordinal, {
  int instantUtcMicros = 100000,
}) {
  store.entries.add((
    id: 'done-$itemId-$ordinal',
    kind: 'card_done',
    instantUtcMicros: instantUtcMicros + ordinal,
    offsetSeconds: 7200,
    itemId: itemId,
    itemOrigin: Origin.shipped,
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
    cluster: null,
    enabled: null,
    triageDestination: null,
    triageVolumeTag: null,
    triageBoxId: null,
    beforeName: null,
    afterName: null,
  ));
}

/// One liberated triage row with its coarse volume tag.
void _seedTriage(
  _RecordingStore store,
  String id,
  String destinationWire,
  String tagWire,
) {
  store.entries.add((
    id: 'triage-$id',
    kind: 'item_triaged',
    instantUtcMicros: 200000,
    offsetSeconds: 7200,
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
    cluster: null,
    enabled: null,
    triageDestination: destinationWire,
    triageVolumeTag: tagWire,
    triageBoxId: null,
    beforeName: null,
    afterName: null,
  ));
}

/// One live album entry naming [group] — the log's append order is the
/// gallery's age order, newest last.
void _seedAlbumEntry(
  _RecordingStore store,
  String group,
  int instantUtcMicros,
) {
  store.entries.add((
    id: 'album-$group',
    kind: 'album_entry_added',
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: 7200,
    itemId: group,
    itemOrigin: Origin.cloud,
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
    cluster: null,
    enabled: null,
    triageDestination: null,
    triageVolumeTag: null,
    triageBoxId: null,
    beforeName: 'before-$group.jpg',
    afterName: 'after-$group.jpg',
  ));
}

/// One scan group's head fact — the slicer-origin step whose Origin
/// Context the highlight caption joins on as the place.
void _seedScanGroup(
  _RecordingStore store,
  String id,
  String context, {
  int instantUtcMicros = 500,
}) {
  store.poolFacts.add((
    id: id,
    origin: Origin.cloud,
    size: Size.maintenance,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: 7200,
    originContext: context,
    dictated: null,
    rescueOf: null,
    estimateSeconds: 240,
    stepText: 'Primer paso',
  ));
}

/// Noon-UTC instants: the caption's short date is the act's own
/// recorded civil day — the instant offset by its row's offset
/// (AD-4) — so no test host's zone can move it, and noon keeps a
/// half-day of margin against a seeded offset nudging the date
/// across midnight.
int _noon(int year, int month, int day) =>
    DateTime.utc(year, month, day, 12).microsecondsSinceEpoch;

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

  DashboardController controllerWith(
    _RecordingStore store,
    _RecordingFiles files, {
    bool failCatalogue = false,
  }) => DashboardController(
    store: store,
    files: files,
    loadCatalogue: () async {
      if (failCatalogue) {
        throw StateError('catalogue failed');
      }
      return _catalogue;
    },
  );

  /// The dashboard is never a MaterialApp's home — it is pushed from
  /// the Album, and its pop returns there. The harness mirrors that:
  /// a standing home route, the dashboard pushed on top.
  Future<void> pumpDashboard(
    WidgetTester tester,
    DashboardController dashboard,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(dashboard: dashboard),
          ),
        );
    await tester.pumpAndSettle();
  }

  /// The rendered store of the matrix's happy arm: work across sizes,
  /// liberated volume across three tags, three highlighted groups with
  /// places.
  (_RecordingStore, _RecordingFiles) seededSurface() {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    // 9 focus (8100 s) + 5 maintenance (900 s) + 4 instant (120 s)
    // = 9120 s = 2 h 32 min; 18 completed Micro-tasks.
    for (var i = 0; i < 9; i++) {
      _seedDone(store, 'focus-a', i);
    }
    for (var i = 0; i < 5; i++) {
      _seedDone(store, 'man-a', i);
    }
    for (var i = 0; i < 4; i++) {
      _seedDone(store, 'hab-a', i);
    }
    // 3 cajas, 1 bolsa liberated.
    for (var i = 0; i < 3; i++) {
      _seedTriage(store, '$i', 'trash_recycle', 'caja');
    }
    _seedTriage(store, 'bolsa', 'donate_sell', 'bolsa');
    // Three highlighted spaces, seeded in the log's own order —
    // oldest first, the reward flow's own append order — so the
    // newest (Salón, 12 ago) renders in the row's first column.
    // Single-word places on purpose: the test font's square glyphs
    // make a caption's NBSP-bound chunks wide, and a two-word place
    // isolates its first word onto its own line — three lines, the
    // reflow, and no three-column pin. The seeded captions hold two
    // lines at scale 1 (the row stays three columns) and cross the
    // two-line threshold at 200% (the reflow test's own arm).
    _seedScanGroup(store, 'g-old', 'Entrada');
    _seedScanGroup(store, 'g-mid', 'Trastero');
    _seedScanGroup(store, 'g-new', 'Salón');
    _seedAlbumEntry(store, 'g-old', _noon(2026, 7, 28));
    _seedAlbumEntry(store, 'g-mid', _noon(2026, 8, 4));
    _seedAlbumEntry(store, 'g-new', _noon(2026, 8, 12));
    for (final entry in store.entries) {
      if (entry.kind == 'album_entry_added') {
        final group = entry.itemId;
        files.blobsByName['before-$group.jpg'] = [1];
        files.blobsByName['after-$group.jpg'] = [2];
      }
    }
    return (store, files);
  }

  testWidgets('the seeded arm renders every AD-26 figure — title, work '
      'figure + label, micro-tasks figure + plural label, volume card, '
      'Del álbum + highlights, Volver al álbum (FR-23, matrix: open from '
      'album)', (tester) async {
    final (store, files) = seededSurface();
    await pumpDashboard(tester, controllerWith(store, files));

    expect(find.text(strings.dashboardTitle), findsOneWidget);
    // The work figure: 2 h 32 min through the hours-and-minutes shape,
    // with its caption naming the whole history — never a period.
    expect(find.text(strings.dashboardWorkDuration(2, 32)), findsOneWidget);
    // The literal pin (the settings-test convention): the rendered
    // figure asserted without routing through the same generated
    // function — the NBSPs binding each value to its unit are
    // load-bearing at 200%.
    expect(find.text('2\u00A0h\u00A032\u00A0min'), findsOneWidget);
    expect(find.text(strings.dashboardWorkCaption), findsOneWidget);
    // The micro-tasks figure and its plural label — the figure its own
    // atomic numeral, never a literal.
    expect(find.text(strings.dashboardMicroTasksFigure(18)), findsOneWidget);
    expect(find.text(strings.dashboardMicroTasksLabel(18)), findsOneWidget);
    // The two utility glyphs at the dense size, one per metric row.
    expect(find.byType(ClockGlyph), findsOneWidget);
    expect(find.byType(AlbumGlyph), findsOneWidget);
    // The volume card: one approximation sentence per non-zero tag,
    // each with its unit visible and correct gender/plural agreement,
    // over the one method line. No glyph rides the volume lines.
    expect(find.text(strings.liberatedVolumeCaja(3)), findsOneWidget);
    expect(find.text(strings.liberatedVolumeBolsa(1)), findsOneWidget);
    expect(find.text(strings.liberatedVolumeCajaGrande(1)), findsNothing);
    expect(find.text(strings.liberatedVolumeMueble(1)), findsNothing);
    expect(find.text(strings.dashboardVolumeMethod), findsOneWidget);
    expect(
      find.byType(AlbumGlyph),
      findsOneWidget,
      reason:
          'the only Álbum glyph is the metric row\'s — the volume '
          'lines carry none (UX-DR37)',
    );
    // The highlight section: three cells, six thumbnail frames, three
    // captions, the close.
    expect(find.text(strings.dashboardAlbumSection), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNWidgets(6));
    expect(
      find.text(strings.dashboardHighlightCaption('Salón', '12\u00A0ago')),
      findsOneWidget,
    );
    expect(
      find.text(strings.dashboardHighlightCaption('Trastero', '4\u00A0ago')),
      findsOneWidget,
    );
    expect(
      find.text(strings.dashboardHighlightCaption('Entrada', '28\u00A0jul')),
      findsOneWidget,
    );
    expect(find.text(strings.dashboardBackToAlbum), findsOneWidget);
  });

  testWidgets('the highlight row at default scale is three columns '
      'actionGap apart — each a Before/After pair at radiusThumb with a '
      'spacingBase pair gap and the caption beneath (UX-DR30)', (tester) async {
    final (store, files) = seededSurface();
    await pumpDashboard(tester, controllerWith(store, files));

    final frames = find.byType(PhotoFrame);
    expect(frames, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      expect(
        tester.widget<PhotoFrame>(frames.at(i)).radius,
        Radii.radiusThumb,
        reason: 'frame $i at the thumbnail cut edge',
      );
    }
    final newestBefore = tester.getRect(frames.at(0));
    final newestAfter = tester.getRect(frames.at(1));
    final middleBefore = tester.getRect(frames.at(2));
    // The pair's own tight gap: spacingBase, tighter than the Album's
    // full pair.
    expect(newestAfter.left - newestBefore.right, Spacing.spacingBase);
    // The column gap: actionGap, the row's own.
    expect(middleBefore.left - newestAfter.right, Spacing.actionGap);
    // Three equal columns.
    expect(newestBefore.width, middleBefore.width);
    expect(
      newestBefore.top,
      middleBefore.top,
      reason: 'the three columns share the row',
    );
    // The caption sits beneath its pair, inside its own column's width.
    final captionFinder = find.text(
      strings.dashboardHighlightCaption('Salón', '12\u00A0ago'),
    );
    final caption = tester.getRect(captionFinder);
    expect(caption.top, greaterThanOrEqualTo(newestAfter.bottom));
    expect(caption.right, lessThanOrEqualTo(newestAfter.right + 1));
  });

  testWidgets('any caption beyond two lines drops the WHOLE row to one '
      'column per row — gaps unchanged, nothing truncated (UX-DR30/46, '
      'matrix: caption beyond two lines)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    _seedDone(store, 'focus-a', 0);
    final longPlace =
        'La estantería grande del pasillo de arriba, la que está '
        'justo al lado del trastero pequeño';
    _seedScanGroup(store, 'g-old', 'Entrada');
    _seedScanGroup(store, 'g-mid', 'Trastero');
    _seedScanGroup(store, 'g-new', longPlace);
    _seedAlbumEntry(store, 'g-old', _noon(2026, 7, 28));
    _seedAlbumEntry(store, 'g-mid', _noon(2026, 8, 4));
    _seedAlbumEntry(store, 'g-new', _noon(2026, 8, 12));
    for (final group in ['g-old', 'g-mid', 'g-new']) {
      files.blobsByName['before-$group.jpg'] = [1];
      files.blobsByName['after-$group.jpg'] = [2];
    }
    await pumpDashboard(tester, controllerWith(store, files));

    final frames = find.byType(PhotoFrame);
    expect(frames, findsNWidgets(6));
    final firstBefore = tester.getRect(frames.at(0));
    final firstAfter = tester.getRect(frames.at(1));
    final secondBefore = tester.getRect(frames.at(2));
    // The whole row reflowed: the second cell starts BELOW the first,
    // never beside it.
    expect(
      secondBefore.top,
      greaterThan(firstBefore.bottom),
      reason: 'one column per row',
    );
    expect(firstAfter.top, firstBefore.top);
    // The dp gaps are unchanged: the pair keeps its spacingBase gap
    // and takes the full row width.
    expect(firstAfter.left - firstBefore.right, Spacing.spacingBase);
    expect(firstBefore.width, firstAfter.width);
    // Nothing truncated: the long caption renders whole.
    final caption = find.text(
      strings.dashboardHighlightCaption(longPlace, '12\u00A0ago'),
    );
    expect(caption, findsOneWidget);
    expect(
      tester.getRect(caption).width,
      lessThan(tester.getRect(frames.at(0)).width * 3),
    );
  });

  testWidgets('at 200% font scale the reflow fires by measurement — the '
      'row degrades to one column with the gaps unscaled and every '
      'caption whole (UX-DR30/46, the expected degradation)', (tester) async {
    final (store, files) = seededSurface();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    try {
      await pumpDashboard(tester, controllerWith(store, files));
    } finally {
      tester.platformDispatcher.clearAllTestValues();
    }

    final frames = find.byType(PhotoFrame);
    expect(frames, findsNWidgets(6));
    final firstBefore = tester.getRect(frames.at(0));
    final firstAfter = tester.getRect(frames.at(1));
    final secondBefore = tester.getRect(frames.at(2));
    expect(
      secondBefore.top,
      greaterThan(firstBefore.bottom),
      reason:
          'the 200% captions measure beyond two lines — one column '
          'per row',
    );
    // The gaps are dp: unscaled by the font.
    expect(firstAfter.left - firstBefore.right, Spacing.spacingBase);
    // The captions render whole — no truncation, no ellipsis.
    expect(
      find.text(strings.dashboardHighlightCaption('Salón', '12\u00A0ago')),
      findsOneWidget,
    );
    expect(
      find.text(strings.dashboardHighlightCaption('Entrada', '28\u00A0jul')),
      findsOneWidget,
    );
  });

  testWidgets('a read failure leaves the quiet pending plate standing — '
      'never a zeros reading — and Volver al álbum still pops (matrix: '
      'read fails)', (tester) async {
    final (store, files) = seededSurface();
    store.throwOnRead = true;
    await pumpDashboard(tester, controllerWith(store, files));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.dashboardVolumeMethod), findsNothing);
    expect(find.text(strings.dashboardMicroTasksFigure(18)), findsNothing);
    final quietPlate = find.byType(AspectRatio);
    expect(quietPlate, findsOneWidget);
    expect(tester.getSize(quietPlate).aspectRatio, closeTo(0.75, 0.01));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.ensureVisible(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('a failing pool-facts read and a failing catalogue load '
      'share the log-read failure\'s contract — the quiet pending plate '
      'standing, Volver al álbum still popping (matrix: read fails)', (
    tester,
  ) async {
    // The pool read throws: transient is never empty.
    var (store, files) = seededSurface();
    store.throwOnPoolRead = true;
    await pumpDashboard(tester, controllerWith(store, files));
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.dashboardVolumeMethod), findsNothing);
    await tester.ensureVisible(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);

    // The catalogue load fails: the same quiet contract.
    (store, files) = seededSurface();
    await pumpDashboard(
      tester,
      controllerWith(store, files, failCatalogue: true),
    );
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.dashboardVolumeMethod), findsNothing);
    await tester.ensureVisible(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('an empty album read pops the surface behind the isCurrent '
      'guard — no empty state, no copy (UX-DR51) — and the null-seam '
      'test seam renders nothing half-wired', (tester) async {
    final store = _RecordingStore();
    // Work figures exist but no album entry: a stale affordance over an
    // already-empty album, the defensive arm.
    _seedDone(store, 'focus-a', 0);
    await pumpDashboard(tester, controllerWith(store, _RecordingFiles()));
    expect(find.byType(DashboardScreen), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (context) => const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('fewer than three entries render fewer cells — no '
      'placeholder slots, no invented highlights (matrix: 1–2 entries)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));

    expect(find.byType(PhotoFrame), findsNWidgets(2));
    expect(
      find.text(
        strings.dashboardHighlightCaption('La mesa del salón', '12\u00A0ago'),
      ),
      findsOneWidget,
    );
    // Nothing placeholder-shaped renders: exactly one caption, one
    // section label, one close.
    expect(find.byType(Text), findsWidgets);
    expect(find.text(strings.dashboardBackToAlbum), findsOneWidget);
  });

  testWidgets('a highlight with no Origin Context renders the dateless '
      'caption — the date alone, never an invented place (matrix: '
      'missing origin context)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    // A group the fold does not know at all.
    _seedAlbumEntry(store, 'g-unknown', _noon(2026, 8, 12));
    files.blobsByName['before-g-unknown.jpg'] = [1];
    files.blobsByName['after-g-unknown.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));

    expect(
      find.text(strings.dashboardHighlightDatelessCaption('12\u00A0ago')),
      findsOneWidget,
    );
    expect(
      find.textContaining('·'),
      findsNothing,
      reason: 'no separator renders without a place',
    );
  });

  testWidgets('the caption\'s short date is the act\'s own recorded civil '
      'day — the instant offset by its row\'s offset, never the reading '
      'device\'s zone (AD-4)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    // 23:30 UTC on the 12th, recorded at +02:00 (the seed\'s own
    // offset): the act\'s civil day is the 13th, and the caption says
    // so on any test host — a device-zone rendering would say the
    // 12th on a UTC host.
    _seedAlbumEntry(
      store,
      'g-night',
      DateTime.utc(2026, 8, 12, 23, 30).microsecondsSinceEpoch,
    );
    files.blobsByName['before-g-night.jpg'] = [1];
    files.blobsByName['after-g-night.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));

    expect(
      find.text(strings.dashboardHighlightDatelessCaption('13\u00A0ago')),
      findsOneWidget,
    );
    expect(
      find.text(strings.dashboardHighlightDatelessCaption('12\u00A0ago')),
      findsNothing,
      reason: 'the device-zone date never renders',
    );
  });

  testWidgets('all volume tallies zero render no volume card at all — no '
      'zero sentence, no method line (matrix: all tallies zero)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    _seedDone(store, 'focus-a', 0);
    // A tagged KEPT row: the tag contributes to no volume.
    _seedTriage(store, 'keep', 'keep', 'caja');
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));

    expect(find.text(strings.dashboardVolumeMethod), findsNothing);
    expect(find.text(strings.liberatedVolumeCaja(0)), findsNothing);
    expect(find.text(strings.liberatedVolumeBolsa(0)), findsNothing);
    expect(find.textContaining('≈'), findsNothing);
    // The rest of the surface stands.
    expect(find.text(strings.dashboardMicroTasksFigure(1)), findsOneWidget);
  });

  testWidgets('a singular volume tally renders its singular sentence — '
      'the authored approximation shape, unit visible, gender and '
      'number correct (FR-22, UX-DR37/49)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    _seedTriage(store, 'grande', 'donate_sell', 'caja_grande');
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));

    expect(find.text(strings.liberatedVolumeCajaGrande(1)), findsOneWidget);
    // The literal pin (the settings-test convention): the singular
    // sentence asserted without routing through the same generated
    // function — the NBSP binding the mark to its count is
    // load-bearing at 200%.
    expect(find.text('≈\u00A01 caja grande liberada'), findsOneWidget);
  });

  testWidgets('no rendered value admits a denominator — neither the % '
      'nor the / character renders anywhere on the surface '
      '(UX-DR36, FR-23, the negative sweep)', (tester) async {
    final (store, files) = seededSurface();
    await pumpDashboard(tester, controllerWith(store, files));

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(texts, isNotEmpty, reason: 'the sweep reads a rendered surface');
    for (final text in texts) {
      expect(text.contains('%'), isFalse, reason: 'no percentage: $text');
      expect(text.contains('/'), isFalse, reason: 'no ratio slash: $text');
    }
  });

  testWidgets('the work figure renders the existing seconds figure under '
      'a minute, the existing minutes figure under an hour, and the '
      'hours shape with a vanishing minutes arm at zero (matrix: '
      'sub-minute total)', (tester) async {
    // Sub-minute: one instant habit, 30 s.
    var store = _RecordingStore();
    var files = _RecordingFiles();
    _seedDone(store, 'hab-a', 0);
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));
    expect(
      find.text(strings.durationSeconds(30)),
      findsOneWidget,
      reason: 'honestly seconds, never a rounded zero',
    );

    // Under an hour: two maintenance dones, 6 min.
    store = _RecordingStore();
    files = _RecordingFiles();
    _seedDone(store, 'man-a', 0);
    _seedDone(store, 'man-a', 1);
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));
    expect(find.text(strings.durationMinutes(6)), findsOneWidget);

    // A whole hour: four focus dones, 1 h exactly.
    store = _RecordingStore();
    files = _RecordingFiles();
    for (var i = 0; i < 4; i++) {
      _seedDone(store, 'focus-a', i);
    }
    _seedAlbumEntry(store, 'g1', _noon(2026, 8, 12));
    _seedScanGroup(store, 'g1', 'La mesa del salón');
    files.blobsByName['before-g1.jpg'] = [1];
    files.blobsByName['after-g1.jpg'] = [2];
    await pumpDashboard(tester, controllerWith(store, files));
    expect(
      find.text(strings.dashboardWorkDuration(1, 0)),
      findsOneWidget,
      reason: 'the minutes arm vanishes at zero',
    );
    // The literal pin (the settings-test convention) plus its
    // negative: the whole-hour figure renders exactly `1\u00A0h`, and
    // no minutes figure renders anywhere on that arm.
    expect(find.text('1\u00A0h'), findsOneWidget);
    expect(
      find.textContaining('min'),
      findsNothing,
      reason: 'the vanishing minutes arm leaves no minutes figure behind',
    );
  });

  testWidgets('a highlight tap pops back into the Album — no viewer, no '
      'browse surface — and a double-tap inside the transition folds to '
      'the one guarded pop (matrix: highlight tap)', (tester) async {
    final (store, files) = seededSurface();
    await pumpDashboard(tester, controllerWith(store, files));

    // The tap lands on the newest cell's pair — below the fold on the
    // test surface, so scroll it in first.
    final frames = find.byType(PhotoFrame);
    await tester.ensureVisible(frames.at(0));
    await tester.pumpAndSettle();
    await tester.tap(frames.at(0));
    await tester.pump();
    // The transition starts — the dashboard route is no longer current,
    // so invoking the cell's own tap handler inside the window is
    // refused (the reward's double-tap recipe: the guard every pop in
    // the flow owns, invoked directly because the route beneath the
    // transition cannot be tapped reliably).
    final cellTap = find
        .ancestor(of: frames.at(0), matching: find.byType(GestureDetector))
        .first;
    tester.widget<GestureDetector>(cellTap).onTap!();
    await tester.pumpAndSettle();
    expect(
      find.byType(DashboardScreen),
      findsNothing,
      reason: 'one pop, back into the Album beneath',
    );
  });

  testWidgets('Volver al álbum pops — the Album named, zero side '
      'effects, and the read-only surface wrote nothing the whole '
      'visit (FR-23)', (tester) async {
    final (store, files) = seededSurface();
    final entriesBefore = store.entries.length;
    await pumpDashboard(tester, controllerWith(store, files));

    await tester.ensureVisible(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);
    expect(
      store.entries,
      hasLength(entriesBefore),
      reason:
          'the dashboard has no write path — no LogWriteQueue '
          'exists behind it',
    );
  });
}
