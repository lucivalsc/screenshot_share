// Serviço de captura de tela
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/screenshot_config.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_data.dart';
import '../widgets/screenshot_wrapper.dart';
import 'storage_service.dart';

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
  }) async {
    // Prevent multiple simultaneous operations
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final config = ScreenshotConfig();
      final screenName = customName ?? config.fileNamePrefix;
      final imageQuality = quality ?? config.imageQuality;
      final screenSizes = customSizes ?? config.screenSizes;
      final shareMode = overrideMode ?? config.shareMode;
      
      debugPrint('📸 Starting screen capture and share: "$screenName"...');

      // Get the RenderRepaintBoundary
      final renderObject = repaintKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        debugPrint('❌ Could not find RenderRepaintBoundary');
        _isProcessing = false;
        return false;
      }

      // Capture the image
      final boundary = renderObject as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('❌ Failed to get ByteData from image');
        _isProcessing = false;
        return false;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      debugPrint('📸 Captured image: ${pngBytes.length} bytes');

      // Decode the image
      final img.Image? decodedImage = img.decodePng(pngBytes);
      if (decodedImage == null) {
        debugPrint('❌ Failed to decode PNG image');
        _isProcessing = false;
        return false;
      }

      debugPrint('📸 Original image: ${decodedImage.width}x${decodedImage.height}');

      // Timestamp for this capture
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final captureId = '${screenName}_$timestamp';
      
      // Create list for screenshots
      List<ScreenshotData> screenshots = [];

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
          filename: '${screenName}_${timestamp}_${suffix}.jpg',
          width: width,
          height: height,
          group: captureId,
          timestamp: timestamp,
        );

        // Add to screenshots list
        screenshots.add(screenshot);
      }

      debugPrint('📤 Processing ${screenshots.length} screenshots using mode: $shareMode');

      bool success = false;
      
      // Process based on selected share mode
      switch (shareMode) {
        case ShareMode.telegram:
          // Create a ZIP with all images
          final zipBytes = await StorageService().createZipArchive(
            screenshots, 
            'screenshot',
          );
          
          // Send to Telegram
          success = await _sendToTelegram(zipBytes, 'screenshot');
          break;
          
        case ShareMode.localSave:
          // Save screenshots locally
          final path = await StorageService().saveScreenshotsLocally(screenshots);
          success = path != null;
          break;
          
        case ShareMode.shareWithApps:
          // Share with other apps
          success = await StorageService().shareScreenshots(screenshots);
          break;
          
        case ShareMode.multiple:
          // For demonstration, default to Telegram in multiple mode
          // In a real implementation, this would show a dialog for selection
          final zipBytes = await StorageService().createZipArchive(
            screenshots, 
            'screenshot',
          );
          success = await _sendToTelegram(zipBytes, 'screenshot');
          break;
      }

      _isProcessing = false;
      return success;
    } catch (e) {
      debugPrint('❌ ERROR capturing and sharing screen: $e');
      _isProcessing = false;
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
}