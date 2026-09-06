/// Shared fixture builders for the egress tests (story 4-2): gradient
/// rasters in every codec shape the cap policy names, plus decode and
/// format probes for asserting what the transport would see.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List gradientJpeg(int width, int height) =>
    img.encodeJpg(gradient(width, height), quality: 90);

/// A JPEG whose raster is [width]×[height] and whose EXIF orientation
/// tag says [orientation] (2–8) — the portrait-stored-landscape shape
/// the bake must handle before any dimension math.
Uint8List rotatedJpeg(int width, int height, int orientation) {
  final image = gradient(width, height);
  image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 90);
}

Uint8List gradientPng(int width, int height) =>
    img.encodePng(gradient(width, height));

/// A single-frame GIF — a third real codec, to pin the
/// admit-exactly-two rejection (story 5.3): the seam refuses GIF
/// pre-transport; the old everything-else→JPEG policy is gone.
Uint8List gradientGif(int width, int height) =>
    img.encodeGif(gradient(width, height));

/// A decodable sub-cap WebP — a fourth real codec whose magic the
/// seam refuses (story 5.3): the bytes decode fine, and that is the
/// point — the rejection is about the wire's declarable types, never
/// about decodability.
Uint8List gradientWebP(int width, int height) =>
    img.encodeWebP(gradient(width, height));

/// A decodable sub-cap BMP — the third undeclarable shape the seam
/// refuses.
Uint8List gradientBmp(int width, int height) =>
    img.encodeBmp(gradient(width, height));

img.Image gradient(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x * 255 ~/ width, y * 255 ~/ height, 128);
    }
  }
  return image;
}

img.Image decodeOrThrow(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw StateError('fixture did not decode');
  }
  return image;
}

img.ImageFormat formatOf(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) {
    throw StateError('fixture format unknown');
  }
  return decoder.format;
}

/// A PNG chunk: big-endian length, type, data, and the standard CRC-32
/// over type + data (the decoder validates the IHDR CRC and throws on
/// a mismatch, so the fixture computes the real one).
Uint8List pngChunk(String type, List<int> data) {
  final body = <int>[...type.codeUnits, ...data];
  var crc = 0xFFFFFFFF;
  for (final byte in body) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
  }
  crc ^= 0xFFFFFFFF;
  final out = BytesBuilder();
  out.add([
    data.length >> 24,
    data.length >> 16,
    data.length >> 8,
    data.length & 0xFF,
  ]);
  out.add(body);
  out.add([
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
  return out.toBytes();
}

/// A minimal, well-formed PNG: signature + IHDR claiming
/// [width]×[height] (8-bit RGBA, no interlace) + IEND. The header
/// parses cleanly; no IDAT follows, so no pixel decode can succeed.
Uint8List pngHeaderWithDimensions(int width, int height) {
  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  out.add(
    pngChunk('IHDR', [
      (width >> 24) & 0xFF,
      (width >> 16) & 0xFF,
      (width >> 8) & 0xFF,
      width & 0xFF,
      (height >> 24) & 0xFF,
      (height >> 16) & 0xFF,
      (height >> 8) & 0xFF,
      height & 0xFF,
      8, // bit depth
      6, // color type: RGBA
      0, // compression
      0, // filter
      0, // interlace
    ]),
  );
  out.add(pngChunk('IEND', const []));
  return out.toBytes();
}
