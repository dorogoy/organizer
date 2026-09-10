// The 3-Destination Flow (Story 6.4, FR-20, UX-DR27/47/49, DESIGN.md
// {components.destination-flow}): the full-screen decision the
// Decluttering Protocol's handoff pushes — three equal rows and
// nothing else. Each row is a 64px destination glyph beside its
// verbatim ARB label on the raised ground; the tap IS the act — no
// selection state, no confirm step, and no question or object line
// (the authored fixed-string register holds only the three labels for
// this flow, and AD-15 forbids unaudited sentence assembly). Hue
// lives only inside the glyphs: no tile, field, bar or band, no
// default, preselection or ordering signal — differentiation rides
// on silhouette alone. Dark mode keeps the light form (UX-DR13): the
// glyphs draw their own dark masses and the label renders in dark
// ink-primary, both through the wired theme. The system back gesture
// is the OS pop — nothing is written, and the purge card stands on
// the dispenser below.
//
// Since Story 6.5 the flow carries one quiet text affordance below
// the trio (FR-21): `Todavía no lo decido`, the hesitation in the
// user's own voice. It is deliberately NOT a fourth destination row
// — no glyph (silhouette differentiation is load-bearing among the
// trio, and the Caja silhouette already means keep), no
// destination-label role (the support role instead), and its own
// construction — so the trio's equality stands untouched (FR-20,
// UX-DR27). The tap performs the quarantine act through the flow's
// second callback seam and shares the rows' one-shot guard and
// pop-only-on-success path exactly.
import 'package:core/log/log_entry.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../glyphs/bag_glyph.dart';
import '../glyphs/box_glyph.dart';
import '../glyphs/seed_glyph.dart';
import '../tokens.dart';

/// The flow's width bound on wide grounds — the surface family's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _flowMaxWidth = 480;

const String _keepRowKeyId = 'destination-flow-keep';
const String _donateRowKeyId = 'destination-flow-donate';
const String _releaseRowKeyId = 'destination-flow-release';
const String _quarantineAffordanceKeyId = 'destination-flow-quarantine';

const _keepRowKey = ValueKey<String>(_keepRowKeyId);
const _donateRowKey = ValueKey<String>(_donateRowKeyId);
const _releaseRowKey = ValueKey<String>(_releaseRowKeyId);
const _quarantineAffordanceKey = ValueKey<String>(_quarantineAffordanceKeyId);

/// The flow's destination act seam: the tapped row's destination. The
/// callback performs the whole act — the `item_triaged` row plus the
/// purge card's completion, one queued write — and answers whether it
/// landed: the flow pops only on success, so a failed write leaves
/// the decision standing for a re-entry to retry.
typedef DestinationTapCallback = Future<bool> Function(
  TriageDestination destination,
);

/// The flow's second act seam (Story 6.5, FR-21): the hesitation
/// affordance's tap. The callback performs the whole act — the
/// `box_created` row, the `item_triaged(quarantine)` row linking it
/// and the purge card's completion, one queued write — and answers
/// whether it landed: the flow pops only on success, exactly as a
/// destination's tap does.
typedef QuarantineTapCallback = Future<bool> Function();

/// The three destinations at equal weight (FR-20, UX-DR27): one
/// full-screen decision whose trio content is the three rows below,
/// with the quiet hesitation affordance below them (Story 6.5).
/// The rows are constructionally identical — glyph at
/// `Spacing.glyphDestination` beside its label in the destination
/// role, `Spacing.destinationRowGap` between rows, the order fixed
/// `Quedármelo` · `Donar o vender` · `Tirar o soltar` — and a tap
/// fires [onDestination] or [onQuarantine] exactly once: the act, not a
/// selection.
class DestinationFlowScreen extends StatefulWidget {
  const DestinationFlowScreen({
    super.key,
    required this.onDestination,
    required this.onQuarantine,
  });

  final DestinationTapCallback onDestination;

  /// The hesitation affordance's act seam (Story 6.5, FR-21) — the
  /// one tap below the trio, sharing the rows' guard and pop path.
  final QuarantineTapCallback onQuarantine;

  @override
  State<DestinationFlowScreen> createState() => _DestinationFlowScreenState();
}

class _DestinationFlowScreenState extends State<DestinationFlowScreen> {
  bool _handedOff = false;

