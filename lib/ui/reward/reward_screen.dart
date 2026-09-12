// The reward surface (Story 7.1, FR-17, UX-DR29/DR39/DR40/DR57): the
// milestone's pushed full-screen moment over a slicer-origin space.
// Two arms, one register — the shared full-screen surfaceBase frame
// (Scaffold→SafeArea→scroll→maxWidth 480 + screenMargin, the consent
// gate's own grammar):
//
// - A Before exists: the Before plate stands, the one recommended
//   action shoots the After, and the landed pair shows — two EQUAL
//   plates (same size, same height, same corner, 3:4 with a 1px
//   hairline, `photoPairGap` apart), the labels `Antes`/`Después`
//   OUTSIDE the frames, nothing else. The pair has no caption and no
//   share action; the save is the flow's own (`album_entry_added`,
//   automatic — AD-21).
// - No Before ever (declined, camera-blocked, typed-genesis): `Un
//   trabajo estupendo` and `Cerrar` — no shoot prompt, no pair, no
//   one-plate diff, no placeholder plate (UX-DR57).
//
// The copy carries no adjective about the result anywhere (FR-17's
// frozen boundary), and the secondary control is always `Cerrar` —
// never a *seguir* variant (UX-DR39). Closing — `Cerrar` or the OS
// back — has zero side effects: no act, no album entry, no blob for
// the After, and the reward is never re-offered for that milestone.
// The shoot action follows the Cámara entry rule (UX-DR24): when the
// rule blocks it the arm degrades to the no-photo presentation —
// absent never greyed, no dead button — and a shoot that fails
// mid-flow (denied open, lost grant, failed write) degrades the same
// way with nothing written: no error dead-end, no retry loop.
import 'package:core/derive/reward.dart';
import 'package:core/ports/files_port.dart';
import 'package:flutter/material.dart';

import '../../album/album_controller.dart';
import '../../dashboard/dashboard_controller.dart';
import '../../reward/reward_controller.dart';
import '../../strings/app_strings.dart';
import '../album/album_screen.dart';
import '../dispenser/task_card.dart';
import '../photo_frame.dart';
import '../photo_shoot_screen.dart';
import '../tokens.dart';

/// The reward surface (FR-17). [space] is the milestone's named space —
/// the core's own `NamedRewardSpace` record, the group the derivation
/// named. [controller] is the reward seam main composes over the same
/// store, Files and camera the scan path holds; absent (the test
/// seam), the read answers the no-photo presentation and a shoot
/// writes nothing. [album] is the 7.2 controller the pair-landed
/// arm's `Ver el álbum` affordance threads into the gallery (Story
/// 7.3) — absent, the affordance renders nowhere (never a dead
/// button). [dashboard] is the 7.4 controller threaded one hop
/// further — the gallery's `Ver lo que ya has movido` affordance is
/// the dashboard's only entry point (Story 7.4); absent, that
/// affordance renders nowhere either.
class RewardScreen extends StatefulWidget {
  const RewardScreen({
    super.key,
    required this.space,
    this.controller,
    this.album,
    this.dashboard,
  });

  final NamedRewardSpace space;
  final RewardController? controller;

  /// The album seam (Story 7.3, FR-18): the pair-landed arm's
  /// contextual way onward into the gallery — the album's ONLY entry
  /// point anywhere in the app (UX-DR31/32).
  final AlbumController? album;

  /// The dashboard seam (Story 7.4, FR-23): the cumulative impact
  /// read's controller, threaded through the gallery — the hop the
  /// Dispenser's milestone push carries so main's one composition
  /// reaches the whole contextual chain.
  final DashboardController? dashboard;

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  /// The read's facts, null until they resolve — the quiet empty
  /// frame, never a loader.
  RewardRead? _read;

  /// The landed After blob's name: the pair state's own fact. Null
  /// until the pair exists (and never again after a degrade).
  String? _afterName;

  /// Whether the arm degraded to the no-photo presentation — a
  /// blocked shoot rule or a failed shoot, indistinguishable on the
  /// surface by design (UX-DR57's one register).
  bool _degraded = false;

  /// Whether a shoot is between its tap and its settle: one shoot
  /// owns the surface, so a rapid second tap is nothing at all.
  bool _shootInFlight = false;

  @override
  void initState() {
    super.initState();
    _readReward();
  }

  Future<void> _readReward() async {
    final controller = widget.controller;
    final read = controller == null
        ? const RewardRead(beforeName: null, cameraAllowed: false)
        : await controller.read(widget.space);
    if (mounted) {
      setState(() => _read = read);
    }
  }

