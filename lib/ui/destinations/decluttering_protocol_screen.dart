// The Decluttering Protocol's frame (Stories 6.1–6.3, FR-19/20/22,
// UX-DR31): the surface a dealt purge card's `Hecho` opens — and the
// ONLY way in. No menu, list or second entry reaches it; the
// dispenser's ordinary card is the whole door. This surface owns the
// two transient detachment answers and the optional coarse volume tag
// of one visit, and hands the pair to the later destination flow
// through a typed seam: the volume block appears only once both
// answers stand, a tag tap and the decline are one-tap equal outcomes,
// and either fires the one-shot handoff — the visit's whole exit.
import 'package:core/log/log_entry.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The frame's width bound on wide grounds — the surface family's own layout
/// bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _protocolMaxWidth = 480;

const String _usageQuestionKeyId = 'decluttering-protocol-usage';
const String _spaceQuestionKeyId = 'decluttering-protocol-space';
const String _usageYesKeyId = 'decluttering-protocol-usage-yes';
const String _usageNoKeyId = 'decluttering-protocol-usage-no';
const String _spaceYesKeyId = 'decluttering-protocol-space-yes';
const String _spaceNoKeyId = 'decluttering-protocol-space-no';
const String _volumeBlockKeyId = 'decluttering-protocol-volume';
const String _volumeBolsaKeyId = 'decluttering-protocol-volume-bolsa';
const String _volumeCajaKeyId = 'decluttering-protocol-volume-caja';
const String _volumeCajaGrandeKeyId =
    'decluttering-protocol-volume-caja-grande';
const String _volumeMuebleKeyId = 'decluttering-protocol-volume-mueble';
const String _volumeSkipKeyId = 'decluttering-protocol-volume-skip';

const _usageQuestionKey = ValueKey<String>(_usageQuestionKeyId);
const _spaceQuestionKey = ValueKey<String>(_spaceQuestionKeyId);
const _usageYesKey = ValueKey<String>(_usageYesKeyId);
const _usageNoKey = ValueKey<String>(_usageNoKeyId);
const _spaceYesKey = ValueKey<String>(_spaceYesKeyId);
const _spaceNoKey = ValueKey<String>(_spaceNoKeyId);
const _volumeBlockKey = ValueKey<String>(_volumeBlockKeyId);
const _volumeBolsaKey = ValueKey<String>(_volumeBolsaKeyId);
const _volumeCajaKey = ValueKey<String>(_volumeCajaKeyId);
const _volumeCajaGrandeKey = ValueKey<String>(_volumeCajaGrandeKeyId);
const _volumeMuebleKey = ValueKey<String>(_volumeMuebleKeyId);
const _volumeSkipKey = ValueKey<String>(_volumeSkipKeyId);

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

/// The handoff seam between the questions, the optional volume tag and the
/// later destination flow: the answers plus the tag the visit ended on —
/// null when the tag was declined (FR-22: declining writes nothing).
typedef DetachmentAnswersCallback = void Function(
  DetachmentAnswers answers,
  CoarseVolumeTag? volumeTag,
);

