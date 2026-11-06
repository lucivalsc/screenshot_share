import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../config/screenshot_config.dart';
import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';
import '../exceptions/screenshot_exceptions.dart';
import '../models/screen_size.dart';
import '../models/screenshot_data.dart';
import '../models/screenshot_result.dart';
import '../utils/image_processor.dart';
import 'storage_service.dart';

/// Asks the user which [ShareMode] to use. Returns `null` when cancelled.
typedef ShareModePicker = Future<ShareMode?> Function();

/// Shared capture and dispatch steps used by both public services.
///
/// Extracted so the single-button and dual-button flows no longer carry two
/// near-identical copies of the capture pipeline, as they did up to 0.1.4.
class CapturePipeline {
  /// Creates a capture pipeline.
  const CapturePipeline();

  /// Resolves the pixel ratio to use for a capture taken from [context].
  ///
  /// Precedence: explicit configuration > the view's device pixel ratio >
  /// a conservative fallback. Always clamped to the supported range, so a
  /// high-density tablet cannot blow up the intermediate bitmap.
  static double resolvePixelRatio(BuildContext context, {double? override}) {
    final configured = override ?? ScreenshotConfig().pixelRatio;
    if (configured != null) {
      return ScreenshotConfig.clampPixelRatio(configured);
    }

    final fromView = MediaQuery.maybeOf(context)?.devicePixelRatio ??
        View.maybeOf(context)?.devicePixelRatio;

    return ScreenshotConfig.clampPixelRatio(fromView ?? 2.0);
  }

  /// Captures the subtree behind [repaintKey] and produces one variant per
  /// configured resolution, written to the cache directory.
  Future<List<ScreenshotData>> captureVariants({
    required GlobalKey repaintKey,
    required double pixelRatio,
    String? customName,
    int? quality,
    List<ScreenSize>? customSizes,
  }) async {
    final config = ScreenshotConfig();
    final screenName = customName == null || customName.isEmpty
        ? config.fileNamePrefix
        : customName;
    final screenSizes = customSizes ?? config.screenSizes;
    final imageQuality = quality ?? config.imageQuality;

    final renderObject = repaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const CaptureUnavailableException(
        'Nenhum RenderRepaintBoundary encontrado para a chave informada. '
        'Garanta que o widget esteja montado e visível.',
      );
    }

    final Uint8List pngBytes;
    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const ScreenshotException(
          'toByteData retornou null; a imagem capturada não pôde ser '
          'convertida para PNG.',
        );
      }
      pngBytes = byteData.buffer.asUint8List();
    } finally {
      // The bitmap lives in native memory and is invisible to the Dart GC;
      // not disposing it leaked 8-30 MB per capture up to version 0.1.4.
      image?.dispose();
    }

    final cacheDirectory = await StorageService().captureCacheDirectory();

    return const ImageProcessor().processImage(
      pngBytes: pngBytes,
      screenName: screenName,
      screenSizes: screenSizes,
      imageQuality: imageQuality,
      resizeStrategy: config.resizeStrategy,
      backgroundColor: _toRgb(config.backgroundColor),
      outputDirectoryPath: cacheDirectory.path,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Zips [screenshots] and delivers the archive to the chosen destination.
  ///
  /// Every destination receives one ZIP archive; loose files are never shared.
  Future<ScreenshotResult> dispatchArchive({
    required List<ScreenshotData> screenshots,
    required String archiveName,
    required ShareMode mode,
    required ScreenshotStrings strings,
    ShareModePicker? modePicker,
  }) async {
    if (screenshots.isEmpty) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.noData,
        message: strings.noScreenshots,
      );
    }

    var effectiveMode = mode;
    if (effectiveMode == ShareMode.askUser) {
      if (modePicker == null) {
        return ScreenshotFailure(
          kind: ScreenshotErrorKind.configuration,
          message: strings.pickerUnavailable,
        );
      }
      final chosen = await modePicker();
      if (chosen == null || chosen == ShareMode.askUser) {
        return const ScreenshotCancelled();
      }
      effectiveMode = chosen;
    }

    final storage = StorageService();
    final archive = await storage.createZipArchive(
      screenshots,
      archiveName: archiveName,
    );

    switch (effectiveMode) {
      case ShareMode.localSave:
        try {
          final path = await storage.saveArchiveLocally(
            archive,
            archiveName: archiveName,
          );
          return ScreenshotSuccess(
            count: screenshots.length,
            location: path,
          );
        } finally {
          // The archive was copied to its destination; the cached copy is
          // no longer needed.
          await storage.discardArchive(archive);
        }

      case ShareMode.shareWithApps:
        // The archive is intentionally kept in the cache: the receiving app
        // may still be reading it. cleanupTemporaryArtifacts() reclaims it.
        final outcome = await storage.shareArchive(
          archive,
          subject: strings.shareSubject,
          text: strings.shareTextFor(screenshots.length),
        );
        return outcome == ShareOutcome.dismissed
            ? const ScreenshotCancelled()
            : ScreenshotSuccess(count: screenshots.length);

      case ShareMode.askUser:
        // Unreachable: resolved above.
        return ScreenshotFailure(
          kind: ScreenshotErrorKind.configuration,
          message: strings.pickerUnavailable,
        );
    }
  }

  /// Maps a thrown error onto a typed [ScreenshotFailure].
  static ScreenshotFailure describeError(
    Object error,
    StackTrace stackTrace, {
    required String fallbackMessage,
  }) {
    if (error is CaptureUnavailableException) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.noRenderBoundary,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is ImageProcessingException) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.processing,
        message: error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is CaptureBufferFullException) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.bufferFull,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is StorageFailureException) {
      return ScreenshotFailure(
        kind: error.isPermissionIssue
            ? ScreenshotErrorKind.permission
            : ScreenshotErrorKind.storage,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is ScreenshotException) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.encoding,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is ArgumentError || error is StateError) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.configuration,
        message: error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is FileSystemException) {
      return ScreenshotFailure(
        kind: ScreenshotErrorKind.storage,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return ScreenshotFailure(
      kind: ScreenshotErrorKind.unknown,
      message: '$fallbackMessage: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static int _toRgb(Color color) {
    final r = (color.r * 255.0).round() & 0xFF;
    final g = (color.g * 255.0).round() & 0xFF;
    final b = (color.b * 255.0).round() & 0xFF;
    return (r << 16) | (g << 8) | b;
  }
}
