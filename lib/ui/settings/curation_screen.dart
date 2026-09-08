// The curation sub-screen (Story 5.11, FR-31, AD-16, UX-DR23): the
// `Contenido de la casa` group's one destination — a flat platform
// list of exactly eight rows, `anclas`, `sostén`, `z1`–`z5`, `fondo`,
// each a cluster name, its cadence as the only description (quiet
// support copy) and a platform switch whose whole band is the
// control. One flip appends exactly one `cluster_curation_changed`
// row and carries no confirmation, no count, no summary — the switch
// is the whole feedback (AD-21, FR-31). The rows never enumerate a
// task and never browse (NL-1): cluster level only, cadence only.
//
// [CurationRow] is public on purpose: Story 5.12's two other homes
// (the E1 template surface and onboarding's one-time strip) reuse it
// verbatim — one component, three homes.
import 'package:core/curation/curation.dart';
import 'package:flutter/material.dart';

import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The rendered name of a cluster (Story 5.11) — the one display-name
/// truth for the three authored names, the canonical zone names reused
/// verbatim for the five zones (`providerNameOf`'s total-map
/// precedent: an exhaustive switch, so a new cluster fails the build
/// here rather than rendering nothing).
String curationClusterLabelOf(AppStrings strings, CurationCluster cluster) =>
    switch (cluster) {
      CurationCluster.anclas => strings.curationClusterAnclas,
      CurationCluster.sosten => strings.curationClusterSosten,
      CurationCluster.z1 => strings.zoneZ1,
      CurationCluster.z2 => strings.zoneZ2,
      CurationCluster.z3 => strings.zoneZ3,
      CurationCluster.z4 => strings.zoneZ4,
      CurationCluster.z5 => strings.zoneZ5,
      CurationCluster.fondo => strings.curationClusterFondo,
    };

/// The row's only description — the cadence word (UX-DR23):
/// `diaria` for `anclas`/`sostén`, `semanal` for the five zones,
/// `mensual-estacional` for `fondo`. Never a count, never a volume,
/// never a task.
String curationCadenceLabelOf(AppStrings strings, CurationCluster cluster) =>
    switch (cluster) {
      CurationCluster.anclas ||
      CurationCluster.sosten => strings.curationCadenceDaily,
      CurationCluster.z1 ||
      CurationCluster.z2 ||
      CurationCluster.z3 ||
      CurationCluster.z4 ||
      CurationCluster.z5 => strings.curationCadenceWeekly,
      CurationCluster.fondo => strings.curationCadenceSeasonal,
    };

/// The curation sub-screen (Story 5.11, FR-31, AD-16): eight
/// [CurationRow]s in the cluster enum's own order — `anclas`,
/// `sostén`, `z1`–`z5`, `fondo` — under the group's own quiet header.
/// The camera row's lifecycle grammar throughout: a generation counter
/// so only the newest read may move the switches, quiet failures that
/// change nothing, the unread window rendering the all-active default
/// (no off-flash), and a pre-read tap that writes nothing.
class CurationScreen extends StatefulWidget {
  const CurationScreen({super.key, this.controller});

  /// The read/write seam over the same store the Dispenser holds.
  /// Absent (the test seam), the rows render on the all-active default
  /// and writes go nowhere.
  final SettingsController? controller;

  @override
  State<CurationScreen> createState() => _CurationScreenState();
}

class _CurationScreenState extends State<CurationScreen> {
  /// The derived active set, null until the first read resolves — no
  /// loader, no placeholder: the rows render on the all-active default
  /// and the switches land on the derivation's answer when the read
  /// commits.
  Set<CurationCluster>? _active;

  // Only the newest read may update the switches: an initial slow read
  // can otherwise complete after the post-write refresh and restore
  // old state (the camera row's own generation grammar).
  var _readGeneration = 0;

  @override
  void initState() {
    super.initState();
    _readCuration();
  }

