// Modelo para dados da captura
import 'dart:typed_data';

/// Model class representing a captured screenshot with its metadata
class ScreenshotData {
  /// Raw bytes of the image
  final Uint8List bytes;

  /// Filename for the screenshot
  final String filename;

  /// Width of the image in pixels
  final int width;

  /// Height of the image in pixels
  final int height;

  /// Group identifier for this screenshot (e.g., "capture_1234567890")
  final String group;

  /// Timestamp when the screenshot was captured
  final int timestamp;

  /// Creates a new screenshot data object
  ScreenshotData({
    required this.bytes,
    required this.filename,
    required this.width,
    required this.height,
    required this.group,
    required this.timestamp,
  });

  /// File size in kilobytes
  double get fileSizeKB => bytes.length / 1024;

  /// Creates a string representation for debugging
  @override
  String toString() => 'ScreenshotData($filename, ${bytes.length} bytes, $width x $height)';
}
