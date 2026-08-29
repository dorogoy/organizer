// The dealt card's rendered contract (Story 1.8): the anatomy order and
// token gaps, Lora's one CONTENT role, the full-width Hecho, the plain
// text secondary, the footer iff the card carries a zone, the duration
// labels with their load-bearing NBSP — on the sizes' derived estimates
// — the hairline/no-shadow surface in both authored palettes, and no
// origin text anywhere: the I/O matrix's rendering rows, pinned.
import 'package:core/catalogue/catalogue.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/duration_chip.dart';
import 'package:organizer/ui/dispenser/task_card.dart';
import 'package:organizer/ui/dispenser/zone_marker.dart';
import 'package:organizer/ui/glyphs/leaf_glyph.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

/// A zoned Focus Chunk with its derived estimate — the real pairing
/// (`estimateSecondsOf(Size.focus) == 900`), so the `15 min` pin holds
/// on a card the weave could actually deal.
const _zonedCard = Card(
  id: 'pasar-la-aspiradora-al-salon',
  size: Size.focus,
  name: 'Despeja la mesa del salón',
  origin: Origin.shipped,
  zone: Zone.z4,
  estimateSeconds: 900,
);

/// A zoneless Instant Habit with its derived estimate (30 s).
const _zonelessCard = Card(
  id: 'regar-una-planta',
  size: Size.instant,
  name: 'Regar una planta',
  origin: Origin.shipped,
  zone: null,
  estimateSeconds: 30,
);

/// A Baseline Upkeep card with its derived estimate (3 min).
const _maintenanceCard = Card(
  id: 'recoger-la-mesa',
  size: Size.maintenance,
  name: 'Recoger la mesa',
  origin: Origin.shipped,
  zone: null,
  estimateSeconds: 180,
);