  /// The shoot-After tap (FR-17): the shared shoot pipeline's
  /// viewfinder (`PhotoShootScreen`) mounts over the reward — the
  /// user frames the space's After beside the Before they framed at
  /// delivery, never a blind shot — with the commit half writing the
  /// blob plus the `album_entry_added` row, automatic. The
  /// viewfinder's answer routes: captured stands the pair; denied or
  /// failed degrades to the no-photo presentation with nothing
  /// written (the milestone spent either way — no error surface, no
  /// retry loop); the quiet exit (the OS back, or a system problem
  /// noticed and backed out of) leaves the reward standing exactly as
  /// it was, shoot primary still present.
  Future<void> _shootAfter() async {
    final controller = widget.controller;
    final read = _read;
    final beforeName = read?.beforeName;
    if (_shootInFlight ||
        controller == null ||
        beforeName == null ||
        !(read?.cameraAllowed ?? false)) {
      return;
    }
    _shootInFlight = true;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoShootScreen(
          camera: controller.camera,
          onDenied: controller.appendCameraRefusal,
          degradeOnSystemFailure: true,
          commit: (bytes) => controller.saveAfterBlob(
            bytes,
            space: widget.space,
            beforeName: beforeName,
          ),
        ),
      ),
    );
    _shootInFlight = false;
    if (!mounted) {
      return;
    }
    switch (result) {
      case PhotoShootCaptured(:final blobName):
        setState(() => _afterName = blobName);
      case PhotoShootDenied():
        setState(() => _degraded = true);
      case PhotoShootFailed():
        setState(() => _degraded = true);
      case null:
        // The quiet exit: nothing written, the reward keeps standing
        // with its shoot primary — the next tap may ask again (the
        // scan surface's own re-ask rule for system problems).
        break;
    }
  }

  /// The gallery's one entry point (Story 7.3, FR-18, UX-DR31/32):
  /// the pair-landed arm's quiet prose way onward — never a permanent
  /// destination, never rendered on any other arm. The push sits
  /// behind the same rapid-tap guard every push in this flow owns; a
  /// stale affordance over an already-empty album degrades to the
  /// gallery's own open-then-pop, accepted and self-correcting.
  void _openAlbum() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              AlbumScreen(album: widget.album, dashboard: widget.dashboard),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final controller = widget.controller;
    final read = _read;
    final beforeName = read?.beforeName;
    final afterName = _afterName;
    // The shoot is offered exactly while a Before stands, the Cámara
    // entry rule admits it, and a seam exists behind it (UX-DR24:
    // absent never greyed — a blocked rule or a missing seam renders
    // the no-photo presentation, never a dead button).
    final shootOffered =
        controller != null &&
        !_degraded &&
        beforeName != null &&
        (read?.cameraAllowed ?? false);
    return Scaffold(
      // The standard surfaceBase frame, centered — the consent gate's
      // own grammar: SafeArea first, screen margins on the sides, the
      // 200% floor holding through SingleChildScrollView. No PopScope:
      // the system back gesture is the OS pop, and closing has zero
      // side effects.
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
                  if (read == null) ...[
                    // The read's quiet pending state (UX-DR29, the
                    // review's flash patch): while the facts resolve
                    // the surface renders the empty right-shape plate
                    // on `surface-base` — NEVER the no-photo text, so
                    // a space WITH a Before cannot flash `Un trabajo
                    // estupendo` before its read lands. No spinner, no
                    // shimmer, no gradient.
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                    const SizedBox(height: Spacing.taskToActions),
                  ] else if (beforeName != null &&
                      afterName != null &&
                      controller != null) ...[
                    // The equal pair (UX-DR29/DR40): both plates the
                    // same size at the same height with the same
                    // corner — two `Expanded` halves of one row, 3:4
                    // by the frame's own aspect, `photoPairGap` apart —
                    // the labels outside the frames and nothing else:
                    // no caption, no share action, no count.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _LabeledPlate(
                            files: controller.files,
                            name: beforeName,
                            label: strings.rewardLabelBefore,
                          ),
                        ),
                        const SizedBox(width: Spacing.photoPairGap),
                        Expanded(
                          child: _LabeledPlate(
                            files: controller.files,
                            name: afterName,
                            label: strings.rewardLabelAfter,
                          ),
                        ),
                      ],
                    ),
                    if (widget.album != null) ...[
                      // The album's one entry point (Story 7.3, FR-18,
                      // UX-DR31/32): the transformation-completed
                      // moment's quiet prose way onward — this arm
                      // alone, never the shoot-offered or no-Before
                      // arms, never anywhere else in the app.
                      const SizedBox(height: Spacing.taskToActions),
                      SecondaryTextAction(
                        label: strings.rewardOpenAlbum,
                        onTap: _openAlbum,
                      ),
                    ],
                  ] else if (shootOffered) ...[
                    // The Before plate and the one recommended action
                    // (the I/O matrix's reward route): the plate
                    // stands while the After is owed, and the flow's
                    // own save lands with the shot.
                    _LabeledPlate(
                      files: controller.files,
                      name: beforeName,
                      label: strings.rewardLabelBefore,
                    ),
                    const SizedBox(height: Spacing.taskToActions),
                    HechoButton(
                      label: strings.rewardAfterShoot,
                      onTap: _shootAfter,
                    ),
                  ] else ...[
                    // `Un trabajo estupendo` (UX-DR57): the no-Before
                    // milestone's whole presentation — and the
                    // degraded shoot's, indistinguishable by design.
                    // bodyMedium is the wired action-secondary role —
                    // the no-Slicer causes' own register (theme.dart).
                    Text(
                      strings.rewardWithoutPhoto,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.taskToActions),
                  ],
                  // The one secondary control, every arm the same:
                  // `Cerrar`, never a *seguir* variant (UX-DR39) —
                  // closing has zero side effects.
                  SecondaryTextAction(
                    label: strings.rewardClose,
                    onTap: () => Navigator.of(context).pop(),
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

/// One plate with its label outside the frame (UX-DR40): the
/// `photo-frame` widget above, the label below it in the support
/// role — the pair's only copy, never a caption on the image.
class _LabeledPlate extends StatelessWidget {
  const _LabeledPlate({required this.files, required this.name, this.label});

  final FilesPort files;
  final String name;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoFrame(files: files, name: name),
        if (label != null) ...[
          const SizedBox(height: Spacing.chipToTask),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
