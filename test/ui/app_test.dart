// The shell wiring, pinned: ThemeMode.system with both token-authored
// themes (NFR19, UX-DR12) and the generated accessors' delegates (AD-15).
// No surface exists yet — this asserts the registration every later
// surface observes through Theme.of / AppStrings.of.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/main.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/ui/tokens.dart';

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

  testWidgets('the generated accessors resolve through the shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OrganizerApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.localizationsDelegates,
      containsAll(AppStrings.localizationsDelegates),
    );
    expect(app.supportedLocales, AppStrings.supportedLocales);

    // The home subtree resolves strings through the wired delegates.
    final home = tester.element(
      find.descendant(
        of: find.byType(Navigator),
        matching: find.byType(SizedBox),
      ),
    );
    expect(AppStrings.of(home).actionDone, 'Hecho');
  });
}
