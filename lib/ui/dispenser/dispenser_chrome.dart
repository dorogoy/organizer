// The Dispenser's chrome (Stories 2.1–2.3 and 3.2): the surface's
// furniture around the view — the pocket-trigger band with the Lápiz
// entry, the quiet ladder sheet, the footer band, and the one frame
// every resolved state shares. Extracted from `dispenser_screen.dart`
// (`_pocketTrigger`, the ladder sheet inside `_openPocketLadder`,
// `_footerActions`, `_pinnedFooterBand`, `_frame`, `_LapizEntry`,
// `_PocketLadderOption`), moved output-equivalent — code verbatim
// where it renders, prose adapted to this home; the rendered output
// is unchanged.
//
// The footer (Story 2.1, UX-DR25): `Nuevo proyecto` sits bottom-centred
// as the surface's one prose departure — ink-secondary text, 48dp
// opaque target, no glyph, no pastel mass, nothing animated — pinned
// as chrome below the scroll region. It opens the intermediate surface
// that carries the `Ajustes` way-out alone (NFR3, AD-26).
//
// The pocket trigger (Story 2.2, FR-8, UX-DR18): a `duration-chip` pill
// pinned top-centred as chrome above the scroll region — above the card
// on the dealt surface, standing alone on the warm close — carrying
// `Tengo {minutes} minutos ahora`, the standing declared pocket while a
// pocketed session is open, else 15. One tap opens a quiet, titleless
// ladder sheet of stepped duration pills; choosing one declares the
// pocket and the surface commits whatever the log now makes true — the
// carried card, a pocket-bounded deal, or the same warm close as pool
// exhaustion. No countdown, no remaining minutes, no new session state,
// and no error surface anywhere on this path.
//
// The stop control (Story 2.3, FR-9, UX-DR43): `Quiero parar` stands in
// the footer band on BOTH the dealt and closed views — never disabled,
// never suggested, one tap, any moment, any reason. The tap is the
// pause write — exactly one `session_ended` row, no payload — and the
// committed view is the standing warm close with the trigger chip back
// at its 15 default: the close is the stop's whole presentation,
// silent by construction. A tap with nothing open appends nothing —
// the accepted quiet no-op. The footer band wraps (never truncates) at
// 200%, and on a body too short to hold the pinned chrome the chip and
// band join the scroll region together: the accessibility floor
// outranks UX-DR45's pin.
//
// The Lápiz entry (Story 3.2, FR-27): the Manual Capture affordance
// joins the top chrome band top-right — the utility glyph inside a 48dp
// target, beside the centred chip it never displaces, in both chrome
// branches (pinned and in-frame). One tap, guarded like every push this
// surface owns, opens the capture surface; nothing here lists, counts
// or remembers captures — the entry is a way in, never a way back.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../glyphs/pencil_glyph.dart';
import '../tokens.dart';
import 'duration_chip.dart';
import 'task_card.dart';

/// The card's width bound on wide grounds. A layout bound, not a gap: no
/// DESIGN token exists for it, and the tokenized side rule
/// (`Spacing.screenMargin`) stays in force below it.
const double _cardMaxWidth = 480;

/// The ladder's stepped options (Story 2.2): every offered value is
/// inside the pocket's command range, so out-of-range is unreachable
/// from the surface. Swapping the list changes nothing else — the log
/// payload and the command contract are unaffected.
const List<int> pocketLadderOptions = [5, 10, 15, 20, 25, 30, 45, 60];

/// The top chrome band (Stories 2.2 and 3.2): the pocket trigger pill
/// top-centred above the card — and standing on the warm close too,
/// because a spent pocket is declared until superseded — with the
/// Lápiz entry top-right in the same band, overlaid so the chip keeps
/// the exact layout it owned alone: full-band wrap width and the
/// screen's x-axis centre, in both chrome branches (pinned and
/// in-frame). The carried minutes are log-derived data, never session
/// state held in memory as truth.
class PocketTriggerBand extends StatelessWidget {
  const PocketTriggerBand({
    super.key,
    required this.minutes,
    this.inFrame = false,
    this.onOpenLadder,
    this.onOpenCapture,
  });

  /// The standing declared pocket the trigger chip carries — the
  /// surface's defaulted value, from the read view's own fact.
  final int minutes;

  /// Whether this band sits inside the frame's scroll region (the
  /// accessibility floor's short-body branch) instead of pinned above
  /// it — the in-frame branch carries no screen margins of its own.
  final bool inFrame;

  /// The chip's tap: the screen's ladder-sheet opener.
  final VoidCallback? onOpenLadder;