Widget _harness(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? OrganizerTheme.light(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
      child: Center(child: child),
    ),
  ),
);

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  test('the duration label follows the whole-minutes-else-seconds rule '
      'with the NBSP between value and unit', () {
    final strings = AppStringsEs();
    expect(durationLabel(900, strings), '15\u00A0min');
    expect(durationLabel(180, strings), '3\u00A0min');
    expect(durationLabel(30, strings), '30\u00A0s');
    expect(durationLabel(90, strings), '90\u00A0s');
  });

  test('the zone label resolves the canonical A12.4 names', () {
    final strings = AppStringsEs();
    expect(zoneLabel(Zone.z1, strings), 'Cocina y despensa');
    expect(zoneLabel(Zone.z2, strings), 'Baños');
    expect(zoneLabel(Zone.z3, strings), 'Dormitorios');
    expect(zoneLabel(Zone.z4, strings), 'Salón y zonas comunes');
    expect(zoneLabel(Zone.z5, strings), 'Entrada, lavadero y exteriores');
  });

  testWidgets('the anatomy renders top to bottom with the token gaps, '
      'the chip above a Lora task, and the footer when zoned', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _zonedCard)));
    await tester.pumpAndSettle();

    // Anatomy order: chip eyebrow → task → Hecho → secondary → footer.
    final chip = _rect(tester, find.byType(DurationChip));
    final task = _rect(tester, find.text(_zonedCard.name));
    final hecho = _rect(tester, find.byType(HechoButton));
    final secondary = _rect(tester, find.byType(SecondaryTextAction));
    final footer = _rect(tester, find.byType(ZoneMarker));
    expect(chip.bottom, lessThan(task.top));
    expect(task.bottom, lessThan(hecho.top));
    expect(hecho.bottom, lessThan(secondary.top));
    expect(secondary.bottom, lessThan(footer.top));

    // The gaps are the tokens', exactly.
    expect(task.top - chip.bottom, Spacing.chipToTask);
    expect(hecho.top - task.bottom, Spacing.taskToActions);
    expect(secondary.top - hecho.bottom, Spacing.actionGap);

    // The task is the one CONTENT role — Lora, 26sp, ink-primary.
    final taskStyle = tester.widget<Text>(find.text(_zonedCard.name)).style!;
    expect(taskStyle.fontFamily, FontFamilies.lora);
    expect(taskStyle.fontSize, 26);
    expect(taskStyle.color, FieldPalette.inkPrimary);

    // The chip carries its estimate, always visible, as the pill's own
    // role on the shared pastel.
    expect(find.text('15\u00A0min'), findsOneWidget);
    final chipDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(DurationChip),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(chipDecoration.color, FieldPalette.accentSoft);
    expect(
      chipDecoration.borderRadius,
      BorderRadius.circular(Radii.radiusFull),
    );
    final chipStyle = tester.widget<Text>(find.text('15\u00A0min')).style!;
    expect(chipStyle.color, FieldPalette.inkPrimary);
    expect(chipStyle.fontSize, 15);

    // The zone footer: the Hoja at 24px beside the canonical word.
    expect(find.byType(LeafGlyph), findsOneWidget);
    final glyph = tester.renderObject<RenderBox>(find.byType(LeafGlyph));
    expect(glyph.size.width, Spacing.glyphZoneMarker);
    expect(glyph.size.height, Spacing.glyphZoneMarker);
    expect(find.text(zoneLabel(Zone.z4, AppStringsEs())), findsOneWidget);

    // Exactly the anatomy's texts — nothing else is on the card.
    expect(find.byType(Text), findsNWidgets(5));
  });

  testWidgets('Hecho is full-width with the 48dp floor; the secondary is '
      'plain centered text with no box, fill or underline', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _zonedCard)));
    await tester.pumpAndSettle();

    final card = _rect(tester, find.byType(TaskCard));
    final cardBorder =
        (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byType(TaskCard),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .border
            as Border;
    final hecho = _rect(tester, find.byType(HechoButton));
    final secondary = _rect(tester, find.byType(SecondaryTextAction));

    // Full-width inside the card padding and hairline, minimum height
    // the platform floor — a minimum, never a fixed height.
    expect(
      hecho.width,
      card.width - 2 * Spacing.cardPadding - 2 * cardBorder.top.width,
    );
    expect(hecho.height, greaterThanOrEqualTo(Spacing.touchTargetMin));
    expect(secondary.height, greaterThanOrEqualTo(Spacing.touchTargetMin));

    // The secondary renders as text only: the action-secondary role in
    // ink-secondary, no decoration, centered within the card.
    final secondaryText = tester.widget<Text>(
      find.text(AppStringsEs().actionRescueOrSkip),
    );
    expect(secondaryText.style!.color, FieldPalette.inkSecondary);
    expect(secondaryText.style!.fontFamily, FontFamilies.lexend);
    // Plain text: no underline ever — absent or explicitly none.
    final decoration = secondaryText.style!.decoration;
    expect(
      decoration == null || decoration == TextDecoration.none,
      isTrue,
      reason:
          'the secondary action is text only — no box, fill or '
          'underline (DESIGN action-secondary)',
    );
    final cardCenterX = card.left + card.width / 2;
    final secondaryCenterX = secondary.left + secondary.width / 2;
    expect(secondaryCenterX, closeTo(cardCenterX, 1));

    // Hecho's label: the action-primary role on the shared pastel.
    final pillDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(DurationChip),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    final hechoMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(HechoButton),
        matching: find.byType(Material),
      ),
    );
    expect(hechoMaterial.color, pillDecoration.color);
    expect(
      hechoMaterial.borderRadius,
      BorderRadius.circular(Radii.radiusDefault),
    );
    final hechoStyle = tester.widget<Text>(find.text('Hecho')).style!;
    expect(hechoStyle.color, FieldPalette.inkPrimary);
    expect(hechoStyle.fontSize, 19);
  });

  testWidgets('the surface separates by tone and a 1px hairline — no '
      'shadow, gradient or glow anywhere (UX-DR6)', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _zonedCard)));
    await tester.pumpAndSettle();

    // The card's DecoratedBox is the outermost of the subtree (the pill's
    // sits inside it).
    final cardDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(TaskCard),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(cardDecoration.color, FieldPalette.surfaceRaised);
    expect(
      cardDecoration.borderRadius,
      BorderRadius.circular(Radii.radiusDefault),
    );
    final border = cardDecoration.border as Border;
    expect(border.top.width, 1);
    expect(border.top.color, FieldPalette.borderHairline);
    expect(cardDecoration.boxShadow, isNull);
    expect(cardDecoration.gradient, isNull);
  });

  testWidgets('the dark palette is the card\'s own authorship, never an '
      'inversion (UX-DR12)', (tester) async {
    await tester.pumpWidget(
      _harness(const TaskCard(card: _zonedCard), theme: OrganizerTheme.dark()),
    );
    await tester.pumpAndSettle();

    final cardDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(TaskCard),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(cardDecoration.color, DarkPalette.surfaceRaisedDark);
    final border = cardDecoration.border as Border;
    expect(border.top.width, 1);
    expect(border.top.color, DarkPalette.borderHairlineDark);
    final taskStyle = tester.widget<Text>(find.text(_zonedCard.name)).style!;
    expect(taskStyle.color, DarkPalette.inkPrimaryDark);
    expect(taskStyle.fontFamily, FontFamilies.lora);
  });

  testWidgets('a maintenance card\'s chip carries its derived estimate — '
      '3 min on the real pairing', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _maintenanceCard)));
    await tester.pumpAndSettle();

    expect(find.text('3\u00A0min'), findsOneWidget);
    expect(find.byType(DurationChip), findsOneWidget);
  });

  testWidgets('a zoneless card ends after the secondary action — no '
      'footer, no invented zone word', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _zonelessCard)));
    await tester.pumpAndSettle();

    expect(find.byType(LeafGlyph), findsNothing);
    expect(find.byType(ZoneMarker), findsNothing);
    for (final zoneWord in [
      AppStringsEs().zoneZ1,
      AppStringsEs().zoneZ2,
      AppStringsEs().zoneZ3,
      AppStringsEs().zoneZ4,
      AppStringsEs().zoneZ5,
    ]) {
      expect(find.text(zoneWord), findsNothing);
    }
    expect(find.text('30\u00A0s'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(4));
  });

  testWidgets('no origin text is ever surfaced (AD-14)', (tester) async {
    await tester.pumpWidget(_harness(const TaskCard(card: _zonedCard)));
    await tester.pumpWidget(_harness(const TaskCard(card: _zonelessCard)));
    await tester.pumpAndSettle();

    for (final originText in [
      'shipped',
      'manual',
      'local',
      'cloud',
      _zonedCard.id,
      _zonelessCard.id,
    ]) {
      expect(find.text(originText), findsNothing);
    }
  });
}
