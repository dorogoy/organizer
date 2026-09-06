import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:organizer/egress/image_cap.dart';

import 'egress_fixtures.dart';

void main() {
  test('the decided cap, quality and pixel ceiling are pinned', () {
    expect(egressImageCap, 1536);
    expect(egressJpegQuality, 85);
    expect(egressPixelCeiling, 12_500_000);
  });

  test('a panoramic frame resizes inside the recorded resize bound — '
      'both edges land under the cap', () async {
    // image_cap.dart's arithmetic (review round 1): the long edge
    // always lands on 1536, so the resize target is bounded by
    // ≈ 1536×1536 ≈ 2.36 MP ≈ 7.1–9.4 MB — a 1536×2048 target never
    // occurs. This 4000×1000 (4 MP) panorama takes the long-edge math
    // to a 4:1 extreme and lands at 1536×384, inside the bound.
    final out = await prepareImageForEgress(gradientJpeg(4000, 1000));
    final image = decodeOrThrow(out);
    expect(image.width, 1536);
    expect(image.height, 384);
    expect(image.width * image.height, 589_824);
  });

  test('the canonical 12 MP sensor capture survives the cap — the '
      'camera class passes', () async {
    // 4032×3024 = 12,192,768 px — the class the ruled 12,500,000
    // exists to admit (a literal 12,000,000 rejected it). The resize
    // lands at 1536×1152, both edges on the cap's terms. Encoding a
    // 12 MP raster in-test costs a few seconds; that is the price of
    // pinning the real camera class rather than a stand-in.
    final bytes = gradientJpeg(4032, 3024);
    final out = await prepareImageForEgress(bytes);
    final image = decodeOrThrow(out);
    expect(image.width, 1536);
    expect(image.height, 1152);
    expect(formatOf(out), img.ImageFormat.jpg);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the ruled band bites: a 12,582,912 px capture is refused — the '
      'pin that discriminates 12.5 MP from a reverted 16 MP', () async {
    // 4096×3072 = 12,582,912 px — inside the old 16 MP ceiling, over
    // the ruled 12,500,000. Under a guard reverted to 16 MP this real
    // fixture would decode and resize successfully, so this pin makes
    // the band's closure behavioral: a guard-only revert ships red.
    // Header-only fixtures cannot discriminate — both ceilings throw
    // the same type; the fixture must be real, and so the encoding
    // costs a few seconds.
    final bytes = gradientJpeg(4096, 3072);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

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

  test(
    'a valid panoramic image over the old edge limit is still downscaled',
    () async {
      final out = await prepareImageForEgress(gradientJpeg(24000, 100));
      final image = decodeOrThrow(out);
      expect(image.width, 1536);
      expect(image.height, 6);
    },
  );

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

  test('an oversized GIF is refused pre-transport — the sniff gates before '
      'any decode, whatever the size', () async {
    final bytes = gradientGif(2000, 1000);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('a within-cap GIF is refused too — size does not soften the admit '
      'set (the old pass-through hole, sealed)', () async {
    final bytes = gradientGif(800, 600);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('a decodable sub-cap WebP is refused before any decode', () async {
    final bytes = gradientWebP(320, 240);
    // The bytes are a genuine WebP the codec could read — the refusal
    // is the sniff's, about the wire's declarable types.
    expect(decodeOrThrow(bytes).width, 320);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('a decodable sub-cap BMP is refused before any decode', () async {
    final bytes = gradientBmp(320, 240);
    expect(decodeOrThrow(bytes).width, 320);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('undecodable bytes are malformed input — one rejection for every '
      'non-admitted input', () async {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);
    await expectLater(
      prepareImageForEgress(garbage),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('JPEG magic with a corrupt body is malformed input too — the '
      'sniff admits, the probe refuses', () async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0x12, 0x34]);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('PNG magic with a corrupt body is malformed input — the PNG leg '
      'of the corrupt-body row', () async {
    final bytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x12, 0x34, 0x56,
    ]);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('an oversized header whose body will not decode is malformed '
      'input — the decode-path refusal site', () async {
    // 2000×1000: long edge over the cap, product under the ceiling,
    // IHDR parses, no IDAT. Restoring FormatException at
    // `_decodeFirstFrame` would still pass every other MalformedImageInput
    // pin; this one would go red.
    final bytes = pngHeaderWithDimensions(2000, 1000);
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('JPEG magic that the JPEG codec refuses is malformed input — '
      'no other decoder may claim it', () async {
    // 32 bytes starting FF D8, with TGA's pixel-depth slot (offset 16)
    // set to 24 so `findDecoderForData` could have handed the body to
    // TGA after JpegDecoder.isValidFile failed. The probe now uses
    // JpegDecoder only.
    final bytes = Uint8List(32);
    bytes[0] = 0xFF;
    bytes[1] = 0xD8;
    bytes[16] = 24;
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('a crafted uint32 PNG header is refused by the per-dimension '
      'bound — the product is never taken on a uint32-max lie', () async {
    // The control proves the builder produces a PNG the decoder's
    // header parse accepts (startDecode reads its IHDR — CRC valid,
    // IEND terminates): with sane dimensions it parses cleanly. The
    // 0xFFFFFFFF² variant then reaches the budget guard with the
    // same well-formed header, so the rejection is the bound, not a
    // probe failure. Dart's int cannot wrap that product negative;
    // the per-dimension comparison fires first so the 10¹⁹ product
    // is never formed.
    final control = pngHeaderWithDimensions(2, 2);
    final controlInfo = img.PngDecoder().startDecode(control);
    expect(controlInfo!.width, 2);
    expect(controlInfo.height, 2);
    final crafted = pngHeaderWithDimensions(0xFFFFFFFF, 0xFFFFFFFF);
    final craftedInfo = img.PngDecoder().startDecode(crafted);
    expect(
      craftedInfo,
      isNotNull,
      reason: 'the header parses; the bound fires',
    );
    expect(craftedInfo!.width, 0xFFFFFFFF);
    expect(craftedInfo.height, 0xFFFFFFFF);
    await expectLater(
      prepareImageForEgress(crafted),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  test('a header claiming an over-ceiling pixel budget is malformed '
      'input, not an OOM attempt', () async {
    // The pixel payload is tiny, but the header claims 20 MP — over
    // both the 12.5 MP ceiling and the old 16 MP bar, so this fixture
    // does not discriminate the two; the 4096×3072 pin does. The
    // probe still rejects before any decode allocation.
    final bytes = _fakeOverBudgetJpegHeader();
    await expectLater(
      prepareImageForEgress(bytes),
      throwsA(isA<MalformedImageInput>()),
    );
  });

  group('the shared sniff (story 5.3) — the seam\'s single type truth', () {
    test('exactly two formats exist, closed by the enum', () {
      expect(EgressImageFormat.values, hasLength(2));
      expect(
        EgressImageFormat.values,
        containsAll(const [EgressImageFormat.jpeg, EgressImageFormat.png]),
      );
    });

    test('empty bytes and short fragments read null — the length '
        'guards hold', () {
      expect(egressImageFormatOf(Uint8List(0)), isNull);
      expect(
        egressImageFormatOf(Uint8List.fromList([0x89, 0x50, 0x4E])),
        isNull,
        reason: 'a 3-byte PNG prefix fragment is not a sniffed type',
      );
      expect(
        egressImageFormatOf(Uint8List.fromList([0xFF, 0xD8])),
        EgressImageFormat.jpeg,
        reason: 'the two JPEG magic bytes alone admit',
      );
    });

    test('a header claiming zero dimensions is refused by the probe '
        'guard', () async {
      // startDecode parses this header cleanly (valid IHDR CRC, IEND
      // terminates) but claims 0×8 pixels — the probe's
      // positive-dimension guard is the rejection site, before any
      // dimension math runs.
      final bytes = pngHeaderWithDimensions(0, 8);
      await expectLater(
        prepareImageForEgress(bytes),
        throwsA(isA<MalformedImageInput>()),
      );
    });

    test('an in-cap APNG passes through whole — the animated shape the '
        'admit set carries', () async {
      // package:image has no encodeAnimatedPng; its PNG encoder writes
      // a real APNG (acTL/fcTL chunks) for a multi-frame Image, which
      // is the same thing — this fixture is a genuine animated PNG.
      final animated = img.Image.from(gradient(100, 80));
      animated.addFrame(gradient(100, 80));
      final bytes = img.encodePng(animated);
      expect(
        decodeOrThrow(bytes).frames.length,
        2,
        reason: 'the fixture really is animated, not a plain PNG',
      );
      final out = await prepareImageForEgress(bytes);
      expect(
        out,
        equals(bytes),
        reason:
            'in-cap pass-through returns the whole file — the '
            'first-frame decode path never runs under the cap',
      );
    });
  });
}

/// Builds bytes whose JPEG header declares a 5000×4000 SOF frame —
/// large enough to trip the pixel budget, small enough to build cheaply.
Uint8List _fakeOverBudgetJpegHeader() {
  // Minimal JPEG: SOI, APP0(JFIF), SOF0 with the lying dimensions, and
  // a truncated tail (the probe never reaches pixels).
  final out = BytesBuilder();
  out.add([0xFF, 0xD8]); // SOI
  out.add([0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00]); // APP0
  out.add([0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
  // SOF0: length 17, precision 8, height 4000, width 5000.
  out.add([0xFF, 0xC0, 0x00, 0x11, 0x08]);
  out.add([4000 >> 8, 4000 & 0xFF]);
  out.add([5000 >> 8, 5000 & 0xFF]);
  out.add([0x03]); // 3 components, then a plausible truncated tail
  out.add([0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01]);
  out.add([0xFF, 0xD9]); // EOI
  return out.toBytes();
}
