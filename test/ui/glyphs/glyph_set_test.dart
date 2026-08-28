// The glyph set's closing checks (DESIGN.md {components.icon-glyph}): the
// ten shipped glyphs — never eleven, no Ajustes — each pinned by a golden
// image in both palettes, with the shared treatment's semantics (tier
// colours, the registered exception) asserted on the painters themselves.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/ui/glyphs/album_glyph.dart';
import 'package:organizer/ui/glyphs/bag_glyph.dart';
import 'package:organizer/ui/glyphs/battery_glyph.dart';
import 'package:organizer/ui/glyphs/box_glyph.dart';
import 'package:organizer/ui/glyphs/camera_glyph.dart';
import 'package:organizer/ui/glyphs/clock_glyph.dart';
import 'package:organizer/ui/glyphs/glyph_canvas.dart';
import 'package:organizer/ui/glyphs/leaf_glyph.dart';
import 'package:organizer/ui/glyphs/microphone_glyph.dart';
import 'package:organizer/ui/glyphs/pencil_glyph.dart';
import 'package:organizer/ui/glyphs/seed_glyph.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

void main() {
  // (glyph constructor, golden name, light mass, dark mass, light line,
  // dark line, registered)
  final allGlyphs =
      <(Widget Function(), String, Color, Color, Color, Color, bool)>[
        (
          () => const CameraGlyph(48),
          'camera',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const AlbumGlyph(48),
          'album',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const BoxGlyph(48),
          'box',
          IconMassPalette.destKeep,
          DarkPalette.destKeepDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const BagGlyph(48),
          'bag',
          IconMassPalette.destDonate,
          DarkPalette.destDonateDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const ClockGlyph(48),
          'clock',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const LeafGlyph(48),
          'leaf',
          IconMassPalette.iconMassOchre,
          DarkPalette.iconMassOchreDark,
          // The zone marker renders quiet — ink-secondary, not ink-primary.
          FieldPalette.inkSecondary,
          DarkPalette.inkSecondaryDark,
          false,
        ),
        (
          () => const PencilGlyph(48),
          'pencil',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const SeedGlyph(48),
          'seed',
          IconMassPalette.destTrash,
          DarkPalette.destTrashDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          false,
        ),
        (
          () => const BatteryGlyph(48, level: BatteryLevel.medium),
          'battery',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          // Unselected: the neutral charge and the ink-secondary casing.
          FieldPalette.inkSecondary,
          DarkPalette.inkSecondaryDark,
          true,
        ),
        (
          () => const MicrophoneGlyph(48),
          'microphone',
          IconMassPalette.iconMassNeutral,
          DarkPalette.iconMassNeutralDark,
          FieldPalette.inkPrimary,
          DarkPalette.inkPrimaryDark,
          true,
        ),
      ];

  group('the glyph set', () {
    test(
      'the exact ten glyphs exist — Settings is quiet text, never a drawing',
      () {
        final glyphs = Directory('lib/ui/glyphs')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .where((name) => name.endsWith('_glyph.dart'))
            .toSet();
        expect(glyphs, {
          'album_glyph.dart',
          'bag_glyph.dart',
          'battery_glyph.dart',
          'box_glyph.dart',
          'camera_glyph.dart',
          'clock_glyph.dart',
          'leaf_glyph.dart',
          'microphone_glyph.dart',
          'pencil_glyph.dart',
          'seed_glyph.dart',
        }, reason: 'the set is exactly ten and Ajustes is dissolved (UX-DR8)');
      },
    );

    testWidgets('battery levels change the rendered charge width', (
      tester,
    ) async {
      Future<TreatmentPainter> pumpLevel(BatteryLevel level) async {
        final glyph = BatteryGlyph(48, level: level);
        await tester.pumpWidget(
          MaterialApp(
            theme: OrganizerTheme.light(),
            home: Center(child: glyph),
          ),
        );
        return _treatmentPainterOf(tester);
      }

      final low = await pumpLevel(BatteryLevel.low);
      final medium = await pumpLevel(BatteryLevel.medium);
      final full = await pumpLevel(BatteryLevel.full);
      expect(low.massPaths.single.getBounds().width, closeTo(3.2, 1e-6));
      expect(medium.massPaths.single.getBounds().width, closeTo(6.4, 1e-6));
      expect(full.massPaths.single.getBounds().width, closeTo(12.8, 1e-6));
    });

    testWidgets(
      'battery and microphone active states use blue in both themes',
      (tester) async {
        Future<TreatmentPainter> pump(Widget glyph, ThemeData theme) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Center(child: glyph),
            ),
          );
          await tester.pumpAndSettle();
          return _treatmentPainterOf(tester);
        }

        for (final brightness in Brightness.values) {
          final dark = brightness == Brightness.dark;
          final theme = dark ? OrganizerTheme.dark() : OrganizerTheme.light();
          final expectedMass = dark
              ? DarkPalette.iconMassBlueDark
              : IconMassPalette.iconMassBlue;
          final expectedInk = dark
              ? DarkPalette.inkPrimaryDark
              : FieldPalette.inkPrimary;

          final battery = await pump(
            const BatteryGlyph(48, level: BatteryLevel.full, selected: true),
            theme,
          );
          expect(battery.massColor, expectedMass);
          expect(battery.lineColor, expectedInk);

          final microphone = await pump(
            const MicrophoneGlyph(48, dictating: true),
            theme,
          );
          expect(microphone.massColor, expectedMass);
          expect(microphone.lineColor, expectedInk);
        }
      },
    );
  });

  group('the shared treatment, per glyph', () {
    for (final (
          build,
          name,
          lightMass,
          darkMass,
          lightLine,
          darkLine,
          registered,
        )
        in allGlyphs) {
      testWidgets('$name — plates, tiers and registration', (tester) async {
        // MaterialApp swaps themes through an AnimatedTheme; only after
        // pumpAndSettle does Theme.of report the new ThemeData (at t=0 it
        // still holds the animating, old one).
        for (final brightness in Brightness.values) {
          final theme = brightness == Brightness.dark
              ? OrganizerTheme.dark()
              : OrganizerTheme.light();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Center(child: build()),
            ),
          );
          await tester.pumpAndSettle();
          final painter = _treatmentPainterOf(tester);
          expect(
            painter.massColor,
            brightness == Brightness.dark ? darkMass : lightMass,
            reason: '$name mass colour in ${brightness.name} mode',
          );
          expect(
            painter.lineColor,
            brightness == Brightness.dark ? darkLine : lightLine,
          );
          expect(
            painter.registeredMass,
            registered,
            reason: registered
                ? '$name is a registered mass — no offset'
                : '$name keeps the global offset',
          );
          expect(painter.massPaths, isNotEmpty);
          expect(painter.linePaths, isNotEmpty);
        }
      });
    }
  });

  group('golden images — both palettes', () {
    Future<void> pumpAndMatch(
      WidgetTester tester,
      Widget Function() build,
      String golden,
      ThemeData theme,
    ) async {
      await tester.binding.setSurfaceSize(const Size.square(64));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Center(child: build()),
        ),
      );
      await expectLater(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TreatmentPainter,
        ),
        matchesGoldenFile('goldens/$golden.png'),
      );
    }

    for (final (build, name, _, _, _, _, _) in allGlyphs) {
      testWidgets('$name at 48px — light', (tester) async {
        await pumpAndMatch(
          tester,
          build,
          'glyph_set/${name}_48_light',
          OrganizerTheme.light(),
        );
      });

      testWidgets('$name at 48px — dark', (tester) async {
        await pumpAndMatch(
          tester,
          build,
          'glyph_set/${name}_48_dark',
          OrganizerTheme.dark(),
        );
      });
    }

    testWidgets('the destination trio at 64px — light', (tester) async {
      await pumpAndMatch(
        tester,
        () => const BoxGlyph(64),
        'glyph_set/box_64_light',
        OrganizerTheme.light(),
      );
      await pumpAndMatch(
        tester,
        () => const BagGlyph(64),
        'glyph_set/bag_64_light',
        OrganizerTheme.light(),
      );
      await pumpAndMatch(
        tester,
        () => const SeedGlyph(64),
        'glyph_set/seed_64_light',
        OrganizerTheme.light(),
      );
      expect(
        _treatmentPainterOf(tester).linePaths,
        hasLength(2),
        reason:
            'at 64px, the destination size, the seed renders exactly two '
            'line paths — filaments and stem; the every-size claim is the '
            'structure sweep\'s to make',
      );
    });
  });
}

TreatmentPainter _treatmentPainterOf(WidgetTester tester) {
  final found = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is TreatmentPainter,
  );
  return (tester.widget(found) as CustomPaint).painter! as TreatmentPainter;
}
