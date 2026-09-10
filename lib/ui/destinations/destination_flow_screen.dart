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

const _keepRowKey = ValueKey<String>(_keepRowKeyId);
const _donateRowKey = ValueKey<String>(_donateRowKeyId);
const _releaseRowKey = ValueKey<String>(_releaseRowKeyId);

/// The flow's one act seam: the tapped row's destination. The
/// callback performs the whole act — the `item_triaged` row plus the
/// purge card's completion, one queued write — and answers whether it
/// landed: the flow pops only on success, so a failed write leaves
/// the decision standing for a re-entry to retry.
typedef DestinationTapCallback = Future<bool> Function(
  TriageDestination destination,
);

/// The three destinations at equal weight (FR-20, UX-DR27): one
/// full-screen decision whose whole content is the three rows below.
/// The rows are constructionally identical — glyph at
/// `Spacing.glyphDestination` beside its label in the destination
/// role, `Spacing.destinationRowGap` between rows, the order fixed
/// `Quedármelo` · `Donar o vender` · `Tirar o soltar` — and a tap
/// fires [onDestination] exactly once: the act, not a selection.
class DestinationFlowScreen extends StatefulWidget {
  const DestinationFlowScreen({super.key, required this.onDestination});

  final DestinationTapCallback onDestination;

  @override
  State<DestinationFlowScreen> createState() => _DestinationFlowScreenState();
}

class _DestinationFlowScreenState extends State<DestinationFlowScreen> {
  bool _handedOff = false;

  /// The flow's one act (Story 6.4): the tap hands the destination to
  /// the sink's callback once — the guard holds the double tap inside
  /// one visit and every later tap of THIS route — and the route pops
  /// only when the act landed. A failed write leaves the flow
  /// standing, quiet (the sink's catch owns the quiet); re-entry —
  /// back, then the protocol again — is the retry.
  Future<void> _handOff(TriageDestination destination) async {
    if (_handedOff) {
      return;
    }
    _handedOff = true;
    final landed = await widget.onDestination(destination);
    if (!mounted) {
      return;
    }
    if (landed) {
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
        onTap: () => _handOff(destination),
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