  /// The Lápiz entry's tap: the screen's capture-surface opener.
  final VoidCallback? onOpenCapture;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.spacingBase),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inFrame ? 0 : Spacing.screenMargin,
          ),
          child: Stack(
            children: [
              Center(
                // On a wide ground, symmetric inner bounds — one glyph
                // zone wide plus the action gap — keep the chip exactly
                // screen-centred while it wraps clear of the Lápiz
                // target: the band reads as two controls, never one
                // pastel passing beneath a glyph. On a short ground the
                // accessibility floor outranks the clearance (Story
                // 2.3's own precedent): the chip keeps the full-band
                // wrap it owned alone and the glyph overlays the band's
                // edge, because starving the wrap there would grow the
                // band past the floor.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final clearOfGlyph = constraints.maxWidth >= _cardMaxWidth;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: clearOfGlyph
                            ? Spacing.touchTargetMin + Spacing.actionGap
                            : 0,
                      ),
                      child: PocketTriggerChip(
                        minutes: minutes,
                        onTap: onOpenLadder,
                      ),
                    );
                  },
                ),
              ),
              Positioned.directional(
                textDirection: Directionality.of(context),
                end: 0,
                top: 0,
                bottom: 0,
                child: Center(child: _LapizEntry(onTap: onOpenCapture)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quiet stepped ladder's content (Story 2.2): the titleless sheet
/// of duration pills — the `size-option` idiom — every option in the
/// command's range, [pocketLadderOptions], selected marking the
/// standing pocket. The sheet wraps and scrolls at 200%; a tap pops
/// the sheet and declares through [onSelect]. Nothing here shows a
/// remainder, nothing counts down, and no error state exists for a
/// refused value to reach.
class PocketLadderSheet extends StatelessWidget {
  const PocketLadderSheet({
    super.key,
    required this.standingMinutes,
    required this.onSelect,
  });

  /// The standing declared pocket the selected pill marks.
  final int standingMinutes;

  /// A pill's tap calls [onSelect] with that pill's minutes.
  final void Function(int minutes) onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        child: Wrap(
          spacing: Spacing.actionGap,
          runSpacing: Spacing.actionGap,
          children: [
            for (final minutes in pocketLadderOptions)
              _PocketLadderOption(
                minutes: minutes,
                selected: standingMinutes == minutes,
                onTap: () => onSelect(minutes),
              ),
          ],
        ),
      ),
    );
  }
}

/// The footer band's two prose controls (Stories 2.1, 2.3, UX-DR25,
/// UX-DR43): `Quiero parar` beside `Nuevo proyecto`, both through the
/// `action-secondary` grammar — ink-secondary text, 48dp opaque
/// targets, no glyph, no pastel mass, nothing animated. The band
/// wraps; nothing in it ever truncates. Pinned below the scroll
/// region (UX-DR45) it takes the safe area and the screen margins —
/// the common surface; a body below the text-scaled chrome floor
/// never reaches that branch: both chrome controls join the scroll
/// region instead ([inFrame]).
class DispenserFooterBand extends StatelessWidget {
  const DispenserFooterBand({
    super.key,
    this.inFrame = false,
    this.onStop,
    this.onNewProject,
  });

  /// Whether this band sits inside the frame's scroll region (the
  /// accessibility floor's short-body branch) instead of pinned below
  /// it — the in-frame branch carries no safe area or margins of its
  /// own.
  final bool inFrame;

  /// The stop's tap: the screen's pause path (Story 2.3, FR-9).
  final VoidCallback? onStop;

  /// The `Nuevo proyecto` tap: the screen's way-out push (Story 2.1,
  /// NFR3, AD-26).
  final VoidCallback? onNewProject;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.actionGap,
      runSpacing: Spacing.spacingBase,
      children: [
        SecondaryTextAction(
          label: AppStrings.of(context).actionStop,
          onTap: onStop,
        ),
        SecondaryTextAction(
          label: AppStrings.of(context).newProjectLink,
          onTap: onNewProject,
        ),
      ],
    );
    if (inFrame) {
      return actions;
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
        child: actions,
      ),
    );
  }
}

/// The one frame every resolved state shares: scroll when the content
/// outgrows the viewport, center it in the remaining flex otherwise,
/// with the 48dp minimum air inside the screen margins and the
/// max-width bound. SafeArea first, so scrolled content never renders
/// under the status bar or a cutout — the minimum air lives inside it.
class DispenserFrame extends StatelessWidget {
  const DispenserFrame({super.key, required this.child});

  /// The resolved content this frame centers, bounds and scrolls.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: child,
      ),
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenMargin,
                // The air around the card: minimum 48 plus flex, carried
                // here rather than in a token precisely because a token
                // reads as a fixed value (UX-DR14).
                vertical: Spacing.touchTargetMin,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Lápiz entry (Story 3.2, FR-27): the Manual Capture affordance —
/// the utility glyph in its neutral mass inside a 48dp opaque target,
/// declared to readers as a button (the battery mark's own grammar).
/// One tap opens the capture surface; no painted label, no fill, no
/// badge, nothing animated, and nothing about it counts or lists
/// captures — mass is the visual, `lapizEntry` is the spoken name.
class _LapizEntry extends StatelessWidget {
  const _LapizEntry({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.of(context).lapizEntry,
      child: GestureDetector(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: Spacing.touchTargetMin,
          height: Spacing.touchTargetMin,
          child: Center(child: PencilGlyph(Spacing.glyphZoneMarker)),
        ),
      ),
    );
  }
}

/// One stepped ladder pill (Story 2.2, the `size-option` idiom): a
/// duration pill — selected fills `colorScheme.primary` (the theme's
/// accent-soft mapping, the same pastel `DurationChip` fills), unselected
/// sits raised with a 1px hairline edge — ink-primary in the duration
/// role on both, `rounded.full`, 48dp minimum, never a glyph. The label
/// is the minutes themselves through the duration format; context is the
/// chip just tapped, so the sheet carries no title and no internal name
/// renders.
class _PocketLadderOption extends StatelessWidget {
  const _PocketLadderOption({
    required this.minutes,
    required this.selected,
    this.onTap,
  });

  final int minutes;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.radiusFull),
        side: selected
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        child: Semantics(
          // The affordance reaches screen readers as a button carrying
          // selection state, never as a different visual grammar: the
          // spoken label is the minutes value the pill's own text
          // already carries.
          button: true,
          selected: selected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.chipPaddingHorizontal,
              ),
              child: Center(
                child: Text(
                  durationLabel(minutes * 60, AppStrings.of(context)),
                  // titleSmall is the wired duration role (theme.dart).
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
