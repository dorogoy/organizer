import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:organizer/egress/image_cap.dart';

import 'egress_fixtures.dart';

void main() {
  test('the decided cap, quality and ceiling are pinned', () {
    expect(egressImageCap, 1536);
    expect(egressJpegQuality, 85);
    expect(egressDimensionCeiling, 20000);
  });

  test('a JPEG within the cap is returned unchanged in value', () async {
    final bytes = gradientJpeg(320, 240);
    final out = await prepareImageForEgress(bytes);
    expect(out, equals(bytes));
  });

  test('a PNG within the cap is returned unchanged in value', () async {
    final bytes = gradientPng(200, 100);
    final out = await prepareImageForEgress(bytes);
    expect(out, equals(bytes));
  });

  test(
    'an oversized landscape JPEG is downscaled to the cap, JPEG out',
    () async {
      final bytes = gradientJpeg(2000, 1500);
      final out = await prepareImageForEgress(bytes);
      final image = decodeOrThrow(out);
      expect(image.width, 1536);
      expect(image.height, 1152);
      expect(formatOf(out), img.ImageFormat.jpg);
    },
  );

  test(
    'an oversized portrait JPEG is downscaled to the cap, JPEG out',
    () async {
      final bytes = gradientJpeg(1500, 2000);
      final out = await prepareImageForEgress(bytes);
      final image = decodeOrThrow(out);
      expect(image.width, 1152);
      expect(image.height, 1536);
      expect(formatOf(out), img.ImageFormat.jpg);
    },
  );

  test('an oversized PNG is downscaled to the cap, PNG out', () async {
    final bytes = gradientPng(2000, 1000);
    final out = await prepareImageForEgress(bytes);
    final image = decodeOrThrow(out);
    expect(image.width, 1536);
    expect(image.height, 768);
    expect(formatOf(out), img.ImageFormat.png);
  });

  test('aspect ratio survives the downscale (either orientation)', () async {
    final landscape = decodeOrThrow(
      await prepareImageForEgress(gradientJpeg(2000, 1250)),
    );
    expect(landscape.width / landscape.height, closeTo(1.6, 0.01));
    final portrait = decodeOrThrow(
      await prepareImageForEgress(gradientJpeg(1250, 2000)),
    );
    expect(portrait.width / portrait.height, closeTo(0.625, 0.01));
  });

  test('EXIF orientation is baked before the resize — a rotated frame '
      'reaches the model upright, tag gone', () async {
    // A 2000×1000 raster tagged orientation 6 displays as 1000×2000
    // portrait; the bake must compute the target size on the oriented
    // raster (768×1536), not the raw one.
    final bytes = rotatedJpeg(2000, 1000, 6);
    final out = await prepareImageForEgress(bytes);
    final image = decodeOrThrow(out);
    expect(image.width, 768);
    expect(image.height, 1536);
    expect(
      image.exif.imageIfd.hasOrientation &&
          image.exif.imageIfd.orientation != 1,
      isFalse,
      reason:
          'the re-encode must not leave a stale orientation tag on '
          'already-baked pixels',
    );
  });

  test(
    'a within-cap rotated frame passes through untouched, tag intact',
    () async {
      final bytes = rotatedJpeg(1000, 800, 8);
      final out = await prepareImageForEgress(bytes);
      expect(
        out,
        equals(bytes),
        reason:
            'pass-through keeps the original '
            'bytes verbatim — the orientation tag travels with them',
      );
    },
  );

  test(
    'a GIF becomes JPEG q85 through the cap (third-format policy)',
    () async {
      final bytes = gradientGif(2000, 1000);
      final out = await prepareImageForEgress(bytes);
      final image = decodeOrThrow(out);
      expect(image.width, 1536);
      expect(image.height, 768);
      expect(formatOf(out), img.ImageFormat.jpg);
    },
  );

  test('a within-cap GIF passes through untouched (no gratuitous '
      're-encode)', () async {
    final bytes = gradientGif(800, 600);
    final out = await prepareImageForEgress(bytes);
    expect(out, equals(bytes));
  });

  test('undecodable bytes throw, never reject', () {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(prepareImageForEgress(garbage), throwsA(isA<FormatException>()));
  });

  test('a header claiming impossible dimensions is undecodable, not an '
      'OOM attempt', () async {
    // The pixel payload is tiny, but the header claims 24000 px wide —
    // the probe rejects before any decode allocation.
    final bytes = _fakeWideJpegHeader();
    expect(prepareImageForEgress(bytes), throwsA(isA<FormatException>()));
  });
}

/// Builds bytes whose JPEG header declares a 24000×100 SOF frame —
/// large enough to trip the ceiling, small enough to build cheaply.
Uint8List _fakeWideJpegHeader() {
  // Minimal JPEG: SOI, APP0(JFIF), SOF0 with the lying dimensions, and
  // a truncated tail (the probe never reaches pixels).
  final out = BytesBuilder();
  out.add([0xFF, 0xD8]); // SOI
  out.add([0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00]); // APP0
  out.add([0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
  // SOF0: length 17, precision 8, height 100, width 24000 (0x5DC0).
  out.add([0xFF, 0xC0, 0x00, 0x11, 0x08]);
  out.add([0x00, 100 >> 8, 100 & 0xFF]);
  out.add([(24000 >> 8) & 0xFF, 24000 & 0xFF]);
  out.add([0x03]); // 3 components, then a plausible truncated tail
  out.add([0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01]);
  out.add([0xFF, 0xD9]); // EOI
  return out.toBytes();
}
