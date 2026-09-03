import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The single image-resolution cap (AD-7): after preparation, no image
/// leaving the app has a dimension over this. 1536 = 2 × the 768 px
/// input tiling of gemini-class vision models — all attainable quality
/// while a 12 MP frame is cut ~6× (story 4.2's decided value).
const int egressImageCap = 1536;

/// The JPEG quality of a capped re-encode (story 4.2's decided value).
const int egressJpegQuality = 85;

/// The maximum raster allocation the pure-Dart decoder may make before the
/// resize. This is a pixel budget rather than a per-dimension limit, so a
/// valid panoramic frame can still be reduced to [egressImageCap] without
/// being rejected merely for having one long edge. The budget keeps a
/// decompression bomb from asking the isolate for an unbounded raster.
const int egressPixelCeiling = 16_000_000;

/// Applies the cap to encoded image bytes, in three phases:
///
/// 1. A header probe (`startDecode` — no pixel decode) reads the
///    raster dimensions. A raster over [egressPixelCeiling] is rejected
///    before allocation as an undecodable resource, while a valid image
///    with a long edge over [egressImageCap] but within the pixel budget is
///    decoded and reduced. Both dimensions within [egressImageCap] return
///    the input value-identical with no full decode — the header alone
///    decides pass-through, so the original bytes (EXIF orientation tag
///    included) travel untouched.
/// 2. Oversized input is decoded (first frame only for animated
///    formats), its EXIF orientation baked into the pixels before the
///    target dimensions are computed — a portrait-stored-landscape
///    frame cannot be resized on its un-baked raster and then reach
///    the model sideways when the re-encode drops the tag.
/// 3. The resize runs with averaging interpolation (the codec's
///    nearest-neighbour default aliases badly at the ~2.6× downscale a
///    4000 px frame takes) and re-encodes by explicit policy: JPEG
///    stays JPEG (q85), PNG stays PNG, every other decodable format
///    (WebP, GIF, BMP, TGA, …) becomes JPEG q85 — one uniform shape
///    for the transport, never a rejection.
///
/// Undecodable bytes throw [FormatException]; dispatch surfaces that as
/// a failed egress, never as a rejection of the user. The codec is pure
/// Dart (`package:image` — no Android footprint, so both native seals
/// stay unaffected) and runs via `compute()`, off the UI isolate.
Future<Uint8List> prepareImageForEgress(Uint8List bytes) =>
    compute(_capImage, bytes);

Uint8List _capImage(Uint8List bytes) {
  final decoder = _probeDecoder(bytes);
  final (probeWidth, probeHeight) = _probeDimensions(decoder, bytes);
  if (probeWidth * probeHeight > egressPixelCeiling) {
    // The decoder stores every source pixel as 32-bit RGBA. Refuse a
    // resource whose allocation would be unsafe, before pixel decode.
    throw const FormatException();
  }
  final longest = probeWidth > probeHeight ? probeWidth : probeHeight;
  if (longest <= egressImageCap) {
    // Pass-through, decided by the header probe alone.
    return bytes;
  }
  final image = _decodeFirstFrame(decoder, bytes);
  // Bake EXIF orientation into the pixels before any dimension math:
  // the target size must be computed on the oriented raster.
  final oriented =
      image.exif.imageIfd.hasOrientation && image.exif.imageIfd.orientation != 1
      ? img.bakeOrientation(image)
      : image;
  final orientedLongest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  // Integer math: the longer edge lands exactly on the cap and the
  // shorter is floored, so rounding can never push a dimension over it.
  var width = oriented.width * egressImageCap ~/ orientedLongest;
  var height = oriented.height * egressImageCap ~/ orientedLongest;
  if (width == 0) {
    width = 1;
  }
  if (height == 0) {
    height = 1;
  }
  final resized = img.copyResize(
    oriented,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  if (decoder.format == img.ImageFormat.png) {
    return img.encodePng(resized);
  }
  return img.encodeJpg(resized, quality: egressJpegQuality);
}

/// Identifies the codec. Every failure — unknown format, or a short
/// buffer that upsets a probe itself — is the one [FormatException].
img.Decoder _probeDecoder(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    if (decoder != null) {
      return decoder;
    }
  } catch (_) {
    // A truncated buffer can upset a probe; it is still undecodable.
  }
  throw const FormatException();
}

/// Reads the raster dimensions from the header, without decoding
/// pixels.
(int, int) _probeDimensions(img.Decoder decoder, Uint8List bytes) {
  try {
    final info = decoder.startDecode(bytes);
    if (info != null && info.width > 0 && info.height > 0) {
      return (info.width, info.height);
    }
  } catch (_) {
    // Header-level parse failure: undecodable.
  }
  throw const FormatException();
}

/// Decodes the first frame only — animated input (GIF, animated WebP)
/// contributes its opening frame and nothing else.
img.Image _decodeFirstFrame(img.Decoder decoder, Uint8List bytes) {
  try {
    final image = decoder.decode(bytes, frame: 0);
    if (image != null) {
      return image;
    }
  } catch (_) {
    // Pixel-level decode failure: undecodable.
  }
  throw const FormatException();
}
