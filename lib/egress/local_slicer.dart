// The Local Slicer (Story 4-4, AD-9; the canned body renegotiated
// Story 5.7, both flights branched in 5.7's review): the port's
// second shape — a canned-slice stub, output recognisable as canned
// by an unmistakable marker, exercising the port's swappability
// rather than asserting it. Reachable only through the factory's
// compile-time gate (`ORGANIZER_LOCAL_SLICER` unset-and-release
// folds false); the class itself is inert data plumbing. The Local
// path died in story 4-1's harness — this shape exists so the
// port's contract stays exercised, never to serve a real slice.
//
// The canned body answers each flight in its OWN contract, branched
// on the port's typed request shape (never string sniffing): a
// `ScanSliceRequest` or a `GenesisSliceRequest` gets the scan body
// (description + `duration_minutes` — the two flights this stub
// can drive on a device, Stories 5.7 and 5.8, whose prompts both
// pin the scan JSON contract), a `RescueSliceRequest` the rescue
// body (steps + `duration_seconds` 1–60, the pre-5.7 values — a
// scan-shaped answer would break the rescue flight by construction,
// `parseRescueSteps` rejecting it every time). Both bodies' field
// names are core's own wire names (`scan_steps.dart`,
// `rescue_steps.dart` — the parses the landings read), so the stub
// cannot drift from
// the wire's contract; the parity — prompt field names ↔ parses ↔
// these bodies — is pinned from the test side.
import 'dart:convert';

import 'package:core/ports/slicer_port.dart';
import 'package:core/slicer/rescue_steps.dart';
import 'package:core/slicer/scan_steps.dart';

import 'byok_slicer.dart';
import 'managed_slicer.dart';

/// The canned body's step count — two, inside BOTH contracts' bands
/// (scan 1–6, rescue 2–4), so the stub's output is shape-plausible
/// while its text announces itself.
const int cannedSliceStepCount = 2;

/// The canned scan body's first step's duration, in minutes — inside
/// the scan contract's 3–5 band.
const int cannedSliceFirstStepMinutes = 3;

/// The canned scan body's later steps' duration, in minutes.
const int cannedSliceLaterStepMinutes = 5;

/// The canned rescue body's first step's duration, in seconds — the
/// pre-5.7 stub's own value, inside the rescue contract's 1–60 band.
const int cannedRescueFirstStepSeconds = 30;

/// The canned rescue body's later steps' duration, in seconds — the
/// pre-5.7 stub's own value.
const int cannedRescueLaterStepSeconds = 45;

final class LocalSlicer implements SlicerPort {
  const LocalSlicer({required this.cannedMarker});

  /// The unmistakable marker the canned description and every canned
  /// step carry — the ARB's one canned-register string, handed in at
  /// wiring so the string table owns the copy (AD-15).
  final String cannedMarker;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async => SlicerDelivered(
    request is ScanSliceRequest || request is GenesisSliceRequest
        ? _scanCannedBody()
        : _rescueCannedBody(),
  );

  /// No HTTP stands behind Local — abandonment has nothing to cancel.
  void abortInFlight() {}

  /// The canned scan body: a JSON object shaped like a scan answer —
  /// the scan parse's own field names — whose description and every
  /// step is the marker. No request's facts enter it: that is what
  /// makes it recognisably canned.
  String _scanCannedBody() {
    return jsonEncode(<String, Object?>{
      scanWireDescriptionField: cannedMarker,
      scanWireStepsField: <Map<String, Object?>>[
        for (var index = 0; index < cannedSliceStepCount; index++)
          <String, Object?>{
            scanWireTextField: cannedMarker,
            scanWireDurationField: index == 0
                ? cannedSliceFirstStepMinutes
                : cannedSliceLaterStepMinutes,
          },
      ],
    });
  }

  /// The canned rescue body: a JSON object shaped like a rescue
  /// answer — the rescue parse's own field names, the pre-5.7
  /// durations — whose every step is the marker. The rescue flight
  /// parses it or nothing: this stub never answers one flight in the
  /// other's dialect.
  String _rescueCannedBody() {
    return jsonEncode(<String, Object?>{
      rescueWireStepsField: <Map<String, Object?>>[
        for (var index = 0; index < cannedSliceStepCount; index++)
          <String, Object?>{
            rescueWireTextField: cannedMarker,
            rescueWireDurationField: index == 0
                ? cannedRescueFirstStepSeconds
                : cannedRescueLaterStepSeconds,
          },
      ],
    });
  }
}

/// Completes a standing BYOK send's abort trigger. Local and Managed
/// have no HTTP to cancel — [LocalSlicer.abortInFlight] /
/// [ManagedSlicer.abortInFlight] are no-ops — and test fakes fall
/// through the same way.
void abortSlicerInFlight(SlicerPort? slicer) {
  switch (slicer) {
    case ByokSlicer byok:
      byok.abortInFlight();
    case LocalSlicer local:
      local.abortInFlight();
    case ManagedSlicer managed:
      managed.abortInFlight();
    case _:
      break;
  }
}
