// The IA y voz access section's contract (Story 4-4, FR-28, AD-9,
// AD-10, AD-22): the provider pills and terms sentences render from
// the frozen allowlist through the ARB; a selection writes exactly
// one `selected_provider` row and reads back as the marked pill; the
// quiet key field saves on submit, deletes on empty submit, scopes
// per provider (a switch never touches another provider's key), and
// renders no availability or status badge anywhere; the free-tier
// sentence states exactly once in the whole tree, and no provider or
// key vocabulary renders anywhere outside the group.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/files/app_files.dart';
import 'package:organizer/platform/credentials/credentials_cipher.dart';
import 'package:organizer/settings/settings_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/settings/settings_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/vault/credential_vault.dart';

/// The recording store (the settings suite's own contract).
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

/// A store whose `setting_changed` append waits on [gate] — the
/// in-flight pill-write race for the key submit path.
class _DelaySettingAppendStore implements StorePort {
  _DelaySettingAppendStore(this._inner, this.gate);

  final _RecordingStore _inner;
  final Completer<void> gate;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == 'setting_changed') {
      await gate.future;
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose every `setting_changed` append throws — the
/// write-failure row for the quiet-failure paths (the settings
/// suite's own shape).
class _FailSettingAppendStore implements StorePort {
  _FailSettingAppendStore(this._inner);

  final _RecordingStore _inner;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == 'setting_changed') {
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// An in-memory Files fake, the vault suite's own shape — with a
/// failing-write knob for the quiet-failure paths.
class _FakeFiles implements FilesPort {
  final Map<String, List<int>> blobs = {};

  /// The next that many writes throw, once each.
  int failWrites = 0;

  @override
  Future<List<int>?> read(String scope, String name) async =>
      blobs['$scope/$name'];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    if (failWrites > 0) {
      failWrites--;
      throw StateError('disk full');
    }
    blobs['$scope/$name'] = List.of(bytes);
  }

  @override
  Future<void> delete(String scope, String name) async =>
      blobs.remove('$scope/$name');
}

/// A transparent cipher: the envelope is the plaintext, so a saved
/// key is readable in the fake store verbatim.
class _TransparentCipher implements CredentialsCipher {
  const _TransparentCipher();

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async =>
      (envelope: List<int>.of(plaintext), failure: null);

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async =>
      (plaintext: List<int>.of(envelope), failure: null);
}

LogEntryRecord seededProvider(String id, {int at = 100}) => (
  id: 'seed-$id',
  kind: 'setting_changed',
  instantUtcMicros: at,
  offsetSeconds: 0,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: 'selected_provider',
  settingValue: null,
  settingTextValue: id,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: null,
  reportWeek: null,
  permission: null,
);

/// The harness record: everything one test needs over one store.
typedef Harness = ({
  _RecordingStore store,
  _FakeFiles files,
  CredentialVault vault,
  SettingsController controller,
});

void main() {
  // The harness is built inside each test body, never in setUp: the
  // controller's write chain must live in the test's own zone for
  // the pumps to drive it (the settings suite's own discipline).
  Harness harness() {
    final store = _RecordingStore();
    final files = _FakeFiles();
    final vault = CredentialVault(
      files: files,
      cipher: const _TransparentCipher(),
    );
    return (
      store: store,
      files: files,
      vault: vault,
      controller: SettingsController(
        store: store,
        vault: vault,
        nowOf: () => DateTime.utc(2026, 9, 3, 12),
      ),
    );
  }

  Future<void> pumpSettings(
    WidgetTester tester,
    SettingsController controller,
  ) async {
    await tester.binding.setSurfaceSize(const ui.Size(320, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The texts the whole tree carries, every channel included.
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

  testWidgets('the pills and terms render from the frozen allowlist, '
      'selection writes selected_provider and reads back', (tester) async {
    final h = harness();
    final store = h.store;
    final controller = h.controller;
    await pumpSettings(tester, controller);
    final es = AppStringsEs();

    // Four pills, each with its terms line beneath.
    for (final name in [
      es.providerNameGemini,
      es.providerNameOpenai,
      es.providerNameAnthropic,
      es.providerNameOpenrouter,
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      find.textContaining('Términos sin entrenamiento verificados el'),
      findsNWidgets(4),
    );
    // Nothing selected yet: no pill carries the selected fill.
    expect(selectedProviderId(tester), isNull);

    await tester.tap(find.text(es.providerNameAnthropic));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final rows = store.entries
        .where((entry) => entry.kind == 'setting_changed')
        .toList();
    expect(rows, hasLength(1));
    expect(rows.single.settingKey, 'selected_provider');
    expect(rows.single.settingTextValue, 'anthropic');
    expect(rows.single.settingValue, isNull);
    expect(selectedProviderId(tester), 'anthropic');

    // Re-tapping the current selection writes nothing.
    await tester.tap(find.text(es.providerNameAnthropic));
    await tester.pumpAndSettle();
    expect(
      store.entries.where((entry) => entry.kind == 'setting_changed'),
      hasLength(1),
    );
  });

  testWidgets('a seeded selection derives its pill on open — the log is '
      'the only source of the selection (AD-1)', (tester) async {
    final h = harness();
    h.store.entries.add(seededProvider('openai'));
    await pumpSettings(tester, h.controller);
    expect(selectedProviderId(tester), 'openai');
  });

  test('the controller refuses an unallowlisted id with silence — '
      'no row lands', () async {
    final h = harness();
    final store = h.store;
    final controller = h.controller;
    await controller.writeSelectedProvider('some_other_provider');
    await controller.writeSelectedProvider('../traversal');
    await controller.writeSelectedProvider('');
    expect(
      store.entries.where((entry) => entry.kind == 'setting_changed'),
      isEmpty,
    );
  });

  testWidgets('a key submit saves into the vault under the selected '
      'provider, and the field clears — no badge appears', (tester) async {
    final h = harness();
    final files = h.files;
    final controller = h.controller;
    await pumpSettings(tester, controller);
    final es = AppStringsEs();
    await tester.tap(find.text(es.providerNameGemini));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).obscureText,
      isTrue,
      reason: 'the key entry is quiet by construction',
    );
    expect(tester.widget<TextField>(field).autocorrect, isFalse);
    expect(tester.widget<TextField>(field).enableSuggestions, isFalse);
    expect(
      tester.widget<TextField>(field).smartDashesType,
      SmartDashesType.disabled,
    );
    expect(
      tester.widget<TextField>(field).smartQuotesType,
      SmartQuotesType.disabled,
    );
    expect(tester.widget<TextField>(field).autofillHints, isEmpty);

    final beforeSave = textsOf(tester).toSet();
    await tester.enterText(field, 'g-key-xyz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      utf8Decode(files.blobs['$credentialFilesScope/gemini']),
      'g-key-xyz',
    );
    expect(
      tester.widget<TextField>(field).controller?.text,
      isEmpty,
      reason: 'the field is an entry point, never a display',
    );
    // No availability or status badge: the tree's texts are exactly
    // what they were — nothing learned that a key now exists.
    expect(textsOf(tester).toSet(), beforeSave);
  });

  testWidgets('an empty submit deletes — idempotently, quietly', (
    tester,
  ) async {
    final h = harness();
    final files = h.files;
    final controller = h.controller;
    await pumpSettings(tester, controller);
    final es = AppStringsEs();
    await tester.tap(find.text(es.providerNameGemini));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, 'g-key-xyz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(files.blobs.containsKey('$credentialFilesScope/gemini'), isTrue);

    // The empty submit deletes what stood.
    await tester.enterText(field, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(files.blobs.containsKey('$credentialFilesScope/gemini'), isFalse);

    // And on nothing stored, the same submit is the same quiet no-op.
    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(files.blobs.containsKey('$credentialFilesScope/gemini'), isFalse);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('switching providers never touches the other provider\'s '
      'key — per-provider scoping', (tester) async {
    final h = harness();
    final files = h.files;
    final controller = h.controller;
    await pumpSettings(tester, controller);
    final es = AppStringsEs();

    await tester.tap(find.text(es.providerNameGemini));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'g-key');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text(es.providerNameOpenai));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'o-key');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(utf8Decode(files.blobs['$credentialFilesScope/gemini']), 'g-key');
    expect(utf8Decode(files.blobs['$credentialFilesScope/openai']), 'o-key');

    // B unkeyed leaves A's envelope untouched: selecting B and saving
    // nothing does not delete A.
    await tester.tap(find.text(es.providerNameAnthropic));
    await tester.pumpAndSettle();
    expect(utf8Decode(files.blobs['$credentialFilesScope/gemini']), 'g-key');
    expect(utf8Decode(files.blobs['$credentialFilesScope/openai']), 'o-key');
    expect(files.blobs.containsKey('$credentialFilesScope/anthropic'), isFalse);
  });

  testWidgets('a key submit with no provider selected stores nothing', (
    tester,
  ) async {
    final h = harness();
    final files = h.files;
    final controller = h.controller;
    await pumpSettings(tester, controller);
    await tester.enterText(find.byType(TextField), 'orphan-key');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(files.blobs, isEmpty);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('the free-tier sentence states exactly once in the whole '
      'tree — and no provider or key vocabulary renders outside the '
      'group', (tester) async {
    final h = harness();
    final controller = h.controller;
    await pumpSettings(tester, controller);
    final es = AppStringsEs();

    // Exactly once, below the key field, in the IA y voz group (the
    // census reads a set: one widget reports through several
    // channels).
    expect(
      textsOf(tester)
          .where((text) => text == es.settingsProviderKeyFreeTierNote)
          .toSet(),
      hasLength(1),
    );

    // The Dispenser never learns any of this exists: a bare surface
    // with the same delegates renders none of the vocabulary.
    final dispenserTexts = await _textsOfBareDispenser(tester);
    for (final forbidden in [
      es.settingsProviderKeyFreeTierNote,
      es.settingsProviderKeyLabel,
      es.providerNameGemini,
      es.providerNameOpenai,
      es.providerNameAnthropic,
      es.providerNameOpenrouter,
    ]) {
      expect(dispenserTexts, isNot(contains(forbidden)));
    }
  });

  group('the review patches (4-4 review round)', () {
    testWidgets('a key submit during an in-flight pill write waits for '
        'the write and scopes to the new provider', (tester) async {
      final h = harness();
      final gate = Completer<void>();
      final delayed = _DelaySettingAppendStore(h.store, gate);
      final controller = SettingsController(
        store: delayed,
        vault: h.vault,
        nowOf: () => DateTime.utc(2026, 9, 3, 12),
      );
      await pumpSettings(tester, controller);
      await tester.tap(find.text(AppStringsEs().providerNameGemini));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'g-race-key');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        h.files.blobs,
        isEmpty,
        reason: 'submit waits on the in-flight write',
      );
      gate.complete();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        utf8Decode(h.files.blobs['$credentialFilesScope/gemini']),
        'g-race-key',
      );
    });

    testWidgets('a fast submit against a seeded selection waits for the '
        'read and saves the key — the log\'s truth, not the field\'s '
        'timing', (tester) async {
      final h = harness();
      h.store.entries.add(seededProvider('gemini'));
      await tester.binding.setSurfaceSize(const ui.Size(320, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: SettingsScreen(controller: h.controller),
        ),
      );
      // No settle: the surface's first frame is up, the selection
      // read is still in flight, and the paste-and-submit lands now.
      await tester.enterText(find.byType(TextField), 'g-fast-key');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        utf8Decode(h.files.blobs['$credentialFilesScope/gemini']),
        'g-fast-key',
        reason:
            'the submit scopes against the seeded selection once the '
            'read resolves',
      );
      // The field cleared either way — an entry point, never a
      // display.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('a pill tap whose setting append throws stays quiet — no '
        'ErrorWidget, no message, no selection', (tester) async {
      final h = harness();
      final failing = _FailSettingAppendStore(h.store);
      final controller = SettingsController(
        store: failing,
        vault: h.vault,
        nowOf: () => DateTime.utc(2026, 9, 3, 12),
      );
      await pumpSettings(tester, controller);
      await tester.tap(find.text(AppStringsEs().providerNameGemini));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(h.store.entries, isEmpty);
      expect(selectedProviderId(tester), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a key save whose vault write throws stays quiet — the '
        'vault\'s own silence, nothing surfaced', (tester) async {
      final h = harness();
      h.files.failWrites = 1;
      await pumpSettings(tester, h.controller);
      await tester.tap(find.text(AppStringsEs().providerNameGemini));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'g-key');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(h.files.blobs, isEmpty, reason: 'the write refused, quietly');
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a replaced controller re-reads the selection — no stale '
        'pills', (tester) async {
      final first = harness();
      await pumpSettings(tester, first.controller);
      expect(selectedProviderId(tester), isNull);

      // The same tree shape with a second controller over a seeded
      // log: the state is reused, so the re-read rides
      // didUpdateWidget.
      final second = harness();
      second.store.entries.add(seededProvider('anthropic'));
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: SettingsScreen(controller: second.controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(selectedProviderId(tester), 'anthropic');
    });
  });
}

String utf8Decode(List<int>? bytes) => bytes == null ? '' : utf8.decode(bytes);

/// The pill whose Material carries the selected fill, by provider id —
/// the settings suite's selected-grammar helper, over the section's
/// own pills.
String? selectedProviderId(WidgetTester tester) {
  final es = AppStringsEs();
  final namesById = {
    'gemini': es.providerNameGemini,
    'openai': es.providerNameOpenai,
    'anthropic': es.providerNameAnthropic,
    'openrouter': es.providerNameOpenrouter,
  };
  for (final entry in namesById.entries) {
    final text = find.text(entry.value);
    if (text.evaluate().isEmpty) {
      continue;
    }
    final material = find
        .ancestor(of: text, matching: find.byType(Material))
        .first;
    final color = tester.widget<Material>(material).color;
    if (color == OrganizerTheme.light().colorScheme.primary) {
      return entry.key;
    }
  }
  return null;
}

Future<List<String>> _textsOfBareDispenser(WidgetTester tester) async {
  // The Dispenser over an empty catalogue (the app suite's own
  // harness): its whole rendered vocabulary, censused.
  await tester.pumpWidget(
    MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: DispenserScreen(
        controller: DispenserController(
          store: _RecordingStore(),
          strings: AppStringsEs(),
          bundle: _EmptyCatalogueBundle(),
          nowOf: () => DateTime.utc(2026, 9, 3, 12),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final texts = <String?>[
    for (final text in tester.widgetList<Text>(find.byType(Text))) text.data,
    for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
      rich.text.toPlainText(),
  ];
  return [
    for (final value in texts)
      if (value != null && value.isNotEmpty) value,
  ];
}

/// A bundle over an empty catalogue (the app suite's own shape), so
/// the Dispenser runs fully offline.
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
