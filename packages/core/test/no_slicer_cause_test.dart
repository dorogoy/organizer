import 'package:core/ports/no_slicer_cause.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:test/test.dart';

/// The no-Slicer cause vocabulary (Story 4-5, FR-29): exactly seven
/// members, and the total map from the port's seven failure causes —
/// pinned row by row, exhaustive with no default arm, so an eighth
/// cause on either side is a compile error here before it is a review
/// comment anywhere. The two pre-request refusals have no
/// failure-cause origin: the map's image is exactly the five causes a
/// request can produce.
void main() {
  test('exactly seven causes exist, closed by the enum', () {
    expect(NoSlicerCause.values, hasLength(7));
    expect(
      NoSlicerCause.values,
      containsAll(const [
        NoSlicerCause.noKey,
        NoSlicerCause.invalidKey,
        NoSlicerCause.quotaExhausted,
        NoSlicerCause.unreachable,
        NoSlicerCause.offline,
        NoSlicerCause.consentDeclined,
        NoSlicerCause.personInFrame,
      ]),
    );
  });

  test('every failure cause maps to its recorded row — the total map', () {
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.credentialUnavailable),
      NoSlicerCause.noKey,
    );
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.invalidKey),
      NoSlicerCause.invalidKey,
    );
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.quotaExhausted),
      NoSlicerCause.quotaExhausted,
    );
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.providerUnreachable),
      NoSlicerCause.unreachable,
    );
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.networkUnreachable),
      NoSlicerCause.offline,
    );
    // The recorded fold (epics.md:1988): a body that yields no slice
    // text surfaces under the provider-unresponsive string.
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.malformedResponse),
      NoSlicerCause.unreachable,
    );
    // The config-family fold (slicer_port.dart's own doc): Managed is
    // inert, nothing was sent, and the no-key remedy is the true one.
    expect(
      noSlicerCauseFromFailure(SlicerFailureCause.managedUnavailable),
      NoSlicerCause.noKey,
    );
  });

  test('consent declined and person in frame have no failure origin', () {
    // The map is exhaustive over the closed failure taxonomy (the
    // switch above carries no default arm), so asserting the image
    // over every member is asserting it over every failure that can
    // ever exist: neither pre-request refusal is reachable from a
    // failure cause — they arrive only from Epic 5's callers.
    final image = {
      for (final failure in SlicerFailureCause.values)
        noSlicerCauseFromFailure(failure),
    };
    expect(image, isNot(contains(NoSlicerCause.consentDeclined)));
    expect(image, isNot(contains(NoSlicerCause.personInFrame)));
    expect(image, hasLength(5));
    expect(
      image,
      containsAll(const [
        NoSlicerCause.noKey,
        NoSlicerCause.invalidKey,
        NoSlicerCause.quotaExhausted,
        NoSlicerCause.unreachable,
        NoSlicerCause.offline,
      ]),
    );
  });
}
