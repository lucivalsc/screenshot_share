import 'package:flutter/foundation.dart';

/// Category of a [ScreenshotFailure], suitable for branching in the UI.
enum ScreenshotErrorKind {
  /// The package is misconfigured (empty size list, missing picker, ...).
  configuration,

  /// No `RenderRepaintBoundary` was found for the supplied key.
  noRenderBoundary,

  /// The captured image could not be converted to bytes.
  encoding,

  /// Decoding, resizing or writing a variant failed.
  processing,

  /// A filesystem or archive operation failed.
  storage,

  /// The destination requires an OS permission that was not granted.
  permission,

  /// Storing another capture would exceed the configured limits.
  bufferFull,

  /// There is nothing to share.
  noData,

  /// Anything not covered above.
  unknown,
}

/// Outcome of a capture or share operation.
///
/// Replaces the `Future<bool>` returned up to version 0.1.4, which could not
/// distinguish "another operation is already running" from a real failure and
/// discarded the diagnostic message entirely.
@immutable
sealed class ScreenshotResult {
  /// Creates a result.
  const ScreenshotResult();

  /// Whether the operation completed successfully.
  bool get isSuccess => this is ScreenshotSuccess;
}

/// The operation completed successfully.
final class ScreenshotSuccess extends ScreenshotResult {
  /// Number of image variants involved.
  final int count;

  /// Where the archive ended up, when the destination has a stable path.
  final String? location;

  /// Creates a successful result.
  const ScreenshotSuccess({required this.count, this.location});

  @override
  String toString() => 'ScreenshotSuccess($count variantes'
      '${location == null ? '' : ', em $location'})';
}

/// Another capture or share operation is already in progress.
///
/// This is not a failure: the caller should simply wait instead of showing an
/// error to the user.
final class ScreenshotBusy extends ScreenshotResult {
  /// Creates a busy result.
  const ScreenshotBusy();

  @override
  String toString() => 'ScreenshotBusy()';
}

/// The user dismissed the share sheet or the destination picker.
final class ScreenshotCancelled extends ScreenshotResult {
  /// Creates a cancelled result.
  const ScreenshotCancelled();

  @override
  String toString() => 'ScreenshotCancelled()';
}

/// The operation failed.
final class ScreenshotFailure extends ScreenshotResult {
  /// Category of the failure.
  final ScreenshotErrorKind kind;

  /// Diagnostic message, safe to show to the user.
  final String message;

  /// The underlying error, when this failure wraps one.
  final Object? cause;

  /// Stack trace of [cause], when available.
  final StackTrace? stackTrace;

  /// Creates a failure result.
  const ScreenshotFailure({
    required this.kind,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'ScreenshotFailure(${kind.name}): $message';
}
