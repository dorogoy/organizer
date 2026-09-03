import 'dart:typed_data';

import 'package:core/ports/slicer_port.dart';
import 'package:test/test.dart';

/// The Slicer port's vocabulary (Story 4-4, AD-9): exactly three
/// requests, exactly two outcomes, exactly seven causes — pinned by
/// exhaustiveness with no default arm, so a fourth request, a third
/// outcome or an eighth cause is a compile error here before it is
/// a review comment anywhere.
void main() {
  test('exactly three request kinds exist, mirroring the payloads 1:1', () {
    expect(_requestOf(ScanSliceRequest(imageBytes: kZero, prompt: '')), 1);
    expect(_requestOf(const GenesisSliceRequest(text: '')), 2);
    expect(
      _requestOf(const RescueSliceRequest(originContext: '', task: '')),
      3,
    );
  });

  test('a scan request carries its bytes and prompt verbatim', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final request = ScanSliceRequest(imageBytes: bytes, prompt: 'describe');
    expect(request.imageBytes, same(bytes));
    expect(request.prompt, 'describe');
  });

  test('a genesis request carries its text verbatim', () {
    const request = GenesisSliceRequest(text: 'un proyecto');
    expect(request.text, 'un proyecto');
  });

  test('a rescue request carries its origin context and task verbatim', () {
    const request = RescueSliceRequest(
      originContext: 'la estantería del salón',
      task: 'ordenar la estantería',
    );
    expect(request.originContext, 'la estantería del salón');
    expect(request.task, 'ordenar la estantería');
  });

  test('exactly two outcomes exist as types', () {
    expect(_outcomeOf(const SlicerDelivered('x')), 1);
    expect(_outcomeOf(const SlicerFailed(SlicerFailureCause.invalidKey)), 2);
  });

  test('a delivered outcome carries the response body verbatim', () {
    const outcome = SlicerDelivered('{"steps":[]}');
    expect(outcome.responseBody, '{"steps":[]}');
  });

  test('exactly seven causes exist, closed by the enum', () {
    expect(SlicerFailureCause.values, hasLength(7));
    expect(
      SlicerFailureCause.values,
      containsAll(const [
        SlicerFailureCause.credentialUnavailable,
        SlicerFailureCause.invalidKey,
        SlicerFailureCause.quotaExhausted,
        SlicerFailureCause.providerUnreachable,
        SlicerFailureCause.networkUnreachable,
        SlicerFailureCause.malformedResponse,
        SlicerFailureCause.managedUnavailable,
      ]),
    );
  });

  test('a failed outcome carries its cause verbatim', () {
    const outcome = SlicerFailed(SlicerFailureCause.quotaExhausted);
    expect(outcome.cause, SlicerFailureCause.quotaExhausted);
  });
}

final Uint8List kZero = Uint8List(0);

/// Exhaustive over [SlicerRequest] with no default arm: a fourth
/// subtype anywhere is a compile error here.
int _requestOf(SlicerRequest request) => switch (request) {
  ScanSliceRequest() => 1,
  GenesisSliceRequest() => 2,
  RescueSliceRequest() => 3,
};

/// Exhaustive over [SlicerOutcome] with no default arm: a third
/// outcome (a queued one, say) is a compile error here.
int _outcomeOf(SlicerOutcome outcome) => switch (outcome) {
  SlicerDelivered() => 1,
  SlicerFailed() => 2,
};
