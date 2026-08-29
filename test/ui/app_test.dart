// The shell wiring, pinned: ThemeMode.system with both token-authored
// themes (NFR19, UX-DR12), the generated accessors' delegates (AD-15),
// and the home the shell carries since Story 1.8 — the Dispenser,
// constructed by main with the same store the session wiring holds and
// by tests through the optional controller seam.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/main.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
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

  test('main wires the one store into both the session lifecycle and the '
      'Dispenser (the one-shell-edit regression pin)', () {
    final source = File('lib/main.dart').readAsStringSync();

    // Exactly one store is opened: a second construction would fork the
    // substrate under the shell's own crash guard.
    expect(
      source.split('openStore()').length - 1,
      1,
      reason: 'openStore() is called exactly once',
    );
    // The session wiring and the Dispenser read the same local store —
    // the launch deal the screen renders is the one the log holds.
    expect(
      RegExp(r'installSessionController\(\s*store: store').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'DispenserController\(\s*store: store').hasMatch(source),
      isTrue,
    );
    expect(source.contains('sessionSettled: () => session.settled'), isTrue);
  });
}
