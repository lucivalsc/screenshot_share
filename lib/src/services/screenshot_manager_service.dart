// Gerenciamento de capturas
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/screenshot_config.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_data.dart';
import '../widgets/dual_button_wrapper.dart';
import 'storage_service.dart';

/// Service for capturing, storing and sharing screenshots
class ScreenshotManagerService {
  // Singleton for global access
  static final ScreenshotManagerService _instance = ScreenshotManagerService._internal();
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

      // Get the RenderRepaintBoundary
      final renderObject = repaintKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        debugPrint('❌ Could not find RenderRepaintBoundary');
        _isCaptureProcessing = false;
        return false;
      }

      // Capture the image
      final boundary = renderObject;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('❌ Failed to get ByteData from image');
        _isCaptureProcessing = false;
        return false;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      debugPrint('📸 Captured image: ${pngBytes.length} bytes');

      // Decode the image
      final img.Image? decodedImage = img.decodePng(pngBytes);
      if (decodedImage == null) {
        debugPrint('❌ Failed to decode PNG image');
        _isCaptureProcessing = false;
        return false;
      }

      debugPrint('📸 Original image: ${decodedImage.width}x${decodedImage.height}');

      // Create a timestamp for this group of images
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final captureId = '${screenName}_$timestamp';

      // Create a list for this capture group
      final captureGroupList = <ScreenshotData>[];

      // Resize for all screen sizes
      debugPrint('📸 Resizing for ${screenSizes.length} different screen sizes...');

      for (int i = 0; i < screenSizes.length; i++) {
        final size = screenSizes[i];
        final width = size['width'] as int;
        final height = size['height'] as int;
        final suffix = size['suffix'] as String;

        debugPrint('📸 Resizing to $width x $height...');

        // Resize the image
        final resizedImage = img.copyResize(
          decodedImage,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
        );

        // Encode to JPEG
        final jpegBytes = img.encodeJpg(resizedImage, quality: imageQuality);

        debugPrint('📸 Image ${i + 1} resized: $width x $height (${jpegBytes.length} bytes)');

        // Create screenshot data object
        final screenshot = ScreenshotData(
          bytes: Uint8List.fromList(jpegBytes),
          filename: '${screenName}_${timestamp}_$suffix.jpg',
          width: width,
          height: height,
          group: captureId,
          timestamp: timestamp,
        );

        // Add to this group's list
        captureGroupList.add(screenshot);

        // Add to the main list of all screenshots
        _allScreenshots.add(screenshot);
      }

      // Store the group of captures
      _captureGroups[captureId] = captureGroupList;

      debugPrint(
          '📸 Stored ${screenSizes.length} images. Total: ${_allScreenshots.length} in ${_captureGroups.length} groups');

      _isCaptureProcessing = false;
      return true;
    } catch (e) {
      debugPrint('❌ ERROR capturing screen: $e');
      _isCaptureProcessing = false;
      return false;
    }
  }

  /// Process and share screenshots based on the configured share mode
  Future<bool> processScreenshots({
    ShareMode? overrideMode,
    bool clearAfterProcessing = true,
  }) async {
    // Prevent multiple simultaneous operations
    if (_isSendingProcessing) return false;
    _isSendingProcessing = true;

    try {
      if (_allScreenshots.isEmpty) {
        debugPrint('❌ No screenshots to process');
        _isSendingProcessing = false;
        return false;
      }

      final config = ScreenshotConfig();
      final shareMode = overrideMode ?? config.shareMode;

      debugPrint('📤 Processing ${_allScreenshots.length} screenshots using mode: $shareMode');

      bool success = false;

      // Process based on selected share mode
      switch (shareMode) {
        case ShareMode.telegram:
          // Create a ZIP with all images
          final zipBytes = await StorageService().createZipArchive(
            _allScreenshots,
            'screenshots',
          );

          // Send to Telegram
          success = await _sendToTelegram(zipBytes, 'screenshots');
          break;

        case ShareMode.localSave:
          // Save screenshots locally
          final path = await StorageService().saveScreenshotsLocally(_allScreenshots);
          success = path != null;
          break;

        case ShareMode.shareWithApps:
          // Share with other apps
          success = await StorageService().shareScreenshots(_allScreenshots);
          break;

        case ShareMode.multiple:
          // For demonstration, default to Telegram in multiple mode
          // In a real implementation, this would show a dialog for selection
          final zipBytes = await StorageService().createZipArchive(
            _allScreenshots,
            'screenshots',
          );
          success = await _sendToTelegram(zipBytes, 'screenshots');
          break;
      }

      // Clear stored screenshots if requested and successful
      if (clearAfterProcessing && success) {
        _captureGroups.clear();
        _allScreenshots.clear();
        debugPrint('🧹 Cleared screenshots after processing');
      }

      _isSendingProcessing = false;
      return success;
    } catch (e) {
      debugPrint('❌ ERROR processing screenshots: $e');
      _isSendingProcessing = false;
      return false;
    }
  }

  /// Send a ZIP file to Telegram
  Future<bool> _sendToTelegram(Uint8List zipBytes, String packageName) async {
    try {
      final config = ScreenshotConfig();

      if (!config.isTelegramConfigValid) {
        debugPrint('❌ Telegram configuration is not valid. Please set token and chatId.');
        return false;
      }

      debugPrint('📤 Sending ZIP to Telegram...');

      final url = 'https://api.telegram.org/bot${config.telegramToken}/sendDocument';

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['chat_id'] = config.telegramChatId
        ..files.add(
          http.MultipartFile.fromBytes(
            'document',
            zipBytes,
            filename: '${packageName}_${DateTime.now().millisecondsSinceEpoch}.zip',
          ),
        );

      final response = await request.send();
      final statusCode = response.statusCode;
      final responseText = await response.stream.bytesToString();

      debugPrint('📤 Response: $statusCode - $responseText');

      return statusCode >= 200 && statusCode < 300;
    } catch (e) {
      debugPrint('❌ Error sending to Telegram: $e');
      return false;
    }
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