/// The Decluttering Protocol's two-question surface with its optional
/// coarse volume block (Stories 6.2–6.3, FR-20/22). [onAnswers] fires
/// once, synchronously from the tap that ends the visit — a tag tap or
/// the decline — and the route pops immediately after: the honest 6.3
/// intermediate state, which Story 6.4's destination flow replaces. It
/// does not complete the purge card or write a log row.
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

  /// Both detachment answers stand — the volume block's whole visibility
  /// rule. Revising either answer keeps them standing, so the block stays
  /// visible while the questions remain revisable.
  bool get _bothAnswersStand =>
      _usedInLastTwelveMonths != null &&
      _deservesPhysicalAndMentalSpace != null;

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
  }

  /// The visit's one exit (Story 6.3): a tag tap or the decline hands the
  /// answers and the tag — null when declined — to the seam once, then
  /// pops the route. The 6.2 behavior of firing on the second answer is
  /// gone: the second answer now reveals the volume block instead.
  void _handOff(CoarseVolumeTag? volumeTag) {
    if (_handedOff) {
      return;
    }
    _handedOff = true;
    widget.onAnswers(
      DetachmentAnswers(
        usedInLastTwelveMonths: _usedInLastTwelveMonths!,
        deservesPhysicalAndMentalSpace: _deservesPhysicalAndMentalSpace!,
      ),
      volumeTag,
    );
    // The seam's sink may synchronously dispose or navigate (6.4 will
    // push the destination flow); popping a deactivated context throws.
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _choiceButton({
    required Key key,
    required ThemeData theme,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    bool inMutuallyExclusiveGroup = false,
  }) {
    final colorScheme = theme.colorScheme;
    return Semantics(
      key: key,
      button: true,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      selected: isSelected,
      value: isSelected ? label : null,
      child: OutlinedButton(
        onPressed: onTap,
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
                child: _choiceButton(
                  key: yesKey,
                  theme: theme,
                  label: AppStrings.of(context).answerYes,
                  isSelected: selected == DetachmentAnswer.yes,
                  inMutuallyExclusiveGroup: true,
                  onTap: () => onSelected(DetachmentAnswer.yes),
                ),
              ),
              const SizedBox(width: Spacing.actionGap),
              Expanded(
                child: _choiceButton(
                  key: noKey,
                  theme: theme,
                  label: AppStrings.of(context).answerNo,
                  isSelected: selected == DetachmentAnswer.no,
                  inMutuallyExclusiveGroup: true,
                  onTap: () => onSelected(DetachmentAnswer.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The optional batch-volume block (Story 6.3, FR-22, UX-DR31): one
  /// question, four coarse tags and the decline — tag and decline are
  /// one-tap equal outcomes with no preselection, no confirm step and no
  /// selection state (the tap IS the act), and either ends the visit.
  /// Nothing here implies an obligation and declining carries no guilt:
  /// the question asks what it was, never what it should have been.
  Widget _volumeBlock({required ThemeData theme}) {
    final strings = AppStrings.of(context);
    return Semantics(
      key: _volumeBlockKey,
      container: true,
      explicitChildNodes: true,
      label: strings.volumeTagQuestion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            excludeSemantics: true,
            child: Text(
              strings.volumeTagQuestion,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Spacing.actionGap),
          Wrap(
            spacing: Spacing.actionGap,
            runSpacing: Spacing.actionGap,
            alignment: WrapAlignment.center,
            children: [
              _choiceButton(
                key: _volumeBolsaKey,
                theme: theme,
                label: strings.volumeTagBolsa,
                onTap: () => _handOff(CoarseVolumeTag.bolsa),
              ),
              _choiceButton(
                key: _volumeCajaKey,
                theme: theme,
                label: strings.volumeTagCaja,
                onTap: () => _handOff(CoarseVolumeTag.caja),
              ),
              _choiceButton(
                key: _volumeCajaGrandeKey,
                theme: theme,
                label: strings.volumeTagCajaGrande,
                onTap: () => _handOff(CoarseVolumeTag.caja_grande),
              ),
              _choiceButton(
                key: _volumeMuebleKey,
                theme: theme,
                label: strings.volumeTagMueble,
                onTap: () => _handOff(CoarseVolumeTag.mueble),
              ),
              // The decline rides the same Wrap as a fifth chip, the
              // same shape and sizing as every tag: an equal one-tap
              // outcome, never weighted as the promoted or the lesser
              // exit (FR-22 — declining simply does not contribute).
              _choiceButton(
                key: _volumeSkipKey,
                theme: theme,
                label: strings.volumeTagSkip,
                onTap: () => _handOff(null),
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
      // margins on the sides, and a scroll region so every question and
      // every target remains reachable at 200% text scale. No PopScope:
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
                  // The block appears only after both answers stand — the
                  // questions stay revisable while it is visible, and a
                  // revision never hides it (both answers still stand).
                  if (_bothAnswersStand) ...[
                    const SizedBox(height: Spacing.taskToActions),
                    _volumeBlock(theme: theme),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
