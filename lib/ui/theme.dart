// System-follow theming (NFR19): the app follows the system light/dark
// choice — ThemeMode.system — and carries no in-app override row. The dark
// theme is DarkPalette's own authorship, never an inversion (UX-DR12).
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class OrganizerTheme {
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark
        ? DarkPalette.surfaceBaseDark
        : FieldPalette.surfaceBase;
    final raised = dark
        ? DarkPalette.surfaceRaisedDark
        : FieldPalette.surfaceRaised;
    final ink = dark ? DarkPalette.inkPrimaryDark : FieldPalette.inkPrimary;
    final inkSecondary = dark
        ? DarkPalette.inkSecondaryDark
        : FieldPalette.inkSecondary;
    final hairline = dark
        ? DarkPalette.borderHairlineDark
        : FieldPalette.borderHairline;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: raised,
      secondary: inkSecondary,
      onSecondary: surface,
      // The system admits no alarm register (no red as alarm, no error
      // fills), so the required error pair carries the ordinary ink and
      // raised tones — nothing in the app styles itself as an error.
      error: ink,
      onError: raised,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: raised,
      onSurfaceVariant: inkSecondary,
      outline: hairline,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: FontFamilies.lexend,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: _textTheme(dark),
    );
  }

  /// The eight roles wired into the nearest TextTheme slots; every style is
  /// fully specified from [TypeRoles], so no slot default leaks through.
  /// Dark mode swaps the ink per role — ink-primary roles take
  /// [DarkPalette.inkPrimaryDark], ink-secondary roles
  /// [DarkPalette.inkSecondaryDark] — the sizes, faces and line-heights are
  /// untouched.
  static TextTheme _textTheme(bool dark) {
    final ink = dark ? DarkPalette.inkPrimaryDark : FieldPalette.inkPrimary;
    final inkSecondary = dark
        ? DarkPalette.inkSecondaryDark
        : FieldPalette.inkSecondary;
    return TextTheme(
      headlineMedium: TypeRoles.task.copyWith(color: ink),
      headlineSmall: TypeRoles.screenHeading.copyWith(color: ink),
      titleLarge: TypeRoles.destinationLabel.copyWith(color: ink),
      titleMedium: TypeRoles.metricNumeral.copyWith(color: ink),
      titleSmall: TypeRoles.duration.copyWith(color: ink),
      bodyLarge: TypeRoles.actionPrimary.copyWith(color: ink),
      bodyMedium: TypeRoles.actionSecondary.copyWith(color: inkSecondary),
      bodySmall: TypeRoles.support.copyWith(color: inkSecondary),
    );
  }
}
