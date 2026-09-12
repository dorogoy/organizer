// The cumulative impact dashboard (Story 7.4, FR-23, UX-DR30/36/37/
// DR51): the whole of completed work, rendered once. Reached ONLY
// from the Album through `Ver lo que ya has movido` — contextual
// navigation (UX-DR31/32), never a permanent destination, never a
// nav bar entry, unreachable until a first transformation exists.
//
// DENSITY: this screen is the app's single declared exception
// (UX-DR35/36, FR-23) — the one surface where more than one figure
// is allowed, because none of its values admits a denominator: no
// "de N", no average, no target, no period comparison, no rate, no
// percentage, no completion ratio. Every figure is a fact about what
// already happened. The exception must not propagate: no other
// surface may cite this screen as precedent for density.
//
// The skeleton mirrors the Album's register — Scaffold→SafeArea→
// scroll→maxWidth 480 + screenMargin — so the 200% floor holds by
// scrolling (UX-DR45), with one measured exception below: the
// highlight row's reflow, decided in LINES, never in dp (UX-DR30/
// DR46). No AppBar: the way back is `Volver al álbum`, and a
// highlight tap is the same guarded pop — the Album is always
// directly beneath, so popping IS the way into it (no viewer, no
// browse surface).
//
// Read discipline mirrors the Album's (7.3): one-shot read in
// initState, generation-guarded commit, read failure = quiet
// pending plate (close still works), empty album read = self-pop
// behind the `ModalRoute.isCurrent` guard (UX-DR51, defensive — a
// stale affordance over an already-empty album). The dashboard has
// NO empty state and NO write path: it renders what the log holds.
// intl exports its own bidi `TextDirection` (LTR/RTL); the painter
// below needs dart:ui's, so it arrives prefixed and fully named.
import 'dart:ui' as ui;

import 'package:core/derive/impact.dart';
import 'package:core/ports/files_port.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dashboard/dashboard_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import '../glyphs/album_glyph.dart';
import '../glyphs/clock_glyph.dart';
import '../photo_frame.dart';
import '../tokens.dart';

/// The null-seam read (the test seam): every figure zero and no
/// highlights — the read the surface pops on, exactly as an empty
/// album read would.
const ImpactRead _emptyImpactRead = (
  answeredSecondsAllTime: 0,
  cardDoneCount: 0,
  liberatedBolsa: 0,
  liberatedCaja: 0,
  liberatedCajaGrande: 0,
  liberatedMueble: 0,
  highlights: [],
);

