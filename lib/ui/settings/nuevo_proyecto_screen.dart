// The intermediate surface behind `Nuevo proyecto` (Story 2.1, UX-DR25,
// epics.md:889): in 2.1 it is honestly empty — no heading, no chrome, no
// placeholder for Epic 5's typed genesis. Its one content is the quiet
// `Ajustes` way-out, bottom-centred in the same prose grammar the
// Dispenser's footer established; the system back gesture pops, and no
// other exit exists. Settings is reachable from inside this surface and
// nowhere else — the only route into the validator surface from any
// surface within three taps of the Dispenser (NFR3, AD-26).
import 'package:flutter/material.dart';

import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import 'settings_screen.dart';

class NuevoProyectoScreen extends StatelessWidget {
  const NuevoProyectoScreen({super.key, this.settings});

  /// The Settings seam handed down from the Dispenser — the same store
  /// instance, threaded through the whole way-out chain. Absent (the
  /// test seam), the way-out still opens the list with no controller
  /// behind it.
  final SettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No heading, no chrome: the standard surfaceBase frame, empty,
      // carrying the way-out alone — the build-order intermediate state
      // Epic 5 later completes with typed genesis as the recommended
      // action. The safe area is consumed once, by the footer band, the
      // dispenser footer's own pattern — the empty ground above it
      // needs no inset of its own.
      body: Column(
        children: [
          const Expanded(child: SizedBox.shrink()),
          SafeArea(
            top: false,
            child: SecondaryTextAction(
              label: AppStrings.of(context).settingsWayOut,
              onTap: () {
                // The same rapid-tap guard as the Dispenser footer: a
                // push while another route transitions in would stack a
                // second route.
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(controller: settings),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
