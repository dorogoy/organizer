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

/// A single-frame GIF — a third codec, to pin the everything-else→JPEG
/// policy.
Uint8List gradientGif(int width, int height) =>
    img.encodeGif(gradient(width, height));

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