/// The cumulative impact dashboard (FR-23). [dashboard] is the 7.4
/// controller the Album's `Ver lo que ya has movido` affordance
/// threads — same store, same Files root, the catalogue loader main
/// composes. Absent (the test seam), the read answers the empty
/// record and the surface pops: nothing half-wired renders.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.dashboard});

  final DashboardController? dashboard;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// The read's figures, null until they resolve — the quiet pending
  /// plate, never a loader. An empty album read never lands here: it
  /// pops the screen instead (UX-DR51, no empty state, no copy).
  ImpactRead? _read;

  /// The generation guard: a read settling after a newer one must not
  /// overwrite it. Deliberate 7.3 pattern-mirroring on a read-only
  /// surface — no re-read path exists today; a future mutation path
  /// inherits the discipline.
  int _readGeneration = 0;

  @override
  void initState() {
    super.initState();
    _readDashboard();
  }

  /// The one commit path (Story 7.4): read, then render or pop — the
  /// Album's own discipline. An empty highlights answer (a stale
  /// affordance over an already-empty album, defensive) pops behind
  /// the isCurrent guard, and a read failure leaves the quiet pending
  /// plate standing with `Volver al álbum` working, never an error
  /// surface and never a zeros reading over a failed read.
  Future<void> _readDashboard() async {
    final generation = ++_readGeneration;
    final controller = widget.dashboard;
    try {
      // The seam's empty answer rides the same await as a real read:
      // the commit path (the pop included) must never run
      // synchronously inside initState — `ModalRoute.of` and
      // `Navigator.of` are frame-scoped.
      final read = controller == null
          ? await Future<ImpactRead>.value(_emptyImpactRead)
          : await controller.read();
      if (!mounted || generation != _readGeneration) {
        return;
      }
      if (read.highlights.isEmpty) {
        // The same isCurrent guard every pop in this flow owns: a
        // route already exiting must not pop again and discard the
        // Album beneath.
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() => _read = read);
    } on Object {
      // The read failed: the quiet pending plate stands, `Volver al
      // álbum` works, and nothing reads as an empty album. Retry is
      // re-entering the surface — close, come back from the Album.
      if (mounted && generation == _readGeneration) {
        setState(() => _read = null);
      }
    }
  }

  /// The way back into the Album (UX-DR30): `Volver al álbum` and a
  /// highlight tap share this one guarded pop — the Album is always
  /// directly beneath (contextual-only reach), so popping IS the way
  /// into it; no viewer, no browse surface, and a double-tap inside
  /// the transition folds to this same single pop.
  void _popToAlbum() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final controller = widget.dashboard;
    final read = _read;
    return Scaffold(
      // The Album's own frame, centered — SafeArea first, screen
      // margins on the sides, the 200% floor holding through
      // SingleChildScrollView. No PopScope: the system back gesture
      // is the OS pop, and closing has zero side effects.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: registerMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The one title — screenHeading, the Album's own
                  // register (the mockup's action-primary title
                  // predates the metricNumeral correction; no spine
                  // rule licenses a second title register).
                  Text(
                    strings.dashboardTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Spacing.taskToActions),
                  if (controller == null || read == null) ...[
                    // The read's quiet pending state (UX-DR29): the
                    // empty right-shape plate on `surface-base` while
                    // the figures resolve, or standing after a read
                    // failure. No spinner, no shimmer, no gradient.
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                    const SizedBox(height: Spacing.actionGap),
                  ] else ...[
                    _MetricRow(
                      glyph: ClockGlyph(Spacing.glyphDense),
                      figure: _workFigure(read.answeredSecondsAllTime, strings),
                      label: strings.dashboardWorkCaption,
                    ),
                    const SizedBox(height: Spacing.cardPadding),
                    _MetricRow(
                      glyph: AlbumGlyph(Spacing.glyphDense),
                      figure: strings.dashboardMicroTasksFigure(
                        read.cardDoneCount,
                      ),
                      label: strings.dashboardMicroTasksLabel(
                        read.cardDoneCount,
                      ),
                    ),
                    _VolumeCard(read: read),
                    const SizedBox(height: Spacing.taskToActions),
                    // The highlight row's section label — support
                    // copy naming where the highlights come from.
                    Text(
                      strings.dashboardAlbumSection,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.actionGap),
                    _HighlightRow(
                      files: controller.files,
                      highlights: read.highlights,
                      onTap: _popToAlbum,
                    ),
                    const SizedBox(height: Spacing.actionGap),
                  ],
                  // The way back — the Album named, the secondary
                  // register, zero side effects.
                  SecondaryTextAction(
                    label: strings.dashboardBackToAlbum,
                    onTap: _popToAlbum,
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

/// The cumulative work figure (Story 7.4, FR-23, {formats.duration}):
/// a sub-minute total renders the existing seconds figure — honestly
/// seconds, never a rounded zero — a total under an hour the existing
/// minutes figure, and an hour or more the hours-and-minutes shape
/// whose minutes arm vanishes at zero. Never a wall-clock sum, never
/// pocket arithmetic: the walk's one charging table already made this
/// figure.
String _workFigure(int seconds, AppStrings strings) {
  if (seconds < 60) {
    return strings.durationSeconds(seconds);
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return strings.dashboardWorkDuration(hours, minutes);
  }
  return strings.durationMinutes(minutes);
}

/// One metric row (mockup §3): the utility glyph at `glyphDense`
/// beside the figure in metricNumeral (titleMedium) with its support
/// label beneath — the glyph's proximity the zone marker's own
/// (chip-to-task, the ladder's proximity mechanism for a paired mark
/// and its text).
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.glyph,
    required this.figure,
    required this.label,
  });

  final Widget glyph;
  final String figure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        glyph,
        const SizedBox(width: Spacing.chipToTask),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // titleMedium is the wired metricNumeral role
              // (theme.dart) — the weight the task and chip use,
              // never the button's.
              Text(figure, style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.spacingBase),
              // bodySmall is the wired support role (theme.dart).
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// The volume card (FR-22, UX-DR37/49): one approximation sentence
/// per non-zero tag, stacked — `≈ 3 cajas liberadas`, gender and
/// plural correct per unit, the unit visible — over the one method
/// line naming the tap vocabulary the tallies came from. The card
/// owns its own gate (FR-22, AD-26): no tally stands, no card — no
/// zero sentence, no method line over nothing, and no stray gap
/// either. The lines carry NO glyph (glyph-adjacency: the only box
/// glyph is `Quedármelo`'s, which would say the opposite of the
/// sentence), and no bolsa↔caja equivalence exists: FR-22 forbids
/// collapsing the units, so each tag keeps its own honest sentence.
class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.read});

  final ImpactRead read;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final sentences = <String>[
      if (read.liberatedBolsa > 0)
        strings.liberatedVolumeBolsa(read.liberatedBolsa),
      if (read.liberatedCaja > 0)
        strings.liberatedVolumeCaja(read.liberatedCaja),
      if (read.liberatedCajaGrande > 0)
        strings.liberatedVolumeCajaGrande(read.liberatedCajaGrande),
      if (read.liberatedMueble > 0)
        strings.liberatedVolumeMueble(read.liberatedMueble),
    ];
    if (sentences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.cardPadding),
        Container(
          // The volume card's own tone is surface-base on the raised
          // frame — the mockup's own pairing, radiusDefault, cardPadding.
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(Radii.radiusDefault),
          ),
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final sentence in sentences) ...[
                Text(sentence, style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.chipToTask),
              ],
              Text(
                strings.dashboardVolumeMethod,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The highlight row (Story 7.4, FR-23, UX-DR30/46): up to three
/// columns `actionGap` apart — each a Before/After pair of
/// `PhotoFrame`s at `radiusThumb` (pair gap `spacingBase`) with a
/// support caption `place · short-date` beneath — and the one
/// measured reflow in the app: any caption laying out beyond TWO
/// LINES at its candidate width, under the ambient scaler, drops the
/// WHOLE row to one column per row. The trigger is measured in lines
/// (`TextPainter` at the candidate width), never in dp, never
/// `maxLines` or ellipsis (the lint bans them); the dp gaps never
/// scale with the font; nothing shrinks and nothing truncates — the
/// 200% degradation is expected, not a defect.
class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.files,
    required this.highlights,
    required this.onTap,
  });

  final FilesPort files;
  final List<ImpactHighlight> highlights;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final dateFactory = DateFormat(
      Formats.shortDateFormat,
      Localizations.localeOf(context).toString(),
    );
    String captionOf(ImpactHighlight highlight) {
      // The act's own recorded civil day (AD-4): the instant offset by
      // the offset its `album_entry_added` row recorded — never the
      // reading device's zone — formatted as the locale's short date.
      final date = dateFactory.format(
        DateTime.fromMicrosecondsSinceEpoch(
          highlight.addedUtcMicros +
              highlight.offsetSeconds * Duration.microsecondsPerSecond,
          isUtc: true,
        ),
      );
      final place = highlight.place;
      // A null OR empty place is no place: the dateless caption, the
      // date alone — never an invented label, never a dangling
      // separator.
      return place == null || place.isEmpty
          ? strings.dashboardHighlightDatelessCaption(date)
          : strings.dashboardHighlightCaption(place, date);
    }

    final captions = [for (final highlight in highlights) captionOf(highlight)];
    return LayoutBuilder(
      builder: (context, constraints) {
        // No cells, no row — the width arithmetic below never divides
        // by an empty column count.
        if (highlights.isEmpty) {
          return const SizedBox.shrink();
        }
        final cells = [
          for (var i = 0; i < highlights.length; i++)
            _HighlightCell(
              files: files,
              highlight: highlights[i],
              caption: captions[i],
              onTap: onTap,
            ),
        ];
        // The three-column candidate width: the row's own width minus
        // the fixed actionGap columns between the cells.
        final columnCount = cells.length;
        final gaps = (columnCount - 1) * Spacing.actionGap;
        final candidateWidth = (constraints.maxWidth - gaps) / columnCount;
        final support = theme.textTheme.bodySmall;
        final scaler = MediaQuery.textScalerOf(context);
        // A narrow parent can leave no positive width for the candidate
        // columns. Reflow before measuring so TextPainter never receives
        // an invalid maxWidth; the one-column layout is the existing
        // graceful degradation for this constraint.
        final widthRequiresReflow =
            !candidateWidth.isFinite || candidateWidth <= 0;
        final anyCaptionBeyondTwoLines = widthRequiresReflow
            ? false
            : captions.any(
                (caption) =>
                    _lineCount(caption, candidateWidth, scaler, support) > 2,
              );
        if (widthRequiresReflow ||
            anyCaptionBeyondTwoLines ||
            columnCount == 1) {
          // One column per row (UX-DR30/46): the whole row reflows,
          // the gaps stay the row's own unscaled actionGap, and every
          // caption renders whole.
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.actionGap),
                cells[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.actionGap),
              Expanded(child: cells[i]),
            ],
          ],
        );
      },
    );
  }

  /// How many lines [caption] occupies at [maxWidth] under [scaler]
  /// — the reflow's measured trigger. A laid-out painter, measured
  /// and released; the rendered caption itself stays unconstrained.
  /// The scaler is the AMBIENT one, read (never overridden — UX-DR45):
  /// it reaches the painter through its setter because the lint bans
  /// the constructor's named slot textually, and the measure must see
  /// exactly the scale the rendered caption will.
  static int _lineCount(
    String caption,
    double maxWidth,
    TextScaler scaler,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: caption, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    painter.textScaler = scaler;
    painter.layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines;
  }
}

