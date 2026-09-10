import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/ui/destinations/decluttering_protocol_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

void main() {
  const usageQuestion = '¿Has utilizado este objeto en los últimos 12 meses?';
  const spaceQuestion = '¿Merece este objeto tu espacio físico y mental?';
  const yesLabel = 'Sí';
  const noLabel = 'No';
  const usageQuestionKey = ValueKey<String>('decluttering-protocol-usage');
  const spaceQuestionKey = ValueKey<String>('decluttering-protocol-space');
  const usageYesKey = ValueKey<String>('decluttering-protocol-usage-yes');
  const usageNoKey = ValueKey<String>('decluttering-protocol-usage-no');
  const spaceYesKey = ValueKey<String>('decluttering-protocol-space-yes');
  const spaceNoKey = ValueKey<String>('decluttering-protocol-space-no');

  Future<void> pumpProtocol(
    WidgetTester tester, {
    required DetachmentAnswersCallback onAnswers,
    Key? screenKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: DeclutteringProtocolScreen(key: screenKey, onAnswers: onAnswers),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder answer(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('the initial visit shows both pressure-free questions and only '
      'their equal Sí/No choices', (tester) async {
    final received = <DetachmentAnswers>[];
    await pumpProtocol(tester, onAnswers: received.add);

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
    expect(received, isEmpty);
  });

  testWidgets('each question starts unanswered and exposes an independent '
      'choice group', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpProtocol(tester, onAnswers: (_) {});

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

  testWidgets('one answer stays transient and the second answer is required '
      'before the typed handoff', (tester) async {
    final received = <DetachmentAnswers>[];
    await pumpProtocol(tester, onAnswers: received.add);

    await tester.tap(answer(usageYesKey));
    await tester.pump();
    expect(received, isEmpty);

    await tester.tap(answer(spaceNoKey));
    await tester.pump();
    expect(received, [
      const DetachmentAnswers(
        usedInLastTwelveMonths: DetachmentAnswer.yes,
        deservesPhysicalAndMentalSpace: DetachmentAnswer.no,
      ),
    ]);

    // The pair is handed off once, while each selected answer remains
    // revisable as long as the surface stays open.
    await tester.tap(answer(usageNoKey));
    await tester.pump();
    expect(received, hasLength(1));
  });

  testWidgets('answer order is independent and the handoff is one-shot per '
      'visit', (tester) async {
    final received = <DetachmentAnswers>[];
    await pumpProtocol(tester, onAnswers: received.add);

    await tester.tap(answer(spaceNoKey));
    await tester.pump();
    expect(received, isEmpty);

    await tester.tap(answer(usageYesKey));
    await tester.pump();
    expect(received, [
      const DetachmentAnswers(
        usedInLastTwelveMonths: DetachmentAnswer.yes,
        deservesPhysicalAndMentalSpace: DetachmentAnswer.no,
      ),
    ]);

    await tester.tap(answer(spaceYesKey));
    await tester.pump();
    expect(received, hasLength(1));
  });

  testWidgets('all Sí/No combinations map to the correct question fields', (
    tester,
  ) async {
    const cases = [
      (used: DetachmentAnswer.yes, space: DetachmentAnswer.yes),
      (used: DetachmentAnswer.yes, space: DetachmentAnswer.no),
      (used: DetachmentAnswer.no, space: DetachmentAnswer.yes),
      (used: DetachmentAnswer.no, space: DetachmentAnswer.no),
    ];

    for (var index = 0; index < cases.length; index++) {
      final received = <DetachmentAnswers>[];
      await pumpProtocol(
        tester,
        screenKey: ValueKey<String>('answer-case-$index'),
        onAnswers: received.add,
      );
      final values = cases[index];
      await tester.tap(
        answer(values.used == DetachmentAnswer.yes ? usageYesKey : usageNoKey),
      );
      await tester.pump();
      await tester.tap(
        answer(values.space == DetachmentAnswer.yes ? spaceYesKey : spaceNoKey),
      );
      await tester.pump();

      expect(received, [
        DetachmentAnswers(
          usedInLastTwelveMonths: values.used,
          deservesPhysicalAndMentalSpace: values.space,
        ),
      ]);
    }
  });

  testWidgets('system back discards the partial pair before a return', (
    tester,
  ) async {
    final received = <DetachmentAnswers>[];
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
                        DeclutteringProtocolScreen(onAnswers: received.add),
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
    await tester.tap(answer(usageYesKey));
    await tester.pump();
    expect(received, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DeclutteringProtocolScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(answer(spaceNoKey));
    await tester.pump();
    expect(
      received,
      isEmpty,
      reason: 'the first answer must not survive a route departure',
    );
  });

  testWidgets('at 200% text scale the question copy wraps, the route scrolls, '
      'and every answer target remains at least 48dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpProtocol(tester, onAnswers: (_) {});

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    for (final question in [usageQuestion, spaceQuestion]) {
      final questionFinder = find.text(question);
      expect(questionFinder, findsOneWidget);
      expect(tester.getSize(questionFinder).height, greaterThan(48));
      expect(
        tester.renderObject<RenderParagraph>(questionFinder).didExceedMaxLines,
        isFalse,
      );
    }

    final buttons = find.byType(OutlinedButton);
    expect(buttons, findsNWidgets(4));
    for (var index = 0; index < 4; index++) {
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
