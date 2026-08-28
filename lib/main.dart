import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'strings/app_strings.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: OrganizerApp()));
}

/// The shell root: Riverpod's ProviderScope wraps the whole app (shell-only
/// state management; the core is a pure function and holds no state).
///
/// No surface and no strings here — Story 1.2 owns tokens and the ARB, and
/// Story 1.8 owns the Dispenser.
class OrganizerApp extends StatelessWidget {
  const OrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const SizedBox.shrink(),
    );
  }
}
