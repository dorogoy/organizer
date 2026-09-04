import 'package:core/ports/slicer_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture/capture_controller.dart';
import 'capture/dictation_controller.dart';
import 'crash.dart';
import 'dispenser/dispenser_controller.dart';
import 'egress/slicer_factory.dart';
import 'files/app_files.dart';
import 'platform/credentials/credentials_cipher.dart';
import 'platform/dictate/dictate_recognizer.dart';
import 'session/session_controller.dart';
import 'session/log_write_queue.dart';
import 'settings/settings_controller.dart';
import 'store/bootstrap.dart';
import 'strings/app_strings.dart';
import 'strings/app_strings_es.dart';
import 'ui/dispenser/dispenser_screen.dart';
import 'ui/theme.dart';
import 'vault/credential_vault.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The substrate comes up before the first frame: the drift database is
  // wired once, and the crash guard — the build's only diagnostics
  // destination — is installed before runApp so nothing can escape it.
  final store = openStore();
  installCrashGuard(store);
  final logWrites = LogWriteQueue();
  // The `dictate` channel's one adapter (FR-32): the channel's
  // method-call handler is per-channel, so a single instance is
  // constructed here and threaded to every consumer — the dictation
  // seam and the Settings surface's permission reads alike.
  final recognizer = DictateRecognizer();
  // The credential vault (Story 4.3, AD-22): the Files adapter over
  // app-private storage and the `credentials` channel's one cipher
  // seam, composed into the one vault the shell owns. Constructed
  // here — the channel registration and the vault's wiring crash
  // nothing at boot — and threaded into the shell root for story
  // 4-4's Settings surfaces to consume; no surface reads it yet, and
  // the vault itself reads and writes nothing until asked.
  final vault = CredentialVault(
    files: AppFiles(),
    cipher: CredentialsChannelCipher(),
  );
  // The Settings seam (Story 4-4): the same store the whole shell
  // holds, the recognizer, and now the vault — the IA y voz key
  // path's one persistence surface. Constructed here so the slicer
  // below can read the provider selection through it.
  final settings = SettingsController(
    store: store,
    recognizer: recognizer,
    vault: vault,
  );
  // The Slicer (Story 4-4, AD-9): the factory composes it inside the
  // egress module — the one place an HTTP client may be constructed
  // — over the vault and the settings derivation's per-call reader.
  // Threaded into the shell root for the Dispenser's rescue path
  // (Story 4-6), the port's one production call site.
  final slicer = buildSlicer(
    vault: vault,
    readSelectedProvider: settings.readSelectedProvider,
    localCannedMarker: AppStringsEs().localSlicerCannedMarker,
  );
  // The session lifecycle wiring (AD-19) sits beside the crash guard:
  // app opens and backgroundings become log facts — `app_opened`, the
  // session's first `card_dealt`, `session_ended`. The launch open runs
  // unawaited inside so the first frame never waits on the store; the
  // catalogue loads once there too.
  final session = installSessionController(
    store: store,
    strings: AppStringsEs(),
    writeQueue: logWrites,
  );
  // The Dispenser (Story 1.8) is the home: it reads the launch deal
  // through the same store, and the double asset read behind the shared
  // catalogue is benign — rootBundle caches bytes. The Settings seam
  // (Story 2.1) holds the same store too: one substrate under the whole
  // shell, threaded through the way-out chain the footer opens.
  runApp(
    ProviderScope(
      child: OrganizerApp(
        dispenser: DispenserController(
          store: store,
          strings: AppStringsEs(),
          writeQueue: logWrites,
          // The Slicer (Story 4-6, AD-9): the Dispenser's rescue path
          // is the port's one production call site — the same instance
          // main composed through the egress factory, threaded here so
          // the one control's ask and the auto-heuristic's fire reach
          // the BYOK path without the surface ever naming a provider,
          // a key or a network.
          slicer: slicer,
        ),
        sessionSettled: () => session.settled,
        settings: settings,
        // The Manual Capture seam (Story 3.2): same store, same shared
        // write queue — a capture's fact and entry serialize against
        // every other write the shell owns.
        capture: CaptureController(store: store, writeQueue: logWrites),
        // The dictation seam (Story 3.4): same store, same shared
        // write queue — a refusal's `permission_refused` entry
        // serializes against every other write too, and the capsule's
        // visibility derives from the probe and the log alone.
        dictation: DictationController(
          store: store,
          recognizer: recognizer,
          writeQueue: logWrites,
        ),
        // The credential vault (Story 4.3): one instance, constructed
        // in main beside the cipher seam it consumes — the Settings
        // key path (4-4) is its first reader, and nothing here pulls
        // it into a surface early.
        vault: vault,
        // The Slicer (Story 4-4, AD-9): threaded like the vault and
        // unread until Rescue Mode (4-6) — the port ships with no
        // production call site, exactly as 4-2's dispatch did.
        slicer: slicer,
      ),
    ),
  );
}

/// The shell root: Riverpod's ProviderScope wraps the whole app (shell-only
/// state management; the core is a pure function and holds no state).
///
/// The optional controller params are the test seam: main constructs them
/// with the same store the session wiring holds; a test may construct the
/// shell without them, and home stays the placeholder in that case.
class OrganizerApp extends StatelessWidget {
  const OrganizerApp({
    super.key,
    this.dispenser,
    this.sessionSettled,
    this.settings,
    this.capture,
    this.dictation,
    this.vault,
    this.slicer,
  });

  final DispenserController? dispenser;
  final Future<void> Function()? sessionSettled;

  /// The Settings seam (Story 2.1), threaded into the Dispenser's footer
  /// and down the way-out chain — same store, one substrate.
  final SettingsController? settings;

  /// The Manual Capture seam (Story 3.2), threaded into the Dispenser's
  /// Lápiz entry — same store, same shared write queue.
  final CaptureController? capture;

  /// The dictation seam (Story 3.4), threaded into the capture surface
  /// beside the capture seam — same store, same shared write queue.
  final DictationController? dictation;

  /// The credential vault (Story 4.3, AD-22), constructed once in
  /// main — the shell's only seal/unseal composition, consumed by
  /// the Settings key path since 4-4.
  final CredentialVault? vault;

  /// The Slicer (Story 4-4, AD-9), composed once in main through the
  /// egress factory — threaded and unread until Rescue Mode (4-6)
  /// calls it. No surface reaches it; the field exists so the
  /// shell's composition stays visible at the root.
  final SlicerPort? slicer;

  @override
  Widget build(BuildContext context) {
    final dispenser = this.dispenser;
    return MaterialApp(
      // Light/dark follows the system — ThemeMode.system, no in-app
      // override row (NFR19). Both themes are authored from tokens.dart.
      theme: OrganizerTheme.light(),
      darkTheme: OrganizerTheme.dark(),
      themeMode: ThemeMode.system,
      // The shipped ARB is the string table (AD-15); the accessors in
      // lib/strings/ are generated from it.
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: dispenser == null
          ? const SizedBox.shrink()
          : DispenserScreen(
              controller: dispenser,
              sessionSettled: sessionSettled,
              settings: settings,
              capture: capture,
              dictation: dictation,
            ),
    );
  }
}
