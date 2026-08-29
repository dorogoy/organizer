import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash.dart';
import 'dispenser/dispenser_controller.dart';
import 'session/session_controller.dart';
import 'store/bootstrap.dart';
import 'strings/app_strings.dart';
import 'strings/app_strings_es.dart';
import 'ui/dispenser/dispenser_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The substrate comes up before the first frame: the drift database is
  // wired once, and the crash guard — the build's only diagnostics
  // destination — is installed before runApp so nothing can escape it.
  final store = openStore();
  installCrashGuard(store);
  // The session lifecycle wiring (AD-19) sits beside the crash guard:
  // app opens and backgroundings become log facts — `app_opened`, the
  // session's first `card_dealt`, `session_ended`. The launch open runs
  // unawaited inside so the first frame never waits on the store; the
  // catalogue loads once there too.
  final session = installSessionController(
    store: store,
    strings: AppStringsEs(),
  );
  // The Dispenser (Story 1.8) is the home: it reads the launch deal
  // through the same store, and the double asset read behind the shared
  // catalogue is benign — rootBundle caches bytes.
  runApp(
    ProviderScope(
      child: OrganizerApp(
        dispenser: DispenserController(store: store, strings: AppStringsEs()),
        sessionSettled: () => session.settled,
      ),
    ),
  );
}

/// The shell root: Riverpod's ProviderScope wraps the whole app (shell-only
/// state management; the core is a pure function and holds no state).
///
/// The optional controller param is the test seam: main constructs it with
/// the same store the session wiring holds; a test may construct the shell
/// without one, and home stays the placeholder in that case.
class OrganizerApp extends StatelessWidget {
  const OrganizerApp({super.key, this.dispenser, this.sessionSettled});

  final DispenserController? dispenser;
  final Future<void> Function()? sessionSettled;

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
            ),
    );
  }
}
