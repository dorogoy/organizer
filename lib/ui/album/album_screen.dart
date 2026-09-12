// The contextual gallery (Story 7.3, FR-18): the album's one surface —
// a column of Before/After thumbnail pairs, newest first, with a
// one-tap delete per entry and a one-tap purge for the whole album,
// both invoking 7.2's controller verbatim. Reached ONLY from the
// reward's pair-landed arm through `Ver el álbum` (UX-DR31/32):
// contextual navigation at the transformation-completed moment,
// never a permanent destination, never a nav bar entry.
//
// The skeleton mirrors the reward screen's register —
// Scaffold→SafeArea→scroll→maxWidth 480 + screenMargin — so the 200%
// floor holds by scrolling (UX-DR45). Every entry renders the pair's
// own vocabulary and nothing else: two `PhotoFrame`s at
// `Radii.radiusThumb` with the labels `Antes`/`Después` outside the
// frames, no caption, no date, no count (UX-DR40; AD-26 — the gallery
// shows no number of any kind). No AppBar: close is the shared
// `Cerrar` secondary, and the system back gesture is the OS pop.
//
// The album has NO empty state (UX-DR51): an empty read pops the
// surface. One code path covers everything — read, render-or-pop —
// so a mutation (delete, purge) is always followed by a fresh read:
// the log is the only truth (AD-13), and an idempotent double-tap
// folds to the same answer. A read failure leaves the quiet pending
// plate standing — never an empty-album reading, never a pop — and
// `Cerrar` works through it. A mutation failure is caught and the
// same fresh read runs: the surface shows the log's truth, no error
// chrome, no success toast (offline is never an error; the visible
// state is the real state).
import 'package:core/derive/album.dart';
import 'package:core/ports/files_port.dart';
import 'package:flutter/material.dart';

import '../../album/album_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import '../photo_frame.dart';
import '../tokens.dart';

