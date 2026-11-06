import 'package:flutter/material.dart';

import '../config/screenshot_config.dart';
import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';
import '../models/screen_size.dart';
import '../models/screenshot_data.dart';
import '../models/screenshot_result.dart';
import '../utils/async_lock.dart';
import '../widgets/screenshot_wrapper.dart';
import 'capture_pipeline.dart';
import 'storage_service.dart';

/// Captures the screen and shares it immediately (single-button mode).
class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();

  /// Returns the singleton service.
  factory ScreenshotService() => _instance;

  ScreenshotService._internal();

  final AsyncLock _lock = AsyncLock();
  final CapturePipeline _pipeline = const CapturePipeline();

  /// Whether a capture is currently in progress.
  bool get isProcessing => _lock.isLocked;

  /// Wraps [child] with a single capture-and-share button.
  static Widget wrapScreen({
    required Widget child,
    bool? showButton,
    AlignmentGeometry? buttonPosition,
    Color? buttonColor,
    ShareMode? overrideShareMode,
    ScreenshotStrings? strings,
    bool enableKeyboardShortcut = true,
    ValueChanged<ScreenshotResult>? onResult,
  }) {
    final config = ScreenshotConfig();

    return ScreenshotWrapper(
      mostrarBotao: showButton ?? config.shouldShowButtons,
      posicaoBotao: buttonPosition ?? Alignment.bottomRight,
      corBotao: buttonColor,
      shareMode: overrideShareMode ?? config.shareMode,
      strings: strings ?? config.strings,
      enableKeyboardShortcut: enableKeyboardShortcut,
      onResult: onResult,
      child: child,
    );
  }

  /// Captures the subtree behind [repaintKey] and shares it as a ZIP archive.
  ///
  /// Returns [ScreenshotBusy] when another capture is already running — this
  /// is not a failure, and callers should not report it as one.
  Future<ScreenshotResult> captureAndShare(
    GlobalKey repaintKey, {
    required double pixelRatio,
    String? customName,
    int? quality,
    List<ScreenSize>? customSizes,
    ShareMode? overrideMode,
    ShareModePicker? modePicker,
    ValueChanged<ScreenshotResult>? onResult,
  }) async {
    final result = await _lock.runIfFree(() async {
      final config = ScreenshotConfig();
      final strings = config.strings;
      final archiveName = customName == null || customName.isEmpty
          ? config.fileNamePrefix
          : customName;

      List<ScreenshotData> screenshots = const [];
      try {
        screenshots = await _pipeline.captureVariants(
          repaintKey: repaintKey,
          pixelRatio: pixelRatio,
          customName: customName,
          quality: quality,
          customSizes: customSizes,
        );

        return await _pipeline.dispatchArchive(
          screenshots: screenshots,
          archiveName: archiveName,
          mode: overrideMode ?? config.shareMode,
          strings: strings,
          modePicker: modePicker,
        );
      } catch (error, stackTrace) {
        debugPrint('❌ captureAndShare falhou: $error');
        return CapturePipeline.describeError(
          error,
          stackTrace,
          fallbackMessage: strings.shareError,
        );
      } finally {
        // Nothing is retained between calls in single-button mode.
        await StorageService().deleteScreenshotFiles(screenshots);
      }
    });

    final outcome = result ?? const ScreenshotBusy();
    onResult?.call(outcome);
    return outcome;
  }
}
