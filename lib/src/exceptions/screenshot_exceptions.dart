import '../models/screen_size.dart';

/// Base class for every failure raised by this package.
class ScreenshotException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// The original error, when this exception wraps another one.
  final Object? cause;

  /// Stack trace of [cause], when available.
  final StackTrace? causeStackTrace;

  /// Creates a screenshot exception.
  const ScreenshotException(this.message, {this.cause, this.causeStackTrace});

  @override
  String toString() => cause == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message (causa: $cause)';
}

/// The stage of the image pipeline that failed.
enum ImageProcessingStage {
  /// Decoding the captured PNG bytes.
  decode,

  /// Resizing the decoded image to a target resolution.
  resize,

  /// Encoding a resized image to JPEG.
  encode,

  /// Writing an encoded variant to the cache directory.
  write,
}

/// Raised inside the processing isolate when a variant cannot be produced.
///
/// Up to version 0.1.4 every failure here was swallowed and reported as an
/// empty list, which made the most failure-prone stage of the pipeline the
/// only one without diagnostics.
class ImageProcessingException extends ScreenshotException {
  /// Which stage failed.
  final ImageProcessingStage stage;

  /// Index of the target size being processed, when applicable.
  final int? sizeIndex;

  /// The target size being processed, when applicable.
  final ScreenSize? size;

  /// Creates an image processing exception.
  const ImageProcessingException(
    super.message, {
    required this.stage,
    this.sizeIndex,
    this.size,
    super.cause,
    super.causeStackTrace,
  });

  @override
  String toString() {
    final target = size == null ? '' : ' [$size]';
    return 'ImageProcessingException(${stage.name})$target: $message';
  }
}

/// Raised when the widget tree does not expose a `RenderRepaintBoundary`.
class CaptureUnavailableException extends ScreenshotException {
  /// Creates a capture-unavailable exception.
  const CaptureUnavailableException(super.message, {super.cause});
}

/// Raised when a filesystem or archive operation fails.
class StorageFailureException extends ScreenshotException {
  /// Whether the failure looks like a missing OS permission.
  final bool isPermissionIssue;

  /// Creates a storage failure.
  const StorageFailureException(
    super.message, {
    this.isPermissionIssue = false,
    super.cause,
    super.causeStackTrace,
  });
}

/// Raised when storing another capture would exceed the configured limits.
class CaptureBufferFullException extends ScreenshotException {
  /// Number of capture groups currently held.
  final int storedCaptures;

  /// Total bytes currently held on disk.
  final int storedBytes;

  /// Creates a buffer-full exception.
  const CaptureBufferFullException(
    super.message, {
    required this.storedCaptures,
    required this.storedBytes,
  });
}
