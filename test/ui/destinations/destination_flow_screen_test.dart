import 'dart:async';
import 'dart:io';

import 'package:core/log/log_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/ui/destinations/destination_flow_screen.dart';
import 'package:organizer/ui/glyphs/bag_glyph.dart';
import 'package:organizer/ui/glyphs/box_glyph.dart';
import 'package:organizer/ui/glyphs/seed_glyph.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

void main() {
  const keepLabel = 'Quedármelo';
  const donateLabel = 'Donar o vender';
  const releaseLabel = 'Tirar o soltar';
  const keepRowKey = ValueKey<String>('destination-flow-keep');
  const donateRowKey = ValueKey<String>('destination-flow-donate');
  const releaseRowKey = ValueKey<String>('destination-flow-release');

  /// Pumps the flow pushed over a host page, the route shape the
  /// dispenser's sink owns — so the flow's own pop lands somewhere
  /// observable.
  Future<void> pumpFlow(
    WidgetTester tester, {
    required DestinationTapCallback onDestination,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        DestinationFlowScreen(onDestination: onDestination),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('three equal rows and nothing else — the verbatim labels in '
      'the fixed order, each glyph at 64, the 32dp gap, the raised ground '
      '(FR-20, UX-DR27)', (tester) async {
    await pumpFlow(tester, onDestination: (_) async => true);

    // Exactly the three authored labels render — no question, no
    // object line, no count (AD-26, AD-15: the register holds only
    // these three strings for this flow).
    expect(find.byType(Text), findsNWidgets(3));
    expect(find.text(keepLabel), findsOneWidget);
    expect(find.text(donateLabel), findsOneWidget);
    expect(find.text(releaseLabel), findsOneWidget);

    // The fixed order: keep, donate, release — top to bottom.
    final keepTop = tester.getTopLeft(find.text(keepLabel)).dy;
    final donateTop = tester.getTopLeft(find.text(donateLabel)).dy;
    final releaseTop = tester.getTopLeft(find.text(releaseLabel)).dy;
    expect(keepTop, lessThan(donateTop));
    expect(donateTop, lessThan(releaseTop));

    // The trio, each at the destination size, one per row, in order.
    expect(find.byType(BoxGlyph), findsOneWidget);
    expect(find.byType(BagGlyph), findsOneWidget);
    expect(find.byType(SeedGlyph), findsOneWidget);
    expect(
      tester.widget<BoxGlyph>(find.byType(BoxGlyph)).size,
      Spacing.glyphDestination,
    );
    expect(
      tester.widget<BagGlyph>(find.byType(BagGlyph)).size,
      Spacing.glyphDestination,
    );
    expect(
      tester.widget<SeedGlyph>(find.byType(SeedGlyph)).size,
      Spacing.glyphDestination,
    );
    expect(
      find.descendant(
        of: find.byKey(keepRowKey),
        matching: find.byType(BoxGlyph),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(donateRowKey),
        matching: find.byType(BagGlyph),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(releaseRowKey),
        matching: find.byType(SeedGlyph),
      ),
      findsOneWidget,
    );

    // Constructionally identical rows at equal pitch: each row is the
    // glyph's 64 plus its padding, separated by the 32dp row gap.
    final keepRowTop = tester.getTopLeft(find.byKey(keepRowKey)).dy;
    final donateRowTop = tester.getTopLeft(find.byKey(donateRowKey)).dy;
    final releaseRowTop = tester.getTopLeft(find.byKey(releaseRowKey)).dy;
    final rowHeight = tester.getSize(find.byKey(keepRowKey)).height;
    expect(donateRowTop - keepRowTop, closeTo(rowHeight + 32, 0.5));
    expect(releaseRowTop - donateRowTop, closeTo(rowHeight + 32, 0.5));
    expect(
      tester.getSize(find.byKey(keepRowKey)).height,
      tester.getSize(find.byKey(donateRowKey)).height,
    );
    expect(
      tester.getSize(find.byKey(donateRowKey)).height,
      tester.getSize(find.byKey(releaseRowKey)).height,
    );

    // The raised ground: tone alone, on the wired slot.
    expect(find.byType(DestinationFlowScreen), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(DestinationFlowScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(
      scaffold.backgroundColor,
      OrganizerTheme.light().colorScheme.surfaceContainerHighest,
    );
    expect(find.byType(AppBar), findsNothing);

    // No tile, field, bar or band anywhere on the flow: no colored
    // boxes exist in its tree at all — hue lives only inside glyphs.
    expect(
      find.descendant(
        of: find.byType(DestinationFlowScreen),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DestinationFlowScreen),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });

  testWidgets('each row reads as a plain button — no selection state, no '
      'grouping, no default (UX-DR27)', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpFlow(tester, onDestination: (_) async => true);

    for (final key in [keepRowKey, donateRowKey, releaseRowKey]) {
      final semantics = tester.widget<Semantics>(find.byKey(key));
      expect(semantics.properties.button, isTrue, reason: '$key');
      // Authored absent, never authored false: no selection state
      // exists anywhere on the flow — the tap is the act.
      expect(semantics.properties.selected, isNull, reason: '$key');
      expect(
        semantics.properties.inMutuallyExclusiveGroup,
        isNull,
        reason: 'the tap is the act — no selection state exists',
      );
    }
    semanticsHandle.dispose();
  });

  testWidgets('a tap fires the callback once with its row\'s destination '
      'and pops the route on success — the act, not a selection', (
    tester,
  ) async {
    final received = <TriageDestination>[];
    await pumpFlow(
      tester,
      onDestination: (destination) async {
        received.add(destination);
        return true;
      },
    );

    await tester.tap(find.byKey(releaseRowKey));
    await tester.pumpAndSettle();

    expect(received, [TriageDestination.trash_recycle]);
    // The act landed: the flow pops and hands the surface back.
    expect(find.byType(DestinationFlowScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('each row hands off its own destination — the wire names the '
      'enum holds', (tester) async {
    const rows = [
      (key: keepRowKey, destination: TriageDestination.keep),
      (key: donateRowKey, destination: TriageDestination.donate_sell),
      (key: releaseRowKey, destination: TriageDestination.trash_recycle),
    ];

    for (var index = 0; index < rows.length; index++) {
      final received = <TriageDestination>[];
      await pumpFlow(
        tester,
        onDestination: (destination) async {
          received.add(destination);
          return true;
        },
      );
      await tester.tap(find.byKey(rows[index].key));
      await tester.pumpAndSettle();
      expect(received, [rows[index].destination]);
    }
  });

  testWidgets('a rapid second tap inside one visit is ignored — one-shot, '
      'exactly one act (matrix: tap during write)', (tester) async {
    var calls = 0;
    await pumpFlow(
      tester,
      onDestination: (destination) async {
        calls++;
        return true;
      },
    );

    await tester.tap(find.byKey(keepRowKey));
    await tester.pump();
    await tester.tap(find.byKey(donateRowKey));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('a failed write leaves the flow standing, quiet, and re-arms '
      'the act for an in-place retry (matrix: write failure)', (tester) async {
    var calls = 0;
    await pumpFlow(
      tester,
      onDestination: (destination) async {
        calls++;
        return false;
      },
    );

    await tester.tap(find.byKey(donateRowKey));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byType(DestinationFlowScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Failure keeps the flow standing and re-arms its one act, so a retry
    // needs neither a back gesture nor another protocol visit.
    await tester.tap(find.byKey(releaseRowKey));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(DestinationFlowScreen), findsOneWidget);
  });

  testWidgets('back during a pending act never lets a late success pop the '
      'host route', (tester) async {
    final landing = Completer<bool>();
    await pumpFlow(tester, onDestination: (_) => landing.future);

    await tester.tap(find.byKey(keepRowKey));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DestinationFlowScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);

    landing.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back before any tap writes nothing — the callback '
      'never fires and the route pops (matrix: back from flow)', (
    tester,
  ) async {
    var calls = 0;
    await pumpFlow(
      tester,
      onDestination: (destination) async {
        calls++;
        return true;
      },
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(DestinationFlowScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('dark mode keeps the light form — the flow renders whole on '
      'the dark raised ground, the labels in dark ink (UX-DR13)', (
    tester,
  ) async {
    final dark = OrganizerTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        DestinationFlowScreen(onDestination: (_) async => true),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BoxGlyph), findsOneWidget);
    expect(find.byType(BagGlyph), findsOneWidget);
    expect(find.byType(SeedGlyph), findsOneWidget);
    // The glyphs' own painters resolve the dark masses (glyphPlates);
    // the flow's part is the dark raised ground and the wired label
    // ink — tone alone, never an inversion.
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(DestinationFlowScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, dark.colorScheme.surfaceContainerHighest);
    expect(scaffold.backgroundColor, DarkPalette.surfaceRaisedDark);
    final label = tester.renderObject<RenderParagraph>(find.text(keepLabel));
    expect(label.text.style?.color, DarkPalette.inkPrimaryDark);
  });

  testWidgets('at 200% text scale the labels wrap, the route scrolls, and '
      'every row target stays at least 48dp (UX-DR45/47)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpFlow(tester, onDestination: (_) async => true);

    expect(tester.takeException(), isNull);
    // The middle label wraps — growing, never truncating.
    final wrapped = find.text(donateLabel);
    expect(
      tester.renderObject<RenderParagraph>(wrapped).didExceedMaxLines,
      isFalse,
    );
    expect(tester.getSize(wrapped).height, greaterThan(48));
    // The screen scrolls so the third row stays reachable.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    for (final key in [keepRowKey, donateRowKey, releaseRowKey]) {
      final row = find.byKey(key);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(row).width, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'the flow\'s source carries no hue and no truncation lever — colour '
    'lives only inside the glyphs, text only grows (the audit pin)',
    () async {
      final source = File('lib/ui/destinations/destination_flow_screen.dart')
          .readAsStringSync();
      expect(source, isNot(contains('IconMassPalette')));
      expect(source, isNot(contains('DarkPalette')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('maxLines:')));
      expect(source, isNot(contains('TextOverflow.ellipsis')));
      expect(source, isNot(contains('FittedBox')));
    },
  );
}
