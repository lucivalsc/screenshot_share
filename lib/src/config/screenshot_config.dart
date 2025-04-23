// Configurações para captura de tela
import 'package:flutter/foundation.dart';
import '../enums/share_mode.dart';

/// Configuration class for the screenshot package
class ScreenshotConfig {
  // Singleton pattern
  static final ScreenshotConfig _instance = ScreenshotConfig._internal();
  factory ScreenshotConfig() => _instance;
  ScreenshotConfig._internal();

  /// Reset the configuration to default values
  static void resetToDefaults() {
    _instance._telegramToken = null;
    _instance._telegramChatId = null;
    _instance._imageQuality = 90;
    _instance._savePath = null;
    _instance._shareMode = ShareMode.telegram;
    _instance._screenSizes = _defaultScreenSizes;
    _instance._fileNamePrefix = 'screenshot';
    _instance._showButtonsInDebugOnly = true;
  }

  /// Configure the screenshot package with custom settings
  static void configure({
    String? telegramToken,
    String? telegramChatId,
    int? imageQuality,
    String? savePath,
    ShareMode? shareMode,
    List<Map<String, dynamic>>? screenSizes,
    String? fileNamePrefix,
    bool? showButtonsInDebugOnly,
  }) {
    if (telegramToken != null) _instance._telegramToken = telegramToken;
    if (telegramChatId != null) _instance._telegramChatId = telegramChatId;
    if (imageQuality != null) _instance._imageQuality = imageQuality;
    if (savePath != null) _instance._savePath = savePath;
    if (shareMode != null) _instance._shareMode = shareMode;
    if (screenSizes != null) _instance._screenSizes = screenSizes;
    if (fileNamePrefix != null) _instance._fileNamePrefix = fileNamePrefix;
    if (showButtonsInDebugOnly != null) _instance._showButtonsInDebugOnly = showButtonsInDebugOnly;
  }

  // Private fields with default values
  String? _telegramToken;
  String? _telegramChatId;
  int _imageQuality = 90;
  String? _savePath;
  ShareMode _shareMode = ShareMode.telegram;
  List<Map<String, dynamic>> _screenSizes = _defaultScreenSizes;
  String _fileNamePrefix = 'screenshot';
  bool _showButtonsInDebugOnly = true;

  // Default screen sizes for common mobile devices
  static const List<Map<String, dynamic>> _defaultScreenSizes = [
    {'width': 1080, 'height': 1920, 'suffix': '1080x1920'},
    {'width': 1440, 'height': 2560, 'suffix': '1440x2560'},
    {'width': 1242, 'height': 2688, 'suffix': '1242x2688'},
    {'width': 828, 'height': 1792, 'suffix': '828x1792'},
    {'width': 1125, 'height': 2436, 'suffix': '1125x2436'},
    {'width': 2048, 'height': 2732, 'suffix': '2048x2732'},
  ];

  /// The Telegram bot token
  String get telegramToken => _telegramToken ?? '';

  /// The Telegram chat ID
  String get telegramChatId => _telegramChatId ?? '';

  /// The image quality for JPEG compression (0-100)
  int get imageQuality => _imageQuality;

  /// Path for saving screenshots locally
  String? get savePath => _savePath;

  /// Share mode for screenshots
  ShareMode get shareMode => _shareMode;

  /// List of screen sizes to generate
  List<Map<String, dynamic>> get screenSizes => _screenSizes;

  /// Prefix for screenshot filenames
  String get fileNamePrefix => _fileNamePrefix;

  /// Show capture buttons only in debug mode
  bool get showButtonsInDebugOnly => _showButtonsInDebugOnly;

  /// Check if Telegram configuration is valid
  bool get isTelegramConfigValid =>
      _telegramToken != null && _telegramToken!.isNotEmpty && _telegramChatId != null && _telegramChatId!.isNotEmpty;

  /// Should the buttons be visible in the current build mode
  bool get shouldShowButtons => !_showButtonsInDebugOnly || kDebugMode;
}
