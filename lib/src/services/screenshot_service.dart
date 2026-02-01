// Serviço de captura de tela
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/screenshot_config.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_data.dart';
import '../widgets/screenshot_wrapper.dart';
import 'storage_service.dart';
import '../utils/image_processor.dart';
import 'telegram_service.dart';

/// Service for capturing and immediately sharing screenshots (single-button mode)
class ScreenshotService {
  // Singleton pattern
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  // Capture and share status
  bool _isProcessing = false;

  /// Create a widget that wraps the entire app with screenshot capture functionality
  static Widget wrapScreen({
    required Widget child,
    bool? showButton,
    AlignmentGeometry? buttonPosition,
    Color? buttonColor,
    ShareMode? overrideShareMode,
  }) {
    final config = ScreenshotConfig();

    return ScreenshotWrapper(
      mostrarBotao: showButton ?? config.shouldShowButtons,
      posicaoBotao: buttonPosition ?? Alignment.bottomRight,
      corBotao: buttonColor ?? Colors.red.withOpacity(0.7),
      shareMode: overrideShareMode ?? config.shareMode,
      child: child,
    );
  }

  /// Capture and immediately share a screenshot
  Future<bool> captureAndShare(
    GlobalKey repaintKey, {
    String? customName,
    int? quality,
    List<Map<String, dynamic>>? customSizes,
    ShareMode? overrideMode,
    Function(String error)? onError,
    Function()? onSuccess,
  }) async {
    // Prevent multiple simultaneous operations
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final config = ScreenshotConfig();
      final screenName = customName ?? config.fileNamePrefix;
      final screenSizes = customSizes ?? config.screenSizes;
      final imageQuality = quality ?? config.imageQuality;
      final shareMode = overrideMode ?? config.shareMode;

      debugPrint('📸 Starting screen capture and share: "$screenName"...');

      // 1. Capture Image from RepaintBoundary
      final renderObject = repaintKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        _handleError('Could not find RenderRepaintBoundary', onError);
        return false;
      }

      final boundary = renderObject;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _handleError('Failed to get ByteData from image', onError);
        return false;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      debugPrint('📸 Captured raw image: ${pngBytes.length} bytes');

      // 2. Process Image (Resize & Encode) in Background Isolate
      debugPrint('📸 Processing images in background isolate...');
      final ImageProcessor processor = ImageProcessor();
      final List<ScreenshotData> screenshots = await processor.processImage(
        pngBytes: pngBytes,
        screenName: screenName,
        screenSizes: screenSizes,
        imageQuality: imageQuality,
      );

      if (screenshots.isEmpty) {
        _handleError('Failed to process screenshots (list is empty)', onError);
        return false;
      }

      debugPrint(
          '📤 Processing ${screenshots.length} screenshots using mode: $shareMode');

      bool success = false;
      String? errorMessage;

      // 3. Share based on selected mode
      switch (shareMode) {
        case ShareMode.telegram:
          final zipBytes = await StorageService().createZipArchive(
            screenshots,
            'screenshot',
          );

          final result = await TelegramService().sendDocument(
            fileBytes: zipBytes,
            filename:
                '${screenName}_${DateTime.now().millisecondsSinceEpoch}.zip',
            caption: '📷 Screenshot Capture: $screenName',
          );

          success = result.success;
          if (!success) errorMessage = result.errorMessage;
          break;

        case ShareMode.localSave:
          final path =
              await StorageService().saveScreenshotsLocally(screenshots);
          success = path != null;
          if (!success) errorMessage = 'Failed to save to local storage';
          break;

        case ShareMode.shareWithApps:
          success = await StorageService().shareScreenshots(screenshots);
          if (!success) errorMessage = 'Failed to share with external apps';
          break;

        case ShareMode.multiple:
          // Default to Telegram + Local for multiple example
          final zipBytes = await StorageService().createZipArchive(
            screenshots,
            'screenshot',
          );
          final result = await TelegramService().sendDocument(
            fileBytes: zipBytes,
            filename:
                '${screenName}_${DateTime.now().millisecondsSinceEpoch}.zip',
          );
          success = result.success;
          if (!success) errorMessage = result.errorMessage;
          break;
      }

      if (success) {
        if (onSuccess != null) onSuccess();
      } else {
        _handleError(errorMessage ?? 'Unknown error during sharing', onError);
      }

      _isProcessing = false;
      return success;
    } catch (e, stack) {
      debugPrint('❌ ERROR capturing and sharing screen: $e');
      debugPrint(stack.toString());
      _handleError(e.toString(), onError);
      _isProcessing = false;
      return false;
    }
  }

  void _handleError(String message, Function(String)? onError) {
    debugPrint('❌ $message');
    _isProcessing = false;
    if (onError != null) onError(message);
  }
}