  Future<void> _readCuration() async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final generation = ++_readGeneration;
    try {
      final active = await controller.readCurationState();
      if (mounted && generation == _readGeneration) {
        setState(() => _active = active);
      }
    } catch (_) {
      // A failed read leaves the switches exactly as they were — no
      // loader, no error state, nothing surfaced.
    }
  }

  /// One row's flip (Story 5.11, FR-31): exactly one
  /// `cluster_curation_changed` row, then a re-read — the switch's own
  /// landing is the whole feedback. A tap before the first read
  /// resolves is a retry of that read, never a write: the switch has
  /// no derived state to change yet, and the write would guess — and
  /// a first read that failed quietly gets its recovery here, on the
  /// user's own next tap, still writing nothing. A value equal to the
  /// derivation writes nothing. A failed write is quiet and changes
  /// nothing. And a second tap while a flip is still in flight is
  /// held off by the writing guard — the flight's own re-read is the
  /// only thing that may move the switch under it.
  var _writing = false;

  Future<void> _onClusterToggle(CurationCluster cluster, bool enabled) async {
    final controller = widget.controller;
    final active = _active;
    if (controller == null) {
      return;
    }
    if (active == null) {
      await _readCuration();
      return;
    }
    if (_writing) {
      return;
    }
    if (enabled == active.contains(cluster)) {
      return;
    }
    _writing = true;
    try {
      await controller.writeClusterCuration(cluster, enabled);
    } catch (_) {
      return;
    } finally {
      _writing = false;
    }
    await _readCuration();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final active = _active;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          children: [
            // The sub-screen's own header — the entry row's label
            // again, quiet support copy (the group headers' grammar).
            Text(
              strings.settingsCurationGroups,
              // bodySmall is the wired support role (theme.dart).
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.taskToActions),
            // Exactly the eight rows, the cluster enum's own order —
            // the unread window renders the all-active default, never
            // an off flash that would misstate the log (FR-31).
            for (final cluster in CurationCluster.values)
              CurationRow(
                cluster: cluster,
                value: active?.contains(cluster) ?? true,
                onChanged: (enabled) => _onClusterToggle(cluster, enabled),
              ),
          ],
        ),
      ),
    );
  }
}

/// One curation row (Story 5.11, FR-31, AD-16, UX-DR23): a quiet
/// platform switch row in the flat list's own grammar — the cluster
/// name in the action-secondary role with its cadence as the only
/// description in the support role beneath, the switch right, the
/// whole band a 48dp minimum target. The row is the camera row's
/// twin: the whole band tappable through one shared handler, merged
/// for readers as one button node with the switch's state as its
/// toggle state, and the bare platform `Switch` on theme defaults.
/// Public: Story 5.12's two other homes reuse it verbatim.
class CurationRow extends StatelessWidget {
  const CurationRow({
    super.key,
    required this.cluster,
    required this.value,
    this.onChanged,
  });

  final CurationCluster cluster;

  final bool value;

  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final label = curationClusterLabelOf(strings, cluster);
    // The whole row band is the control — the camera row's own
    // grammar, merged for readers into ONE node: the cluster name and
    // the cadence both speak (the label derives from the merged child
    // Texts — accessor concatenation is banned by the string-table
    // law, so the cadence reaches the spoken label by being a child
    // text of the merged node, never by interpolation), the node
    // carries the button flag, and the switch contributes its own
    // toggled state to the same node. The platform switch keeps its
    // own thumb inside the merged node, so the visual control and the
    // spoken one are the same thing.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          // Absent, the tap stays an accepted no-op — a null onChanged
          // would render a disabled control instead (the row's band and
          // the switch share this one handler).
          onTap: onChanged == null ? () {} : () => onChanged!(!value),
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Spacing.spacingBase,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          // bodyMedium is the wired action-secondary
                          // role (theme.dart) — the row reads as quiet
                          // prose, the settings list's own grammar.
                          style: theme.textTheme.bodyMedium,
                        ),
                        // The cadence — the row's only description, in
                        // the support role (UX-DR23): no count, no
                        // volume, no task ever rides the row.
                        Text(
                          curationCadenceLabelOf(strings, cluster),
                          // bodySmall is the wired support role
                          // (theme.dart).
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    // The same one handler the band carries — the two
                    // controls are one.
                    onChanged: onChanged ?? (_) {},
                    value: value,
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
