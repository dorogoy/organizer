import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:organizer/egress/egress_dispatch.dart';
import 'package:organizer/egress/egress_payload.dart';

import 'egress_fixtures.dart';

/// Matrix rows 1–3 of the story's I/O table, plus the union
/// exhaustiveness guarantees (a fourth payload or a third outcome does
/// not compile — the switches below carry no default arm, so the
/// analyzer breaks the build the moment one appears).
void main() {
  test('row 1: a scan payload within the cap reaches the transport once, '
      'bytes unchanged', () async {
    final bytes = gradientJpeg(640, 480);
    final payload = ScanImagePrompt(imageBytes: bytes, prompt: 'describe');
    var calls = 0;
    Object? received;
    final dispatch = EgressDispatch((payload) async {
      calls++;
      received = payload;
      return 'sliced';
    });
    final result = await dispatch.send(payload);
    expect(calls, 1);
    expect(result, isA<EgressDelivered>());
    expect((result as EgressDelivered).responseBody, 'sliced');
    final sent = received as ScanImagePrompt;
    expect(sent.prompt, 'describe');
    expect(
      sent.imageBytes,
      equals(bytes),
      reason: 'an in-cap scan payload is never re-encoded',
    );
  });

  test('row 2: an oversized landscape JPEG is capped before the transport, '
      'either orientation', () async {
    final result = await _sendOverJpg(2000, 1500);
    expect(result.image.width, 1536);
    expect(result.image.height, 1152);
    expect(result.format, img.ImageFormat.jpg);
  });

  test(
    'row 2: an oversized portrait JPEG is capped before the transport',
    () async {
      final result = await _sendOverJpg(1500, 2000);
      expect(result.image.width, 1152);
      expect(result.image.height, 1536);
      expect(result.format, img.ImageFormat.jpg);
    },
  );

  test('row 2: an oversized PNG stays PNG through the cap', () async {
    var received = <String, Object?>{};
    final dispatch = EgressDispatch((payload) async {
      received['payload'] = payload;
      return 'ok';
    });
    final result = await dispatch.send(
      ScanImagePrompt(imageBytes: gradientPng(2000, 1000), prompt: 'describe'),
    );
    expect(result, isA<EgressDelivered>());
    final out = (received['payload'] as ScanImagePrompt).imageBytes;
    final decoder = img.findDecoderForData(out);
    expect(decoder, isNotNull);
    expect(decoder!.format, img.ImageFormat.png);
    expect(img.decodeImage(out)!.width, 1536);
  });

  test('row 3: a transport that throws fails terminally, exactly one '
      'attempt, and the stack trace travels with the cause', () async {
    final cause = StateError('unreachable');
    var calls = 0;
    final dispatch = EgressDispatch((payload) async {
      calls++;
      throw cause;
    });
    final result = await dispatch.send(ProjectGenesisText(text: 'a project'));
    expect(calls, 1, reason: 'no retry exists anywhere in the module');
    expect(result, isA<EgressFailed>());
    final failure = result as EgressFailed;
    expect(identical(failure.cause, cause), isTrue);
    expect(
      failure.stack,
      isNotNull,
      reason: '4-5\'s diagnosis surface keeps the stack',
    );
    expect(failure.stack.toString(), contains('asynchronous'));
  });

  test('row 3: a second send after a failure is a fresh call — nothing '
      'retained, nothing replayed', () async {
    var calls = 0;
    var healthy = false;
    final dispatch = EgressDispatch((payload) async {
      calls++;
      if (!healthy) {
        throw StateError('first attempt offline');
      }
      return 'recovered';
    });
    final first = await dispatch.send(ProjectGenesisText(text: 'a project'));
    expect(first, isA<EgressFailed>());
    healthy = true;
    final second = await dispatch.send(ProjectGenesisText(text: 'a project'));
    expect(second, isA<EgressDelivered>());
    expect((second as EgressDelivered).responseBody, 'recovered');
    expect(calls, 2, reason: 'one invocation per send, never a queued replay');
  });

  test('undecodable scan bytes fail before the transport is touched', () async {
    var calls = 0;
    final dispatch = EgressDispatch((payload) async {
      calls++;
      return 'never';
    });
    final result = await dispatch.send(
      ScanImagePrompt(
        imageBytes: Uint8List.fromList([9, 9, 9]),
        prompt: 'describe',
      ),
    );
    expect(calls, 0);
    expect(result, isA<EgressFailed>());
    expect((result as EgressFailed).cause, isA<FormatException>());
  });

  test(
    'text payloads ride the seam unchanged — the cap is scan-shaped only',
    () async {
      final genesis = ProjectGenesisText(text: 'a project');
      final rescue = RescueResliceText(
        originContext: 'shelf',
        task: 'clear it',
      );
      final seen = <EgressPayload>[];
      final dispatch = EgressDispatch((payload) async {
        seen.add(payload);
        return 'ok';
      });
      await dispatch.send(genesis);
      await dispatch.send(rescue);
      expect(seen, hasLength(2));
      expect(identical(seen[0], genesis), isTrue);
      expect(identical(seen[1], rescue), isTrue);
    },
  );

  test('exactly three payload shapes and two outcomes exist as types', () {
    expect(_shapeOf(ScanImagePrompt(imageBytes: kZero, prompt: '')), 1);
    expect(_shapeOf(const ProjectGenesisText(text: '')), 2);
    expect(_shapeOf(const RescueResliceText(originContext: '', task: '')), 3);
    expect(_outcomeOf(const EgressDelivered('x')), 1);
    expect(_outcomeOf(EgressFailed(_ZeroCause())), 2);
  });
}

final Uint8List kZero = Uint8List(0);

class _ZeroCause implements Exception {}

/// Exhaustive over [EgressPayload] with no default arm: a fourth subtype
/// anywhere is a compile error here (AD-7's "no fourth exists as a
/// type", by construction).
int _shapeOf(EgressPayload payload) => switch (payload) {
  ScanImagePrompt() => 1,
  ProjectGenesisText() => 2,
  RescueResliceText() => 3,
};

/// Exhaustive over [EgressResult] with no default arm: a third outcome
/// (a queued one, say) is a compile error here.
int _outcomeOf(EgressResult result) => switch (result) {
  EgressDelivered() => 1,
  EgressFailed() => 2,
};

Future<({img.Image image, img.ImageFormat format})> _sendOverJpg(
  int width,
  int height,
) async {
  var received = <String, Object?>{};
  final dispatch = EgressDispatch((payload) async {
    received['payload'] = payload;
    return 'ok';
  });
  final result = await dispatch.send(
    ScanImagePrompt(imageBytes: gradientJpeg(width, height), prompt: 'scan'),
  );
  expect(result, isA<EgressDelivered>());
  final out = (received['payload'] as ScanImagePrompt).imageBytes;
  final decoder = img.findDecoderForData(out);
  expect(decoder, isNotNull);
  return (image: decodeOrThrow(out), format: decoder!.format);
}
