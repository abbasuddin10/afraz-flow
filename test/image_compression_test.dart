import 'dart:math';
import 'dart:typed_data';

import 'package:afraz_flow/core/services/image_compression_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'large photos are resized and compressed under the 100 KB budget',
    () async {
      final random = Random(7);
      final source = img.Image(width: 1600, height: 1200);
      for (final pixel in source) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final input = img.encodeJpg(source, quality: 98);

      final result = await ImageCompressionService.compress(input);

      expect(result.contentType, 'image/jpeg');
      expect(result.extension, 'jpg');
      expect(
        result.sizeInBytes,
        lessThanOrEqualTo(ImageCompressionService.maxBytes),
      );
      final decoded = img.decodeJpg(result.bytes);
      expect(decoded, isNotNull);
      expect(
        max(decoded!.width, decoded.height),
        lessThanOrEqualTo(ImageCompressionService.maxDimension),
      );
    },
  );

  test('small photos are not upscaled', () async {
    final source = img.Image(width: 320, height: 200);
    img.fill(source, color: img.ColorRgb8(20, 160, 140));
    final input = img.encodePng(source);

    final result = await ImageCompressionService.compress(input);

    final decoded = img.decodeJpg(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 320);
    expect(decoded.height, 200);
  });

  test('unsupported bytes are rejected', () async {
    await expectLater(
      ImageCompressionService.compress(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
  });
}
