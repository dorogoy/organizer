// The Local Slicer (Story 4-4, AD-9): the port's second shape — a
// canned-slice stub, output recognisable as canned by an
// unmistakable marker, exercising the port's swappability rather
// than asserting it. Reachable only through the factory's
// compile-time gate (`ORGANIZER_LOCAL_SLICER` unset-and-release
// folds false); the class itself is inert data plumbing. The
// Local path died in story 4-1's harness — this shape exists so the
// port's contract stays exercised, never to serve a real slice.
//
// The canned body's field names are derived from the canonical
// rescue schema (rescue_contract.dart's single source), so the stub
// cannot drift from the wire's contract.
import 'dart:convert';

import 'package:core/ports/slicer_port.dart';

import 'rescue_contract.dart';

/// The canned body's step count — two, inside the rescue contract's
/// 2–4 band, so the stub's output is shape-plausible while its text
/// announces itself.
const int cannedSliceStepCount = 2;

/// The canned body's first step's duration, in seconds.
const int cannedSliceFirstStepSeconds = 30;

/// The canned body's later steps' duration, in seconds.
const int cannedSliceLaterStepSeconds = 45;

final class LocalSlicer implements SlicerPort {
  const LocalSlicer({required this.cannedMarker});

  /// The unmistakable marker every canned step carries — the ARB's
  /// one canned-register string, handed in at wiring so the string
  /// table owns the copy (AD-15).
  final String cannedMarker;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async =>
      SlicerDelivered(_cannedBody());

  /// The canned body: a JSON object shaped like a rescue answer —
  /// the canonical schema's own field names, parsed — whose every
  /// step is the marker. No request's facts enter it: that is what
  /// makes it recognisably canned.
  String _cannedBody() {
    final names = rescueSchemaFieldNames();
    return jsonEncode(<String, Object?>{
      names.steps: <Map<String, Object?>>[
        for (var index = 0; index < cannedSliceStepCount; index++)
          <String, Object?>{
            names.text: cannedMarker,
            names.durationSeconds: index == 0
                ? cannedSliceFirstStepSeconds
                : cannedSliceLaterStepSeconds,
          },
      ],
    });
  }
}