  /// The flow's one act (Stories 6.4/6.5): a tap hands its act to the
  /// sink's callback once — the guard holds the double tap inside one
  /// visit and every later tap of THIS route, destination and
  /// hesitation alike — and the route pops only when the act landed.
  /// A failed write leaves the flow standing, quiet (the sink's catch
  /// owns the quiet), and re-arms the guard in place: the next tap of
  /// this route is the retry, no back-and-protocol needed.
  Future<void> _handOff(Future<bool> Function() act) async {
    if (_handedOff) {
      return;
    }
    _handedOff = true;
    final landed = await act();
    if (!mounted) {
      return;
    }
    if (!landed) {
      // The sink absorbed a failed write and the flow remains the current
      // decision. Re-arm its one-shot guard so the user may retry the act
      // here, as the dispenser's ordinary Hecho path does.
      setState(() => _handedOff = false);
      return;
    }
    // System back can remove this route while the write is still pending.
    // A late success must never pop whichever route is now current beneath
    // it (normally the dispenser).
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  Widget _destinationRow({
    required Key key,
    required Widget glyph,
    required String label,
    required TriageDestination destination,
    required ThemeData theme,
  }) {
    return Semantics(
      key: key,
      button: true,
      child: InkWell(
        onTap: () => _handOff(() => widget.onDestination(destination)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.spacingBase),
          child: Row(
            children: [
              glyph,
              // The glyph sits beside its label at the measured mockup
              // row's proximity, `Spacing.cardPadding` — the scale's
              // interior inset; the row itself carries no other chrome,
              // so the pair is the whole target.
              const SizedBox(width: Spacing.cardPadding),
              // Flexible, so the label wraps at 200% instead of
              // overflowing its row — growing, never truncating
              // (UX-DR45, no maxLines, no ellipsis).
              Expanded(
                // titleLarge is the wired destination-label role
                // (theme.dart), dark ink included.
                child: Text(label, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The hesitation affordance (Story 6.5, FR-21): text alone, in
  /// the support role, centered below the trio — no glyph, no
  /// destination-label role, and its own construction, so it cannot
  /// read as a fourth equal choice (FR-20's equality is the trio's
  /// own). The target keeps the 48dp floor and the label wraps at
  /// 200% (UX-DR45 — no maxLines, no ellipsis), and the tap shares
  /// the rows' one act: the same guard, the same pop-only-on-success.
  Widget _quarantineAffordance({
    required Key key,
    required ThemeData theme,
    required AppStrings strings,
  }) {
    return Semantics(
      key: key,
      button: true,
      child: InkWell(
        onTap: () => _handOff(widget.onQuarantine),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Spacing.touchTargetMin),
          child: Center(
            child: Text(
              strings.destinationQuarantine,
              // bodySmall is the wired support role (theme.dart) —
              // the Settings quiet-text register, never the
              // destination-label role the trio carries.
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      // The raised ground — DESIGN's `background: surface-raised`, the
      // wired `surfaceContainerHighest` — tone alone, never a shadow,
      // and never a field a destination hue may fill.
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      // No AppBar and no PopScope: the system back gesture is the OS
      // pop, writing nothing on its way out.
      body: SafeArea(
        // The house full-screen pattern (the protocol's own scaffold):
        // SafeArea first, screen margins on the sides, a scroll region
        // so every row stays reachable at 200% text scale — and the
        // decision centered when it fits, one decision on a whole
        // screen.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.screenMargin,
                    vertical: Spacing.touchTargetMin,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _flowMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _destinationRow(
                          key: _keepRowKey,
                          glyph: const BoxGlyph(Spacing.glyphDestination),
                          label: strings.destinationKeep,
                          destination: TriageDestination.keep,
                          theme: theme,
                        ),
                        const SizedBox(height: Spacing.destinationRowGap),
                        _destinationRow(
                          key: _donateRowKey,
                          glyph: const BagGlyph(Spacing.glyphDestination),
                          label: strings.destinationDonate,
                          destination: TriageDestination.donate_sell,
                          theme: theme,
                        ),
                        const SizedBox(height: Spacing.destinationRowGap),
                        _destinationRow(
                          key: _releaseRowKey,
                          glyph: const SeedGlyph(Spacing.glyphDestination),
                          label: strings.destinationRelease,
                          destination: TriageDestination.trash_recycle,
                          theme: theme,
                        ),
                        // More air than a row gap (the scale's own next
                        // step): the affordance sits below the TRIO as
                        // its own quiet thing, never as a fourth row of
                        // the trio's rhythm (FR-20, UX-DR27) — its own
                        // named gap, not the tappable-box floor.
                        const SizedBox(height: Spacing.destinationAsideGap),
                        _quarantineAffordance(
                          key: _quarantineAffordanceKey,
                          theme: theme,
                          strings: strings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
