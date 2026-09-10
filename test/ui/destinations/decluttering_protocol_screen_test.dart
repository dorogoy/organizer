import 'package:core/log/log_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/ui/destinations/decluttering_protocol_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

/// One handed-off visit: the answers as they stood at the tap, plus
/// the tag the visit ended on — null when declined.
typedef ReceivedVisit = ({DetachmentAnswers answers, CoarseVolumeTag? tag});

void main() {
  const usageQuestion = '¿Has utilizado este objeto en los últimos 12 meses?';
  const spaceQuestion = '¿Merece este objeto tu espacio físico y mental?';
  const volumeQuestion = '¿Cuánto era?';
  const yesLabel = 'Sí';
  const noLabel = 'No';
  const bolsaLabel = 'Bolsa';
  const cajaLabel = 'Caja';
  const cajaGrandeLabel = 'Caja grande';
  const muebleLabel = 'Mueble';
  const skipLabel = 'Sin etiqueta';
  const usageQuestionKey = ValueKey<String>('decluttering-protocol-usage');
  const spaceQuestionKey = ValueKey<String>('decluttering-protocol-space');
  const usageYesKey = ValueKey<String>('decluttering-protocol-usage-yes');
  const usageNoKey = ValueKey<String>('decluttering-protocol-usage-no');
  const spaceYesKey = ValueKey<String>('decluttering-protocol-space-yes');
  const spaceNoKey = ValueKey<String>('decluttering-protocol-space-no');
  const volumeBlockKey = ValueKey<String>('decluttering-protocol-volume');
  const volumeBolsaKey = ValueKey<String>('decluttering-protocol-volume-bolsa');
  const volumeCajaKey = ValueKey<String>('decluttering-protocol-volume-caja');
  const volumeCajaGrandeKey = ValueKey<String>(
    'decluttering-protocol-volume-caja-grande',
  );
  const volumeMuebleKey = ValueKey<String>(
    'decluttering-protocol-volume-mueble',
  );
  const volumeSkipKey = ValueKey<String>('decluttering-protocol-volume-skip');

  /// Pumps the protocol pushed over a host page, the route shape the
  /// dispenser owns — so the handoff's pop lands somewhere observable.
  Future<void> pumpProtocol(
    WidgetTester tester, {
    required void Function(ReceivedVisit visit) onVisit,
    Key? screenKey,
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
                    builder: (context) => DeclutteringProtocolScreen(
                      key: screenKey,
                      onAnswers: (answers, tag) =>
                          onVisit((answers: answers, tag: tag)),
                    ),
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

  Finder answer(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('the initial visit shows both pressure-free questions, only '
      'their equal Sí/No choices, and no volume block', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);

    expect(find.text(usageQuestion), findsOneWidget);
    expect(find.text(spaceQuestion), findsOneWidget);
    expect(find.text(yesLabel), findsNWidgets(2));
    expect(find.text(noLabel), findsNWidgets(2));
    expect(find.text('Hecho'), findsNothing);
    expect(find.text('Ahora no'), findsNothing);
    expect(find.byKey(usageQuestionKey), findsOneWidget);
    expect(find.byKey(spaceQuestionKey), findsOneWidget);
    expect(find.byKey(usageYesKey), findsOneWidget);
    expect(find.byKey(usageNoKey), findsOneWidget);
    expect(find.byKey(spaceYesKey), findsOneWidget);
    expect(find.byKey(spaceNoKey), findsOneWidget);
    // The volume block appears only after both answers stand.
    expect(find.byKey(volumeBlockKey), findsNothing);
    expect(find.text(volumeQuestion), findsNothing);
    expect(received, isEmpty);
  });

  testWidgets('each question starts unanswered and exposes an independent '
      'choice group', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpProtocol(tester, onVisit: (_) {});

    for (final key in [usageYesKey, usageNoKey, spaceYesKey, spaceNoKey]) {
      final semantics = tester.widget<Semantics>(find.byKey(key));
      expect(semantics.properties.selected, isFalse);
      expect(semantics.properties.inMutuallyExclusiveGroup, isTrue);
    }
    expect(
      tester.widget<Semantics>(find.byKey(usageQuestionKey)).properties.label,
      usageQuestion,
    );
    expect(
      tester.widget<Semantics>(find.byKey(spaceQuestionKey)).properties.label,
      spaceQuestion,
    );

    await tester.tap(answer(usageYesKey));
    await tester.pump();
    expect(
      tester.widget<Semantics>(find.byKey(usageYesKey)).properties.selected,
      isTrue,
    );
    expect(
      tester.widget<Semantics>(find.byKey(usageNoKey)).properties.selected,
      isFalse,
    );
    expect(
      tester.widget<Semantics>(find.byKey(spaceYesKey)).properties.selected,
      isFalse,
    );

    await tester.tap(answer(usageNoKey));
    await tester.pump();
    expect(
      tester.widget<Semantics>(find.byKey(usageYesKey)).properties.selected,
      isFalse,
    );
    expect(
      tester.widget<Semantics>(find.byKey(usageNoKey)).properties.selected,
      isTrue,
    );
    semanticsHandle.dispose();
  });

  testWidgets('the second standing answer reveals the volume block — one '
      'question, four tag choices, one decline, nothing handed off yet '
      '(FR-22)', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);

    await tester.tap(answer(usageYesKey));
    await tester.pump();
    // One answer alone reveals nothing.
    expect(find.byKey(volumeBlockKey), findsNothing);

    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();

    expect(find.byKey(volumeBlockKey), findsOneWidget);
    expect(find.text(volumeQuestion), findsOneWidget);
    expect(find.text(bolsaLabel), findsOneWidget);
    expect(find.text(cajaLabel), findsOneWidget);
    expect(find.text(cajaGrandeLabel), findsOneWidget);
    expect(find.text(muebleLabel), findsOneWidget);
    expect(find.text(skipLabel), findsOneWidget);
    expect(received, isEmpty, reason: 'the reveal hands off nothing');

    // Answer order is independent: the block appears whichever answer
    // lands second — a fresh visit, the first route closed.
    final orderReceived = <ReceivedVisit>[];
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await pumpProtocol(
      tester,
      screenKey: const ValueKey<String>('order'),
      onVisit: orderReceived.add,
    );
    await tester.tap(answer(spaceYesKey));
    await tester.pump();
    expect(find.byKey(volumeBlockKey), findsNothing);
    await tester.tap(answer(usageNoKey));
    await tester.pumpAndSettle();
    expect(find.byKey(volumeBlockKey), findsOneWidget);
    expect(orderReceived, isEmpty);
  });

  testWidgets('tag and decline read as equal one-tap outcomes — no '
      'preselection, no grouping, no confirm step (UX-DR31)', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpProtocol(tester, onVisit: (_) {});
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    await tester.tap(answer(spaceYesKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Semantics>(find.byKey(volumeBlockKey)).properties.label,
      volumeQuestion,
    );
    for (final key in [
      volumeBolsaKey,
      volumeCajaKey,
      volumeCajaGrandeKey,
      volumeMuebleKey,
      volumeSkipKey,
    ]) {
      final semantics = tester.widget<Semantics>(find.byKey(key));
      expect(semantics.properties.button, isTrue, reason: '$key');
      expect(semantics.properties.selected, isFalse, reason: '$key');
      expect(
        semantics.properties.inMutuallyExclusiveGroup,
        isFalse,
        reason: 'the tap is the act — no selection state exists',
      );
    }
    semanticsHandle.dispose();
  });

  testWidgets('a tag tap fires the one-shot handoff with the answers and '
      'the tag — the route stands for the sink to pop (6.4\'s seam: '
      'navigation is no longer the protocol\'s act)', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();

    await tester.tap(answer(volumeCajaKey));
    await tester.pumpAndSettle();

    expect(received, [
      (
        answers: const DetachmentAnswers(
          usedInLastTwelveMonths: DetachmentAnswer.yes,
          deservesPhysicalAndMentalSpace: DetachmentAnswer.no,
        ),
        tag: CoarseVolumeTag.caja,
      ),
    ]);
    // Since 6.4 the seam's sink owns navigation: the visit ends with
    // the handoff, and the route stays standing — the sink pops it and
    // pushes the destination flow (a pop from here would pop the flow
    // the sink just pushed).
    expect(find.byType(DeclutteringProtocolScreen), findsOneWidget);
    expect(find.text('open'), findsNothing);

    // The visit's one handoff is spent: a later tag tap on the same
    // standing route fires nothing further.
    await tester.tap(answer(volumeBolsaKey));
    await tester.pumpAndSettle();
    expect(received, hasLength(1));
  });

  testWidgets('the decline tap fires the same one-shot handoff with a null '
      'tag — declining writes nothing anywhere', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);
    await tester.tap(answer(usageNoKey));
    await tester.pump();
    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();

    await tester.tap(answer(volumeSkipKey));
    await tester.pumpAndSettle();

    expect(received, [
      (
        answers: const DetachmentAnswers(
          usedInLastTwelveMonths: DetachmentAnswer.no,
          deservesPhysicalAndMentalSpace: DetachmentAnswer.no,
        ),
        tag: null,
      ),
    ]);
    // The decline is the same one-tap outcome: handed off, the route
    // standing for the sink to pop.
    expect(find.byType(DeclutteringProtocolScreen), findsOneWidget);
  });

  testWidgets('the answers stay revisable while the block is visible, and '
      'the handoff carries them as they stand at the tap', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();
    expect(find.byKey(volumeBlockKey), findsOneWidget);

    // A revision after the reveal: the block stays visible (both
    // answers still stand) and nothing fires.
    await tester.tap(answer(spaceYesKey));
    await tester.pumpAndSettle();
    expect(find.byKey(volumeBlockKey), findsOneWidget);
    expect(received, isEmpty);

    await tester.tap(answer(volumeBolsaKey));
    await tester.pumpAndSettle();
    expect(received, [
      (
        answers: const DetachmentAnswers(
          usedInLastTwelveMonths: DetachmentAnswer.yes,
          deservesPhysicalAndMentalSpace: DetachmentAnswer.yes,
        ),
        tag: CoarseVolumeTag.bolsa,
      ),
    ]);
  });

  testWidgets('all Sí/No combinations map to the correct question fields at '
      'the handoff, each with the tapped tag', (tester) async {
    const cases = [
      (used: DetachmentAnswer.yes, space: DetachmentAnswer.yes),
      (used: DetachmentAnswer.yes, space: DetachmentAnswer.no),
      (used: DetachmentAnswer.no, space: DetachmentAnswer.yes),
      (used: DetachmentAnswer.no, space: DetachmentAnswer.no),
    ];

    for (var index = 0; index < cases.length; index++) {
      final received = <ReceivedVisit>[];
      await pumpProtocol(
        tester,
        screenKey: ValueKey<String>('answer-case-$index'),
        onVisit: received.add,
      );
      final values = cases[index];
      await tester.tap(
        answer(values.used == DetachmentAnswer.yes ? usageYesKey : usageNoKey),
      );
      await tester.pump();
      await tester.tap(
        answer(values.space == DetachmentAnswer.yes ? spaceYesKey : spaceNoKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(answer(volumeMuebleKey));
      await tester.pumpAndSettle();

      expect(received, [
        (
          answers: DetachmentAnswers(
            usedInLastTwelveMonths: values.used,
            deservesPhysicalAndMentalSpace: values.space,
          ),
          tag: CoarseVolumeTag.mueble,
        ),
      ]);

      // The route stands after the handoff (the sink owns the pop), so
      // the loop closes it itself before the next visit.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('every coarse tag hands off as itself — the four the enum '
      'names, one row each', (tester) async {
    const tags = [
      (key: volumeBolsaKey, tag: CoarseVolumeTag.bolsa),
      (key: volumeCajaKey, tag: CoarseVolumeTag.caja),
      (key: volumeCajaGrandeKey, tag: CoarseVolumeTag.caja_grande),
      (key: volumeMuebleKey, tag: CoarseVolumeTag.mueble),
    ];

    for (var index = 0; index < tags.length; index++) {
      final received = <ReceivedVisit>[];
      await pumpProtocol(
        tester,
        screenKey: ValueKey<String>('tag-case-$index'),
        onVisit: received.add,
      );
      await tester.tap(answer(usageYesKey));
      await tester.pump();
      await tester.tap(answer(spaceYesKey));
      await tester.pumpAndSettle();
      await tester.tap(answer(tags[index].key));
      await tester.pumpAndSettle();

      expect(received.single.tag, tags[index].tag);

      // The route stands after the handoff (the sink owns the pop), so
      // the loop closes it itself before the next visit.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('system back from the volume block discards the transient '
      'answers and the visibility — no event, re-opening starts '
      'unanswered', (tester) async {
    final received = <ReceivedVisit>[];
    await pumpProtocol(tester, onVisit: received.add);
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();
    expect(find.byKey(volumeBlockKey), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DeclutteringProtocolScreen), findsNothing);
    expect(received, isEmpty);

    // A fresh visit starts from nothing: unanswered questions, no
    // block, nothing standing from the discarded visit.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final semanticsHandle = tester.ensureSemantics();
    for (final key in [usageYesKey, spaceYesKey]) {
      expect(
        tester.widget<Semantics>(find.byKey(key)).properties.selected,
        isFalse,
      );
    }
    semanticsHandle.dispose();
    expect(find.byKey(volumeBlockKey), findsNothing);

    // And one answer from the discarded visit cannot satisfy the new
    // one's block rule alone.
    await tester.tap(answer(spaceNoKey));
    await tester.pump();
    expect(find.byKey(volumeBlockKey), findsNothing);
    expect(
      received,
      isEmpty,
      reason: 'no answer may survive a route departure',
    );
  });

  testWidgets('at 200% text scale the question copy wraps, the route '
      'scrolls, and every target — answers, tags and decline — remains at '
      'least 48dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpProtocol(tester, onVisit: (_) {});
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    // The second question sits below the fold at 200% — bring it in
    // before its target can be tapped.
    await tester.ensureVisible(answer(spaceNoKey));
    await tester.pumpAndSettle();
    await tester.tap(answer(spaceNoKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    for (final question in [usageQuestion, spaceQuestion, volumeQuestion]) {
      final questionFinder = find.text(question);
      expect(questionFinder, findsOneWidget);
      expect(tester.getSize(questionFinder).height, greaterThan(48));
      expect(
        tester.renderObject<RenderParagraph>(questionFinder).didExceedMaxLines,
        isFalse,
      );
    }

    // Four answer targets, four tags and the decline — nine in all.
    final buttons = find.byType(OutlinedButton);
    expect(buttons, findsNWidgets(9));
    for (var index = 0; index < 9; index++) {
      expect(
        tester.getSize(buttons.at(index)).height,
        greaterThanOrEqualTo(Spacing.touchTargetMin),
      );
      expect(
        tester.getSize(buttons.at(index)).width,
        greaterThanOrEqualTo(Spacing.touchTargetMin),
      );
    }
    await tester.ensureVisible(buttons.last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