/// The contextual gallery (FR-18). [album] is the 7.2 controller the
/// reward's pair-landed arm threads — same store, same Files root, the
/// same seam main composes. Absent (the test seam), the read answers
/// empty and the surface pops: nothing half-wired renders.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, this.album});

  final AlbumController? album;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  /// The read's live entries, null until they resolve — the quiet
  /// pending plate, never a loader. An empty answer never lands here:
  /// it pops the screen instead (UX-DR51, no empty state).
  List<AlbumEntry>? _entries;

  /// The generation guard: a read settling after a newer one (a
  /// delete's refresh racing the opening read) must not overwrite it.
  int _readGeneration = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  /// The one commit path (FR-18, AD-13): read, then render or pop. An
  /// empty read pops — no empty state, no copy (UX-DR51) — and a read
  /// failure leaves the quiet pending plate standing, never an
  /// empty-album reading.
  Future<void> _read() async {
    final generation = ++_readGeneration;
    final controller = widget.album;
    try {
      // The seam's empty answer rides the same await as a real read:
      // the commit path (the pop included) must never run synchronously
      // inside initState — `ModalRoute.of` and `Navigator.of` are
      // frame-scoped, and a synchronous pop would die in the catch.
      final entries = controller == null
          ? await Future<List<AlbumEntry>>.value(const [])
          : await controller.read();
      if (!mounted || generation != _readGeneration) {
        return;
      }
      if (entries.isEmpty) {
        // The pop sits behind the same isCurrent guard every push and
        // pop in this flow owns: a route already exiting — the back
        // gesture, `Cerrar`, a first purge's pop with a second read
        // still racing — must not pop again and discard the reward
        // screen beneath the gallery.
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() => _entries = entries);
    } on Object {
      // The read failed: the quiet pending plate stands, `Cerrar`
      // works, and nothing reads as an empty album. Retry is
      // re-entering the surface — close, come back from the reward —
      // and the plate stands until then; never an error surface.
    }
  }

  /// One entry's delete (FR-18, AD-13): one tap, no confirmation —
  /// 7.2's single deletion operation (`album_entry_deleted` plus the
  /// unlink), then the fresh read. A failure is caught and the read
  /// runs anyway: the log's truth shows (the row never landed, so the
  /// entry stands — the honest answer, never an error surface).
  /// Idempotent by construction: a second tap folds to the same read.
  Future<void> _delete(AlbumEntry entry) async {
    final controller = widget.album;
    if (controller == null) {
      return;
    }
    try {
      await controller.deleteEntry(entry);
    } on Object {
      // Caught: the same fresh read below renders the log's truth.
    }
    await _read();
  }

  /// The whole album's purge (FR-18): one tap, no confirmation — 7.2's
  /// sweep plus the `album_purged` row, then the fresh read, which
  /// finds nothing and pops the screen. A failure is caught and the
  /// read runs anyway, exactly the delete's own terms.
  Future<void> _purge() async {
    final controller = widget.album;
    if (controller == null) {
      return;
    }
    try {
      await controller.purge();
    } on Object {
      // Caught: the same fresh read below renders the log's truth.
    }
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final controller = widget.album;
    final entries = _entries;
    return Scaffold(
      // The reward surface's own frame, centered — SafeArea first,
      // screen margins on the sides, the 200% floor holding through
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
                  // The gallery's one title — a noun, never a count
                  // (AD-26). headlineSmall is the wired screenHeading
                  // role (theme.dart).
                  Text(
                    strings.albumTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Spacing.taskToActions),
                  if (controller == null || entries == null) ...[
                    // The read's quiet pending state (UX-DR29): the
                    // empty right-shape plate on `surface-base` while
                    // the facts resolve, or standing after a read
                    // failure. No spinner, no shimmer, no gradient.
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                    const SizedBox(height: Spacing.actionGap),
                  ] else ...[
                    // Newest first — the reverse of the fold's log
                    // order — each pair with its one-tap delete, and
                    // nothing else per entry (UX-DR40; AD-26).
                    for (final entry in entries.reversed) ...[
                      _AlbumEntryView(
                        files: controller.files,
                        entry: entry,
                        onDelete: () => _delete(entry),
                      ),
                      const SizedBox(height: Spacing.taskToActions),
                    ],
                    // The whole album's one-tap purge (FR-18) — quiet
                    // prose, no confirmation, no count of what goes.
                    SecondaryTextAction(
                      label: strings.albumPurge,
                      onTap: _purge,
                    ),
                    // The deliberate air between the purge and the
                    // close: a slip targeting `Cerrar` must not land
                    // on the irreversible whole-album act — the
                    // largest interior gap the register owns, the
                    // pause between reading and committing.
                    const SizedBox(height: Spacing.taskToActions),
                  ],
                  // The shared close — never a *seguir* variant, and
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

/// One gallery entry (FR-18, UX-DR40): two `PhotoFrame`s at
/// `Radii.radiusThumb` — a cut edge, not a small card — the labels
/// `Antes`/`Después` outside the frames, and the one-tap `Borrar`
/// under the pair. No caption, no date, no count.
class _AlbumEntryView extends StatelessWidget {
  const _AlbumEntryView({
    required this.files,
    required this.entry,
    required this.onDelete,
  });

  final FilesPort files;
  final AlbumEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledThumb(
                files: files,
                name: entry.beforeName,
                label: strings.rewardLabelBefore,
              ),
            ),
            const SizedBox(width: Spacing.photoPairGap),
            Expanded(
              child: _LabeledThumb(
                files: files,
                name: entry.afterName,
                label: strings.rewardLabelAfter,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.actionGap),
        SecondaryTextAction(label: strings.albumEntryDelete, onTap: onDelete),
      ],
    );
  }
}

/// One thumb with its label outside the frame — the reward's
/// `_LabeledPlate` grammar at the thumbnail's own radius.
class _LabeledThumb extends StatelessWidget {
  const _LabeledThumb({
    required this.files,
    required this.name,
    required this.label,
  });

  final FilesPort files;
  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoFrame(files: files, name: name, radius: Radii.radiusThumb),
        const SizedBox(height: Spacing.chipToTask),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
