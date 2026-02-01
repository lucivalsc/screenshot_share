// Gerenciamento de capturas
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/screenshot_config.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_data.dart';
import '../widgets/dual_button_wrapper.dart';
import 'storage_service.dart';
import '../utils/image_processor.dart';
import 'telegram_service.dart';

/// Service for capturing, storing and sharing screenshots
class ScreenshotManagerService {
  // Singleton for global access
  static final ScreenshotManagerService _instance =
      ScreenshotManagerService._internal();
  factory ScreenshotManagerService() => _instance;
  ScreenshotManagerService._internal();

  // List to store captured screenshots by groups
  final Map<String, List<ScreenshotData>> _captureGroups = {};

  // List of all screenshots
  final List<ScreenshotData> _allScreenshots = [];

  // Processing status
  bool _isCaptureProcessing = false;
  bool _isSendingProcessing = false;

  // Public accessors
  int get storedScreenshotsCount => _allScreenshots.length;
  int get captureGroupsCount => _captureGroups.length;
  bool get isProcessing => _isCaptureProcessing || _isSendingProcessing;

  /// Create a widget that wraps the entire app with screenshot capture functionality
  static Widget wrapScreen({
    required Widget child,
    bool? showButtons,
    AlignmentGeometry? buttonPosition,
    Color? captureButtonColor,
    Color? shareButtonColor,
    ShareMode? overrideShareMode,
  }) {
    final config = ScreenshotConfig();

    return DualButtonScreenshotWrapper(
      mostrarBotoes: showButtons ?? config.shouldShowButtons,
      posicaoBotoes: buttonPosition ?? Alignment.bottomRight,
      corCapturarBotao: captureButtonColor ?? Colors.red.withOpacity(0.7),
      corEnviarBotao: shareButtonColor ?? Colors.blue.withOpacity(0.7),
      shareMode: overrideShareMode ?? config.shareMode,
      child: child,
    );
  }

  /// Capture the current screen and store it locally
  Future<bool> captureScreen(
    GlobalKey repaintKey, {
    String? customName,
    int? quality,
    List<Map<String, dynamic>>? customSizes,
    Function(String error)? onError,
  }) async {
    // Prevent multiple simultaneous captures
    if (_isCaptureProcessing) return false;
    _isCaptureProcessing = true;

    try {
      final config = ScreenshotConfig();
      final screenName = customName ?? config.fileNamePrefix;
      final imageQuality = quality ?? config.imageQuality;
      final screenSizes = customSizes ?? config.screenSizes;

      debugPrint('📸 Starting screen capture: "$screenName"...');

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

      // 3. Store results
      // Create a timestamp for this group of images (using the one from the first screenshot or now)
      final captureId = screenshots.first.group;

      // Store the group of captures
      _captureGroups[captureId] = screenshots;

      // Add to the main list of all screenshots
      _allScreenshots.addAll(screenshots);

      debugPrint(
          '📸 Stored ${screenSizes.length} images. Total: ${_allScreenshots.length} in ${_captureGroups.length} groups');

      _isCaptureProcessing = false;
      return true;
    } catch (e) {
      debugPrint('❌ ERROR capturing screen: $e');
      _handleError(e.toString(), onError);
      _isCaptureProcessing = false;
      return false;
    }
  }

  /// Process and share screenshots based on the configured share mode
  Future<bool> processScreenshots({
    ShareMode? overrideMode,
    bool clearAfterProcessing = true,
    Function(String error)? onError,
    Function()? onSuccess,
  }) async {
    // Prevent multiple simultaneous operations
    if (_isSendingProcessing) return false;
    _isSendingProcessing = true;

    try {
      if (_allScreenshots.isEmpty) {
        _handleSendingError('No screenshots to process', onError);
        return false;
      }

      final config = ScreenshotConfig();
      final shareMode = overrideMode ?? config.shareMode;

      debugPrint(
          '📤 Processing ${_allScreenshots.length} screenshots using mode: $shareMode');

      bool success = false;
      String? errorMessage;

      // Process based on selected share mode
      switch (shareMode) {
        case ShareMode.telegram:
          final zipBytes = await StorageService().createZipArchive(
            _allScreenshots,
            'screenshots',
          );

          final result = await TelegramService().sendDocument(
            fileBytes: zipBytes,
            filename:
                'screenshots_${DateTime.now().millisecondsSinceEpoch}.zip',
            caption: '📷 Bundle of ${_allScreenshots.length} screenshots',
          );

          success = result.success;
          if (!success) errorMessage = result.errorMessage;
          break;

        case ShareMode.localSave:
          final path =
              await StorageService().saveScreenshotsLocally(_allScreenshots);
          success = path != null;
          if (!success) errorMessage = 'Failed to save to local storage';
          break;

        case ShareMode.shareWithApps:
          success = await StorageService().shareScreenshots(_allScreenshots);
          if (!success) errorMessage = 'Failed to share with external apps';
          break;

        case ShareMode.multiple:
          final zipBytes = await StorageService().createZipArchive(
            _allScreenshots,
            'screenshots',
          );
          final result = await TelegramService().sendDocument(
            fileBytes: zipBytes,
            filename:
                'screenshots_${DateTime.now().millisecondsSinceEpoch}.zip',
          );
          success = result.success;
          if (!success) errorMessage = result.errorMessage;
          break;
      }

      // Clear stored screenshots if requested and successful
      if (clearAfterProcessing && success) {
        _captureGroups.clear();
        _allScreenshots.clear();
        debugPrint('🧹 Cleared screenshots after processing');
      }

      if (success) {
        if (onSuccess != null) onSuccess();
      } else {
        _handleSendingError(errorMessage ?? 'Unknown error', onError);
      }

      _isSendingProcessing = false;
      return success;
    } catch (e) {
      debugPrint('❌ ERROR processing screenshots: $e');
      _handleSendingError(e.toString(), onError);
      _isSendingProcessing = false;
      return false;
    }
  }

  void _handleError(String message, Function(String)? onError) {
    debugPrint('❌ $message');
    _isCaptureProcessing = false;
    if (onError != null) onError(message);
  }

  void _handleSendingError(String message, Function(String)? onError) {
    debugPrint('❌ $message');
    _isSendingProcessing = false;
    if (onError != null) onError(message);
  }

  /// Clear all stored screenshots
  void clearScreenshots() {
    _captureGroups.clear();
    _allScreenshots.clear();
    debugPrint('🧹 All screenshots cleared');
  }

  /// Get all stored screenshots
  List<ScreenshotData> getAllScreenshots() {
    return List.unmodifiable(_allScreenshots);
  }

  /// Get screenshots for a specific group
  List<ScreenshotData> getScreenshotsForGroup(String groupId) {
    return List.unmodifiable(_captureGroups[groupId] ?? []);
  }

  /// Get all group IDs
  List<String> getAllGroupIds() {
    return List.unmodifiable(_captureGroups.keys);
  }
}