/// One highlight cell (UX-DR30): the Before/After pair at the
/// thumbnail's cut edge (`spacingBase` apart — the row's own tight
/// pair, tighter than the Album's full pair), the caption beneath in
/// the support role, and the whole cell one guarded pop into the
/// Album — never a viewer, never a browse surface.
class _HighlightCell extends StatelessWidget {
  const _HighlightCell({
    required this.files,
    required this.highlight,
    required this.caption,
    required this.onTap,
  });

  final FilesPort files;
  final ImpactHighlight highlight;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Semantics(
      // The way-into-the-album action, named for screen readers —
      // the reward's own `Ver el álbum` key reused verbatim, no new
      // ARB: the cell's tap IS that same guarded pop into the Album.
      button: true,
      label: strings.rewardOpenAlbum,
      child: GestureDetector(
        // Opaque so the whole cell takes the tap — the caption's air
        // included, the secondary action's own target discipline.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PhotoFrame(
                    files: files,
                    name: highlight.beforeName,
                    radius: Radii.radiusThumb,
                  ),
                ),
                const SizedBox(width: Spacing.spacingBase),
                Expanded(
                  child: PhotoFrame(
                    files: files,
                    name: highlight.afterName,
                    radius: Radii.radiusThumb,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.chipToTask),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
