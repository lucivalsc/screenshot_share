import 'dart:io';

import 'package:flutter/foundation.dart';

/// Metadata of one generated screenshot variant, backed by a file on disk.
///
/// Up to version 0.1.4 this model carried the raw JPEG bytes in memory, which
/// made a batch of captures grow without bound. The bytes now live in the
/// cache directory and are read on demand, so holding a reference costs only
/// a few dozen bytes of heap.
@immutable
class ScreenshotData {
  /// Absolute path of the generated JPEG file.
  final String path;

  /// Filename of the variant, also used as its ZIP entry name.
  final String filename;

  /// Width of the image in pixels.
  final int width;

  /// Height of the image in pixels.
  final int height;

  /// Size of the file on disk, in bytes.
  final int sizeInBytes;

  /// Group identifier shared by every variant of the same capture.
  final String group;

  /// Milliseconds since epoch of the moment the capture was taken.
  final int timestamp;

  /// Creates screenshot metadata.
  const ScreenshotData({
    required this.path,
    required this.filename,
    required this.width,
    required this.height,
    required this.sizeInBytes,
    required this.group,
    required this.timestamp,
  });

  /// The backing file.
  File get file => File(path);

  /// File size in kilobytes.
  double get fileSizeKB => sizeInBytes / 1024;

  /// Reads the image bytes from disk.
  Future<Uint8List> readBytes() => file.readAsBytes();

  /// Deletes the backing file, ignoring a file that is already gone.
  Future<void> delete() async {
    try {
      final target = file;
      if (await target.exists()) {
        await target.delete();
      }
    } on FileSystemException {
      // The cache directory may be cleared by the OS at any time; a missing
      // file is the desired end state either way.
    }
  }

  @override
  String toString() =>
      'ScreenshotData($filename, $sizeInBytes bytes, $width x $height)';
}
