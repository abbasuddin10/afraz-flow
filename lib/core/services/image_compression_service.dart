import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A product photo that has been resized and re-encoded on-device.
///
/// Uploading these bytes instead of the original camera image keeps each
/// product photo comfortably below [ImageCompressionService.maxBytes], which
/// matters on Supabase's free storage tier.
class CompressedImage {
  const CompressedImage({
    required this.bytes,
    this.contentType = ImageCompressionService.contentType,
    this.extension = ImageCompressionService.extension,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;

  int get sizeInBytes => bytes.length;

  double get sizeInKb => sizeInBytes / 1024;
}

/// Resizes and compresses images entirely on the client before they are sent
/// to Supabase Storage.
///
/// The compressor uses the pure-Dart `image` package so the exact same result
/// is produced on Android, iOS, Web, Windows, macOS and Linux. Work runs on a
/// background isolate through [compute] where the platform supports it.
class ImageCompressionService {
  const ImageCompressionService._();

  /// Longest edge of the stored image. Product cards are never wider than a
  /// few hundred logical pixels, so 512px remains crisp on high-density
  /// screens while keeping the payload tiny.
  static const int maxDimension = 512;

  /// Hard budget for a single uploaded product photo.
  static const int maxBytes = 100 * 1024;

  static const int _initialQuality = 80;
  static const int _minQuality = 45;

  static const String contentType = 'image/jpeg';
  static const String extension = 'jpg';

  /// Decodes [input], applies camera orientation, resizes it to fit within
  /// [maxDimension] and re-encodes it as a JPEG under [maxBytes].
  ///
  /// Throws a [FormatException] when the bytes are not a supported image.
  static Future<CompressedImage> compress(Uint8List input) async {
    if (input.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    final bytes = await compute(_compressInIsolate, input);
    return CompressedImage(bytes: bytes);
  }
}

/// Top-level so it can run in an isolate via [compute].
Uint8List _compressInIsolate(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('Unsupported image format.');
  }

  var image = img.bakeOrientation(decoded);
  image = _resizeToFit(image, ImageCompressionService.maxDimension);

  var quality = ImageCompressionService._initialQuality;
  var output = img.encodeJpg(_flattenAlpha(image), quality: quality);

  // Most photos land well under the budget at the first pass. If a very
  // detailed image is still too heavy, reduce quality before shrinking the
  // dimensions so the result never exceeds the storage budget.
  while (output.length > ImageCompressionService.maxBytes &&
      quality > ImageCompressionService._minQuality) {
    quality -= 10;
    output = img.encodeJpg(_flattenAlpha(image), quality: quality);
  }

  var dimension = ImageCompressionService.maxDimension;
  while (output.length > ImageCompressionService.maxBytes && dimension > 160) {
    dimension = (dimension * 0.8).round();
    image = _resizeToFit(image, dimension);
    output = img.encodeJpg(_flattenAlpha(image), quality: quality);
  }

  return output;
}

img.Image _resizeToFit(img.Image source, int maxSide) {
  if (source.width <= maxSide && source.height <= maxSide) return source;
  final ratio = source.width >= source.height
      ? maxSide / source.width
      : maxSide / source.height;
  final width = (source.width * ratio).round().clamp(1, maxSide);
  final height = (source.height * ratio).round().clamp(1, maxSide);
  return img.copyResize(
    source,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
}

/// JPEG has no alpha channel. Composing transparent pixels over white keeps
/// PNG logos and cut-outs looking correct instead of turning black.
img.Image _flattenAlpha(img.Image source) {
  if (source.numChannels < 4) return source;
  final flattened = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flattened, source);
  return flattened;
}
