import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The image formats the seam can honestly carry and declare. The
/// cap's admit-set and the wire's declarable-mime set are the same
/// two facts, read from one sniff — a third format exists on neither
/// side (AC1, AD-7).
enum EgressImageFormat { jpeg, png }

/// The single magic-number sniff the whole seam reads (story 5.3):
/// JPEG's `FF D8` and PNG's `89 50 4E 47` prefix admit; every other
/// prefix — a decodable WebP, GIF or BMP included — is null. The cap
/// gates on it before any decode; the wire's `imageMimeTypeOf` maps
/// it onto the one mime it declares. One sniff, so the cap and the
/// wire cannot disagree about an input's type by construction.
EgressImageFormat? egressImageFormatOf(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return EgressImageFormat.jpeg;
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return EgressImageFormat.png;
  }
  return null;
}

/// The image seam's one pre-transport rejection (story 5.3): the
/// input cannot be carried honestly — its magic is neither JPEG's nor
/// PNG's, its bytes will not decode, its header claims more pixels
/// than [egressPixelCeiling], or its body trips the header probe.
/// Corruption is detected exactly there — the probe, or the oversized
/// decode path; a body whose header parses within the cap passes
/// through value-identical whatever follows the header (4-2's
/// header-decides pass-through design, unchanged by this story). One
/// fact, one type, whether the input was undecodable or merely
/// undeclarable: nothing was ever sent, so this is never the
/// delivered-but-unusable `malformedResponse`. A plain final class
/// with no closures and no ports, so it crosses `compute()`'s
/// isolate boundary cleanly (Flutter rethrows isolate errors
/// verbatim) — the dispatch test exercises exactly that path.
final class MalformedImageInput implements Exception {
  const MalformedImageInput();
}

/// The single image-resolution cap (AD-7): after preparation, no image
/// leaving the app has a dimension over this. 1536 = 2 × the 768 px
/// input tiling of gemini-class vision models — all attainable quality
/// while a 12 MP frame is cut ~6× (story 4.2's decided value).
const int egressImageCap = 1536;

/// The JPEG quality of a capped re-encode (story 4.2's decided value).
const int egressJpegQuality = 85;

/// The maximum raster allocation the pure-Dart decoder may make before
/// the resize. The budget is a pixel budget, not a second size policy
/// — a valid panoramic frame is reduced to [egressImageCap] rather
/// than rejected merely for having one long edge — guarded before the
/// product by a per-dimension bound at this same constant: overflow
/// armor, not a second limit. A claimed dimension alone above the
/// budget is a lie no product needs to read (see the guard's comment
/// on the int64 wrap); for honest positive dimensions the product
/// check dominates, so the bound rejects nothing the product check
/// alone would admit. The budget keeps a decompression bomb from
/// asking the isolate for an unbounded raster.
///
/// The value is the recorded memory arithmetic (story 5.3, review
/// round 1: ruled 12,500,000 — a literal 12,000,000 would have
/// rejected the canonical 12 MP sensor output, 4032×3024 =
/// 12,192,768 px, which is exactly the camera class this budget
/// exists to admit). The codec stores a JPEG raster as 3-channel
/// uint8 — JPEG being the only production input, the camera — so a
/// 12.5 MP frame is ≈ 37.5 MB, and ≈ 50 MB at the alpha-format worst
/// case (×4). The resize target is bounded by ≈ 1536×1536 ≈ 2.36 MP ≈
/// 7.1–9.4 MB — the long edge always lands on [egressImageCap], so a
/// 1536×2048 target never occurs — and the encode buffers are bounded
/// by the same target. The flow is sequenced so these peaks do not
/// stack: the face gate's native decode is released (its bitmap
/// `close()`d in a `finally`) before the cap runs, leaving the raw
/// capture bytes (~10 MB at `ResolutionPreset.max`) the only
/// co-resident holding — ≈ 50–63 MB transient peak in the compute
/// isolate for the JPEG production path, inside low-RAM process
/// budgets, versus ~70+ MB at 16 MP. The alpha-format worst case
/// peaks ≈ 72 MB and has no production sender (the camera is
/// JPEG-only); it is recorded here as residual, not scoped away.
/// Captures above 12.5 MP reject as malformed input before any
/// allocation; widening that rejection band (12.5–16 MP and above) is
/// the accepted cost of the honest ceiling — the bounded-capture-preset
/// decision that would shrink it stays deferred, coupled to the 5.1
/// composition reopen (deferred-work.md).
const int egressPixelCeiling = 12_500_000;

