// The photo-frame widget (Story 7.1, FR-17, DESIGN.md
// {components.photo-frame}; UX-DR29): the app's first image surface —
// a 3:4 plate with a 1px hairline and a parametric corner (14 at full
// size, 4 at album-thumbnail size), rendering album bytes over the
// Files port's own read. The empty state is the whole quiet contract:
// while the bytes load, when the blob is absent, and when they fail
// to decode, the frame renders as an empty plate of the right shape
// on `surface-base` — no spinner, no shimmer, no gradient, never a
// pastel stand-in. Nothing here knows a caption or a pair: the label
// and the 16dp gap are the reward surface's own (7.1), and 7.2/7.3
// reuse this widget unchanged.
import 'dart:typed_data';

import 'package:core/ports/files_port.dart';
import 'package:flutter/material.dart';

import '../files/app_files.dart';
import 'tokens.dart';

/// One photo plate (UX-DR29): bytes read from the [albumFilesScope]
/// partition under [name], 3:4 whatever the width, [radius] corners,
/// a 1px hairline edge, `surface-base` inside while no image stands.
/// The read starts once, at mount; a name that changes re-reads. The
/// widget holds no other state and never writes.
class PhotoFrame extends StatefulWidget {
  const PhotoFrame({
    super.key,
    required this.files,
    required this.name,
    this.radius = Radii.radiusDefault,
  });

  /// The Files port the bytes read through — the same standing
  /// adapter the whole shell holds.
  final FilesPort files;

  /// The album blob's content-addressed name (AD-13).
  final String name;

  /// The corner radius — `Radii.radiusDefault` at full size,
  /// `Radii.radiusThumb` at album-thumbnail size.
  final double radius;

  @override
  State<PhotoFrame> createState() => _PhotoFrameState();
}

class _PhotoFrameState extends State<PhotoFrame> {
  /// The read bytes, or null while loading, absent or failed — the
  /// one state the empty plate and the image both read.
  List<int>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoFrame old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name || old.files != widget.files) {
      _load();
    }
  }

  Future<void> _load() async {
    // The generation guard: the read names the name it asked for — an
    // older read settling after a newer one (a name change raced the
    // Files port's latency) must not paint the previous blob under
    // the new name, and a widget that unmounted mid-read owns no
    // state at all.
    final name = widget.name;
    final files = widget.files;
    try {
      final bytes = await files.read(albumFilesScope, name);
      if (!mounted || widget.name != name) {
        return;
      }
      // Absence, refusal and every read failure fold into the same
      // quiet empty plate — the read is nullable by the port's own
      // contract, never an error surface here.
      setState(() => _bytes = bytes);
    } on Object {
      // A throwing Files port is the empty plate too — never an
      // unhandled async exception, never an error surface (UX-DR29).
      if (mounted && widget.name == name) {
        setState(() => _bytes = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _bytes;
    Widget content;
    if (bytes == null) {
      // The empty right-shape frame on `surface-base` (UX-DR29): the
      // shape holds whatever the bytes did or did not do — loading,
      // absent, undecodable — and no motion, fill or gradient stands
      // in for them.
      content = ColoredBox(color: theme.colorScheme.surface);
    } else {
      content = Image.memory(
        // `Image.memory` pins Uint8List; the copy is the decode
        // boundary's own requirement, once per read.
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        // Undecodable bytes are the empty plate, exactly the absent
        // blob's state — never a crash and never an error surface.
        errorBuilder: (context, error, stackTrace) =>
            ColoredBox(color: theme.colorScheme.surface),
      );
    }
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          // surfaceContainerHighest is the wired raised tone; outline
          // is the wired hairline (theme.dart) — tone and a 1px edge,
          // no shadow.
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outline, width: 1),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
