// The Decluttering Protocol's frame (Stories 6.1–6.2, FR-19/20, UX-DR31):
// the surface a dealt purge card's `Hecho` opens — and the ONLY way in.
// No menu, list or second entry reaches it; the dispenser's ordinary card is
// the whole door. This surface owns only the two transient detachment answers
// and hands them to the later destination flow through a typed seam.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The frame's width bound on wide grounds — the surface family's own layout
/// bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _protocolMaxWidth = 480;

const _usageQuestionKey = ValueKey<String>('decluttering-protocol-usage');
const _spaceQuestionKey = ValueKey<String>('decluttering-protocol-space');
const _usageYesKey = ValueKey<String>('decluttering-protocol-usage-yes');
const _usageNoKey = ValueKey<String>('decluttering-protocol-usage-no');
const _spaceYesKey = ValueKey<String>('decluttering-protocol-space-yes');
const _spaceNoKey = ValueKey<String>('decluttering-protocol-space-no');

/// A response to one of the protocol's two mandatory questions.
enum DetachmentAnswer { yes, no }

/// The complete pair of answers handed to the downstream destination flow.
/// It is immutable so the callback receives a snapshot, while the screen's
/// own selections remain ephemeral state for this visit only.
@immutable
class DetachmentAnswers {
  const DetachmentAnswers({
    required this.usedInLastTwelveMonths,
    required this.deservesPhysicalAndMentalSpace,
  });

  final DetachmentAnswer usedInLastTwelveMonths;
  final DetachmentAnswer deservesPhysicalAndMentalSpace;

  @override
  bool operator ==(Object other) =>
      other is DetachmentAnswers &&
      other.usedInLastTwelveMonths == usedInLastTwelveMonths &&
      other.deservesPhysicalAndMentalSpace == deservesPhysicalAndMentalSpace;

  @override
  int get hashCode =>
      Object.hash(usedInLastTwelveMonths, deservesPhysicalAndMentalSpace);
}

/// The handoff seam between the questions and the later destination flow.
typedef DetachmentAnswersCallback = void Function(DetachmentAnswers answers);

/// The Decluttering Protocol's two-question surface (Story 6.2, FR-20).
/// [onAnswers] fires once, synchronously from the tap that supplies the
/// second answer. It does not complete the purge card or write a log row.
class DeclutteringProtocolScreen extends StatefulWidget {
  const DeclutteringProtocolScreen({super.key, required this.onAnswers});

  final DetachmentAnswersCallback onAnswers;

  @override
  State<DeclutteringProtocolScreen> createState() =>
      _DeclutteringProtocolScreenState();
}

class _DeclutteringProtocolScreenState
    extends State<DeclutteringProtocolScreen> {
  DetachmentAnswer? _usedInLastTwelveMonths;
  DetachmentAnswer? _deservesPhysicalAndMentalSpace;
  bool _handedOff = false;

  void _selectAnswer({
    required bool usageQuestion,
    required DetachmentAnswer answer,
  }) {
    setState(() {
      if (usageQuestion) {
        _usedInLastTwelveMonths = answer;
      } else {
        _deservesPhysicalAndMentalSpace = answer;
      }
    });

    final usedInLastTwelveMonths = _usedInLastTwelveMonths;
    final deservesPhysicalAndMentalSpace = _deservesPhysicalAndMentalSpace;
    if (usedInLastTwelveMonths == null ||
        deservesPhysicalAndMentalSpace == null) {
      return;
    }

    if (!_handedOff) {
      // The callback is a one-shot visit boundary, while the controls remain
      // revisable for as long as this surface stays open.
      _handedOff = true;
      widget.onAnswers(
        DetachmentAnswers(
          usedInLastTwelveMonths: usedInLastTwelveMonths,
          deservesPhysicalAndMentalSpace: deservesPhysicalAndMentalSpace,
        ),
      );
    }
  }

  Widget _answerButton({
    required Key key,
    required ThemeData theme,
    required String label,
    required DetachmentAnswer answer,
    required DetachmentAnswer? selected,
    required ValueChanged<DetachmentAnswer> onSelected,
  }) {
    final isSelected = answer == selected;
    final colorScheme = theme.colorScheme;
    return Semantics(
      key: key,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      value: isSelected ? label : null,
      child: OutlinedButton(
        onPressed: () => onSelected(answer),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          foregroundColor: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurface,
          minimumSize: const Size(0, Spacing.touchTargetMin),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.chipPaddingHorizontal,
            vertical: Spacing.spacingBase,
          ),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.radiusDefault),
          ),
          textStyle: theme.textTheme.bodyLarge,
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _questionBlock({
    required Key key,
    required Key yesKey,
    required Key noKey,
    required ThemeData theme,
    required String question,
    required DetachmentAnswer? selected,
    required ValueChanged<DetachmentAnswer> onSelected,
  }) {
    final strings = AppStrings.of(context);
    return Semantics(
      key: key,
      container: true,
      explicitChildNodes: true,
      label: question,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            excludeSemantics: true,
            child: Text(
              question,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Spacing.actionGap),
          Row(
            children: [
              Expanded(
                child: _answerButton(
                  key: yesKey,
                  theme: theme,
                  label: strings.answerYes,
                  answer: DetachmentAnswer.yes,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
              const SizedBox(width: Spacing.actionGap),
              Expanded(
                child: _answerButton(
                  key: noKey,
                  theme: theme,
                  label: strings.answerNo,
                  answer: DetachmentAnswer.no,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      // The standard surfaceBase frame, centered — SafeArea first, screen
      // margins on the sides, and a scroll region so both question copy and
      // answer targets remain reachable at 200% text scale. No PopScope:
      // system back is the OS pop and leaves this transient state behind.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _protocolMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _questionBlock(
                    key: _usageQuestionKey,
                    yesKey: _usageYesKey,
                    noKey: _usageNoKey,
                    theme: theme,
                    question: strings.detachmentUseQuestion,
                    selected: _usedInLastTwelveMonths,
                    onSelected: (answer) =>
                        _selectAnswer(usageQuestion: true, answer: answer),
                  ),
                  const SizedBox(height: Spacing.taskToActions),
                  _questionBlock(
                    key: _spaceQuestionKey,
                    yesKey: _spaceYesKey,
                    noKey: _spaceNoKey,
                    theme: theme,
                    question: strings.detachmentSpaceQuestion,
                    selected: _deservesPhysicalAndMentalSpace,
                    onSelected: (answer) =>
                        _selectAnswer(usageQuestion: false, answer: answer),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
