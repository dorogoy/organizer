// The shell wiring, pinned: ThemeMode.system with both token-authored
// themes (NFR19, UX-DR12), the generated accessors' delegates (AD-15),
// and the home the shell carries since Story 1.8 — the Dispenser,
// constructed by main with the same store the session wiring holds and
// by tests through the optional controller seam.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/derive/reward.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/album/album_controller.dart';
import 'package:organizer/capture/dictation_controller.dart';
import 'package:organizer/dashboard/dashboard_controller.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/genesis/genesis_controller.dart';
import 'package:organizer/main.dart';
import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/reward/reward_controller.dart';
import 'package:organizer/session/log_write_queue.dart';
import 'package:organizer/settings/settings_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/reward/reward_screen.dart';
import 'package:organizer/ui/settings/nuevo_proyecto_screen.dart';
import 'package:organizer/ui/tokens.dart';

/// A quiet store over an empty catalogue — the home resolves through it
/// without any deal standing (the close surface, itself a real state).
class _EmptyCatalogueStore implements StorePort {
  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {}

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async => const [];
}

class _EmptyCatalogueBundle implements AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ui.ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      '{"version":1,"entries":[]}';

  @override
  Future<T> loadStructuredData<T>(
    String key,
    FutureOr<T> Function(String value) parser,
  ) => loadString(key).then(parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => load(key).then(parser);

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

class _EmptyFiles implements FilesPort {
  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> sweepScanCache() async {}

  @override
  Future<void> sweepAlbum() async {}

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';
}

class _NoopCamera implements CameraShell {
  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {}

  @override
  Future<CameraOpenOutcome> open() async => CameraOpenOutcome.unavailable;

  @override
  Future<CameraShotOutcome> takePicture() async => const CameraShotNone();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shell follows the system theme with no override', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OrganizerApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.theme!.colorScheme.surface, FieldPalette.surfaceBase);
    expect(app.theme!.colorScheme.primary, FieldPalette.accentSoft);
    expect(app.theme!.colorScheme.onPrimary, FieldPalette.inkPrimary);
    expect(
      app.darkTheme!.colorScheme.surface,
      DarkPalette.surfaceBaseDark,
      reason: 'the dark palette is separately authored (UX-DR12)',
    );
    expect(app.darkTheme!.colorScheme.primary, DarkPalette.accentSoftDark);
    expect(app.darkTheme!.colorScheme.onPrimary, DarkPalette.inkPrimaryDark);
    // No override surface exists — theming is system-only (NFR19).
  });

  testWidgets('the generated accessors resolve through the shell and the '
      'home is the Dispenser (Story 1.8)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: _EmptyCatalogueStore(),
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.localizationsDelegates,
      containsAll(AppStrings.localizationsDelegates),
    );
    expect(app.supportedLocales, AppStrings.supportedLocales);

    // The home subtree is the Dispenser, and it resolves strings through
    // the wired delegates.
    final home = tester.element(find.byType(DispenserScreen));
    expect(AppStrings.of(home).actionDone, 'Hecho');
    expect(
      find.text(AppStrings.of(home).poolExhaustedClose),
      findsOneWidget,
      reason: 'the empty catalogue leaves the warm close standing',
    );
  });

  testWidgets('the settings seam is exercised: OrganizerApp hands its '
      'SettingsController down to the Dispenser home (Story 2.1)', (
    tester,
  ) async {
    final settings = SettingsController(store: _EmptyCatalogueStore());
    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: _EmptyCatalogueStore(),
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen),
    );
    expect(identical(dispenser.settings, settings), isTrue);
    // The read seam resolves over the empty log: the default bag.
    expect(await settings.readTimeBag(), 15);
  });

  testWidgets('the dictation seam is exercised: OrganizerApp hands its '
      'DictationController down to the Dispenser home (Story 3.4)', (
    tester,
  ) async {
    final dictation = DictationController(
      store: _EmptyCatalogueStore(),
      recognizer: _UnavailableRecognizer(),
      addObserver: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: _EmptyCatalogueStore(),
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          dictation: dictation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen),
    );
    expect(identical(dispenser.dictation, dictation), isTrue);
    // The seam resolves over the empty log and the absent platform:
    // the affordance derives absent, quietly.
    await tester.pump();
    expect(dictation.visible, isFalse);
    expect(dictation.listening, isFalse);
  });

  testWidgets('the reward and session-milestone seams reach the '
      'Dispenser home together (Story 7.1)', (tester) async {
    final store = _EmptyCatalogueStore();
    final reward = RewardController(
      store: store,
      files: _EmptyFiles(),
      camera: _NoopCamera(),
    );
    NamedRewardSpace? takeSessionMilestone() => null;

    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: store,
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          reward: reward,
          sessionMilestone: takeSessionMilestone,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen),
    );
    expect(identical(dispenser.reward, reward), isTrue);
    expect(identical(dispenser.sessionMilestone, takeSessionMilestone), isTrue);
  });

  testWidgets('the album seam is exercised: OrganizerApp hands its '
      'AlbumController down to the Dispenser home (Story 7.3)', (tester) async {
    final store = _EmptyCatalogueStore();
    final album = AlbumController(
      store: store,
      files: _EmptyFiles(),
      writeQueue: LogWriteQueue(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: store,
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          album: album,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen),
    );
    expect(identical(dispenser.album, album), isTrue);
  });

  testWidgets('the album seam hop-through: the milestone reward push '
      'carries the SAME controller into the reward screen (Story 7.3 — '
      'dropping either hand-down ships the gallery dead with every '
      'composition pin green)', (tester) async {
    final store = _EmptyCatalogueStore();
    final album = AlbumController(
      store: store,
      files: _EmptyFiles(),
      writeQueue: LogWriteQueue(),
    );
    final dashboard = DashboardController(
      store: store,
      files: _EmptyFiles(),
      loadCatalogue: () async => Catalogue(version: 1, entries: const []),
    );
    const space = (groupId: 'group-1', origin: Origin.cloud);

    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: store,
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          reward: RewardController(
            store: store,
            files: _EmptyFiles(),
            camera: _NoopCamera(),
          ),
          album: album,
          dashboard: dashboard,
          sessionMilestone: () => space,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reward = tester.widget<RewardScreen>(
      find.byType(RewardScreen, skipOffstage: false),
    );
    expect(identical(reward.album, album), isTrue);
    // And the 7.4 hop, one step further down the contextual chain:
    // the SAME dashboard controller reaches the reward screen too,
    // whose album push carries it to the gallery — the dashboard's one
    // entry point (Story 7.4, dropping either hand-down ships it dead
    // with every composition pin green).
    expect(identical(reward.dashboard, dashboard), isTrue);
    // The Dispenser holds the same seam it threaded.
    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen, skipOffstage: false),
    );
    expect(identical(dispenser.dashboard, dashboard), isTrue);
  });

  test(
    'main wires the one store into the session lifecycle, the '
    'Dispenser and the Settings seam (the one-shell-edit regression pin)',
    () {
      final source = File('lib/main.dart').readAsStringSync();

      // Exactly one store is opened: a second construction would fork the
      // substrate under the shell's own crash guard.
      expect(
        source.split('openStore()').length - 1,
        1,
        reason: 'openStore() is called exactly once',
      );
      // The session wiring, the Dispenser and the Settings seam read the
      // same local store — the launch deal the screen renders is the one
      // the log holds, and the bag the footer chain writes is the bag the
      // derivation reads.
      expect(
        RegExp(r'installSessionController\(\s*store: store').hasMatch(source),
        isTrue,
      );
      // The Files seam (Story 5.4): the open's scan-cache sweep — the
      // crash backstop — runs through the one standing AppFiles
      // instance; deleting the threading breaks this pin. The match
      // is bounded by the statement's terminating semicolon, so it
      // cannot reach the scan seam's own `files: files` below.
      expect(
        RegExp(r'installSessionController\([^;]*?files:\s*files')
            .hasMatch(source),
        isTrue,
        reason: 'the session wiring must hold the one Files adapter',
      );
      expect(
        RegExp(r'DispenserController\(\s*store: store').hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(r'SettingsController\(\s*store: store').hasMatch(source),
        isTrue,
        reason: 'the settings wiring must hold the same single store',
      );
      expect(source.contains('sessionSettled: () => session.settled'), isTrue);
      // The dictation seam (Story 3.4) rides the same store and the one
      // channel adapter — deleting the threading breaks this pin.
      expect(
        RegExp(r'DictationController\(\s*store: store').hasMatch(source),
        isTrue,
        reason: 'the dictation wiring must hold the same single store',
      );
      expect(
        source.contains('dictation: DictationController('),
        isTrue,
        reason: 'the Dispenser home receives the dictation seam',
      );
      // The rescue seam (Story 4.6) rides the same composed slicer —
      // a null here would quietly decline every ask and suppress the
      // auto-heuristic with the suite green.
      expect(
        RegExp(r'DispenserController\([\s\S]*?slicer:\s*slicer')
            .hasMatch(source),
        isTrue,
        reason: 'the Dispenser rescue path must hold the composed slicer',
      );
      // The consent phase (Story 5.5) rides the same composed slicer
      // and the settings derivation's provider read — optional named
      // args vanish silently, so dropping either seam would render the
      // gate dead in production (accept folds stale) with every suite
      // green. Bounded by the statement's semicolon, like the Files
      // pin above, so the Dispenser's own `slicer:` cannot satisfy it.
      expect(
        RegExp(r'ScanController\([^;]*?slicer:\s*slicer').hasMatch(source),
        isTrue,
        reason: 'the scan consent phase must hold the composed slicer',
      );
      expect(
        RegExp(
          r'ScanController\([^;]*?readSelectedProvider:\s*settings\.readSelectedProvider',
        ).hasMatch(source),
        isTrue,
        reason:
            'the pre-gate availability read must come from the '
            'settings derivation',
      );
      // The typed genesis seam (Story 5.8) rides the same composed
      // slicer, the same settings read and the one shared write
      // queue — optional named args vanish silently, so dropping the
      // seam would ship typed genesis dead (the pill disabled in
      // production, `Nuevo proyecto` answering nothing) with every
      // suite green. Bounded by the statement's semicolon, like the
      // pins above, so the scan seam's own `slicer:` cannot satisfy
      // it.
      expect(
        RegExp(r'GenesisController\([^;]*?slicer:\s*slicer').hasMatch(source),
        isTrue,
        reason: 'the typed genesis channel must hold the composed slicer',
      );
      expect(
        RegExp(
          r'GenesisController\([^;]*?readSelectedProvider:\s*settings\.readSelectedProvider',
        ).hasMatch(source),
        isTrue,
        reason:
            'the fail-closed provider read must come from the '
            'settings derivation, the scan seam\'s own rule',
      );
      expect(
        RegExp(r'GenesisController\([^;]*?writeQueue:\s*logWrites')
            .hasMatch(source),
        isTrue,
        reason: 'the genesis rows ride the one shared write queue',
      );
      // The dashboard seam (Story 7.4, FR-23) rides the same store and
      // the one Files adapter, and holds NO write queue — the surface
      // is read-only by construction. Bounded by the statement's
      // semicolon, like the pins above, so the Dispenser's own
      // `store:` cannot satisfy it.
      expect(
        RegExp(r'DashboardController\([^;]*?store:\s*store').hasMatch(source),
        isTrue,
        reason: 'the dashboard wiring must hold the same single store',
      );
      expect(
        RegExp(r'DashboardController\([^;]*?files:\s*files').hasMatch(source),
        isTrue,
        reason: 'the dashboard wiring must hold the one Files adapter',
      );
      expect(
        RegExp(
          r'DashboardController\([^;]*?loadCatalogue:\s*\(\)\s*=>\s*loadEvergreenCatalogue',
        ).hasMatch(source),
        isTrue,
        reason: 'the catalogue read must come from the shell\'s loader',
      );
      // And the dashboard's own two hand-downs inside main.dart: the
      // OrganizerApp construction and the Dispenser home it builds —
      // losing either ships the cumulative impact surface unreachable
      // from the Album, with every composition pin above still green
      // (the 7.3 seam-hop lesson, one hop further).
      expect(
        source.split('dashboard: dashboard,').length - 1,
        2,
        reason:
            'the dashboard seam is handed down twice inside main.dart — '
            'OrganizerApp and the Dispenser home it builds',
      );
      // And both hand-downs inside main.dart: the OrganizerApp
      // construction and the Dispenser home it builds — losing
      // either orphans the seam with the composition pins above
      // still green.
      expect(
        source.split('genesis: genesis,').length - 1,
        2,
        reason:
            'the seam is handed down twice inside main.dart — '
            'OrganizerApp and the Dispenser home it builds',
      );
    },
  );

  testWidgets('the genesis seam is exercised: OrganizerApp hands its '
      'GenesisController down to the `Nuevo proyecto` surface (Story '
      '5.8, FR-11)', (tester) async {
    final genesis = GenesisController(store: _EmptyCatalogueStore());
    await tester.pumpWidget(
      ProviderScope(
        child: OrganizerApp(
          dispenser: DispenserController(
            store: _EmptyCatalogueStore(),
            strings: AppStringsEs(),
            bundle: _EmptyCatalogueBundle(),
          ),
          genesis: genesis,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dispenser = tester.widget<DispenserScreen>(
      find.byType(DispenserScreen),
    );
    expect(identical(dispenser.genesis, genesis), isTrue);

    // And the third hop, through the real push: the footer's quiet
    // departure opens the typed genesis surface carrying the SAME
    // controller — deleting the hand-off at the push site renders
    // the surface controller-less with every composition pin green.
    await tester.tap(find.text('Nuevo proyecto'));
    await tester.pumpAndSettle();
    final surface = tester.widget<NuevoProyectoScreen>(
      find.byType(NuevoProyectoScreen),
    );
    expect(identical(surface.genesis, genesis), isTrue);
  });
}

/// The dictation seam's absent platform: a recognizer that answers
/// unavailable and never emits — enough for the wiring pin, whose
/// business is the threading, not the listening.
class _UnavailableRecognizer implements RecognizerPort {
  @override
  Future<RecognizerAvailability> probe() async =>
      RecognizerAvailability.unavailable;

  @override
  Future<RecognizerStart> start(int sessionId) async =>
      RecognizerStart.unavailable;

  @override
  Future<void> cancel(int sessionId) async {}

  @override
  Stream<RecognizerOutcome> get outcomes => const Stream.empty();

  @override
  Future<void> openAppSettings() async {}
}
