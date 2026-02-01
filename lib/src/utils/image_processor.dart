import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/screenshot_data.dart';

/// Class responsible for processing images in a separate isolate
class ImageProcessor {
  /// Process the captured image: decode, resize for multiple screens, and encode to JPG.
  /// This runs in a separate isolate to avoid blocking the UI thread.
  Future<List<ScreenshotData>> processImage({
    required Uint8List pngBytes,
    required String screenName,
    required List<Map<String, dynamic>> screenSizes,
    required int imageQuality,
  }) async {
    // Run the heavy processing in a separate isolate
    return await compute(
      _processImageIsolate,
      _ImageProcessParams(
        pngBytes: pngBytes,
        screenName: screenName,
        screenSizes: screenSizes,
        imageQuality: imageQuality,
      ),
    );
  }

  /// The static function that runs in the isolate
  static List<ScreenshotData> _processImageIsolate(_ImageProcessParams params) {
    try {
      // Decode the image
      final img.Image? decodedImage = img.decodePng(params.pngBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode PNG image');
      }

      // Timestamp for this capture
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final captureId = '${params.screenName}_$timestamp';

      final screenshots = <ScreenshotData>[];

      for (int i = 0; i < params.screenSizes.length; i++) {
        final size = params.screenSizes[i];
        final width = size['width'] as int;
        final height = size['height'] as int;
        final suffix = size['suffix'] as String;

        // Resize the image
        final resizedImage = img.copyResize(
          decodedImage,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
        );

        // Encode to JPEG
        final jpegBytes =
            img.encodeJpg(resizedImage, quality: params.imageQuality);

        // Create screenshot data object
        final screenshot = ScreenshotData(
          bytes: Uint8List.fromList(jpegBytes),
          filename: '${params.screenName}_${timestamp}_$suffix.jpg',
          width: width,
          height: height,
          group: captureId,
          timestamp: timestamp,
        );

        screenshots.add(screenshot);
      }

      return screenshots;
    } catch (e) {
      debugPrint('❌ Error in image processing isolate: $e');
      return [];
    }
  }
}

/// Parameters to pass to the isolate
class _ImageProcessParams {
  final Uint8List pngBytes;
  final String screenName;
  final List<Map<String, dynamic>> screenSizes;
  final int imageQuality;

  _ImageProcessParams({
    required this.pngBytes,
    required this.screenName,
    required this.screenSizes,
    required this.imageQuality,
  });
}