/// Applies the seam's admit-and-cap policy to encoded image bytes:
///
/// 1. The shared magic sniff ([egressImageFormatOf]) gates before any
///    decode: only JPEG and PNG proceed — the only types the wire can
///    declare honestly. Every other input, decodable or not, throws
///    [MalformedImageInput] here, before any transport exists: a
///    sub-cap WebP, GIF or BMP the codec could read is refused all
///    the same, because a type the wire cannot declare must never be
///    re-labelled to fit (AC1, AD-7).
/// 2. A header probe (`startDecode` — no pixel decode) reads the
///    raster dimensions. A raster over [egressPixelCeiling] is
///    rejected before allocation; a valid image with a long edge over
///    [egressImageCap] but within the pixel budget is decoded and
///    reduced. Both dimensions within [egressImageCap] return the
///    input value-identical with no full decode — the header alone
///    decides pass-through, so the original bytes (EXIF orientation
///    tag included, every animation frame an animated PNG carries)
///    travel untouched, whatever follows the header.
/// 3. Oversized input is decoded — first frame only, on this decode
///    path alone; pass-through above never splits a file — its EXIF
///    orientation baked into the pixels before the target dimensions
///    are computed — a portrait-stored-landscape frame cannot be
///    resized on its un-baked raster and then reach the model sideways
///    when the re-encode drops the tag — resized with averaging
///    interpolation (the codec's nearest-neighbour default aliases
///    badly at the ~2.6× downscale a 4000 px frame takes), and
///    re-encoded by explicit policy: JPEG stays JPEG (q85), PNG stays
///    PNG — the re-encode can only ever emit a type the sniff already
///    admitted.
///
/// Every failure — undeclarable magic, undecodable bytes, a body the
/// header probe trips (or, on the oversized path, the decode), an
/// over-budget header — is the one [MalformedImageInput]; dispatch
/// surfaces it as a failed egress before the transport is touched. It
/// is a fact about the input, never a rejection of the user (nothing
/// was sent, no payload left the device). The codec is pure Dart
/// (`package:image` — no Android footprint, so both native seals stay
/// unaffected) and runs via `compute()`, off the UI isolate.
Future<Uint8List> prepareImageForEgress(Uint8List bytes) =>
    compute(_capImage, bytes);

Uint8List _capImage(Uint8List bytes) {
  final format = egressImageFormatOf(bytes);
  if (format == null) {
    // Not JPEG, not PNG: a type the wire cannot declare, or not an
    // image at all — refused before any decoder is found or asked.
    throw const MalformedImageInput();
  }
  final decoder = _probeDecoder(bytes, format);
  final (probeWidth, probeHeight) = _probeDimensions(decoder, bytes);
  // Per-dimension bound first: a crafted PNG header can claim two
  // near-uint32-max dimensions. Dart's `int` is arbitrary-precision, so
  // the product cannot wrap negative — 4294967295² is just a very
  // large int, and a product-only comparison would still refuse it —
  // but forming that product is wasted work on a lie no decode should
  // ever see. Bounding each dimension alone first means the product
  // below is only ever taken on values already inside the budget.
  if (probeWidth > egressPixelCeiling ||
      probeHeight > egressPixelCeiling ||
      probeWidth * probeHeight > egressPixelCeiling) {
    // The decoder stores every source pixel as uint8 channels (3 for
    // the JPEG production path, 4 at the alpha worst case — the
    // arithmetic [egressPixelCeiling]'s doc records). Refuse a
    // resource whose allocation would be unsafe, before pixel decode.
    throw const MalformedImageInput();
  }
  final longest = probeWidth > probeHeight ? probeWidth : probeHeight;
  if (longest <= egressImageCap) {
    // Pass-through, decided by the header probe alone.
    return bytes;
  }
  final image = _decodeFirstFrame(decoder, bytes);
  // Bake, resize and encode are still pre-transport: a throw here
  // never reached a provider, so it is the same MalformedImageInput
  // as the four named refusal sites, never `_causeOf`'s residual
  // `providerUnreachable`.
  try {
    // Bake EXIF orientation into the pixels before any dimension math:
    // the target size must be computed on the oriented raster.
    final oriented =
        image.exif.imageIfd.hasOrientation &&
            image.exif.imageIfd.orientation != 1
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
    // Re-encode from the sniff, not from decoder.format: the
    // admit-set is two formats, and the copy on the wire is one of
    // those two.
    return switch (format) {
      EgressImageFormat.png => img.encodePng(resized),
      EgressImageFormat.jpeg => img.encodeJpg(
        resized,
        quality: egressJpegQuality,
      ),
    };
  } catch (error) {
    if (error is MalformedImageInput) rethrow;
    throw const MalformedImageInput();
  }
}

/// Identifies the codec the sniff already admitted. The walk of every
/// registered decoder (`findDecoderForData`) is not used: TGA has no
/// magic, and a body the sniff called JPEG/PNG that those codecs
/// refuse must not be claimed by another format and then declared as
/// the sniff's mime. Every failure — the admitted codec rejects the
/// body, or a short buffer upsets the probe itself — is the one
/// [MalformedImageInput]: the sniff already admitted the magic, so a
/// probe refusal here is a corrupt body, pre-transport.
img.Decoder _probeDecoder(Uint8List bytes, EgressImageFormat format) {
  try {
    final decoder = switch (format) {
      EgressImageFormat.jpeg => img.JpegDecoder(),
      EgressImageFormat.png => img.PngDecoder(),
    };
    if (decoder.isValidFile(bytes)) {
      return decoder;
    }
  } catch (_) {
    // A truncated buffer can upset a probe; it is still undecodable.
  }
  throw const MalformedImageInput();
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
  throw const MalformedImageInput();
}

/// Decodes the first frame only — on this oversized-decode path,
/// animated input contributes its opening frame and nothing else
/// (an in-cap animated PNG never reaches here: it passes through
/// whole). With GIF and WebP refused at the sniff (story 5.3), the
/// admitted animated shape is APNG, which sniffs as PNG and is
/// admitted; its opening frame is all this path reads.
img.Image _decodeFirstFrame(img.Decoder decoder, Uint8List bytes) {
  try {
    final image = decoder.decode(bytes, frame: 0);
    if (image != null) {
      return image;
    }
  } catch (_) {
    // Pixel-level decode failure: undecodable.
  }
  throw const MalformedImageInput();
}
