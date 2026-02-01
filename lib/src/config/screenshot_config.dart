// Configurações para captura de tela
import 'package:flutter/foundation.dart';
import '../enums/share_mode.dart';
import '../enums/device_type.dart';

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
    _instance._customScreenSizes = null;
    _instance._deviceTypes = {}; // Defaults to all if empty
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
    List<DeviceType>? deviceTypes,
    String? fileNamePrefix,
    bool? showButtonsInDebugOnly,
  }) {
    if (telegramToken != null) {
      _instance._telegramToken = telegramToken;
    }
    if (telegramChatId != null) {
      _instance._telegramChatId = telegramChatId;
    }
    if (imageQuality != null) {
      _instance._imageQuality = imageQuality;
    }
    if (savePath != null) {
      _instance._savePath = savePath;
    }
    if (shareMode != null) {
      _instance._shareMode = shareMode;
    }
    if (screenSizes != null) {
      _instance._customScreenSizes = screenSizes;
    }
    if (deviceTypes != null) {
      _instance._deviceTypes = deviceTypes.toSet();
    }
    if (fileNamePrefix != null) {
      _instance._fileNamePrefix = fileNamePrefix;
    }
    if (showButtonsInDebugOnly != null) {
      _instance._showButtonsInDebugOnly = showButtonsInDebugOnly;
    }
  }

  // Private fields with default values
  String? _telegramToken;
  String? _telegramChatId;
  int _imageQuality = 90;
  String? _savePath;
  ShareMode _shareMode = ShareMode.telegram;

  // Custom sizes provided raw by the user (overrides device types)
  List<Map<String, dynamic>>? _customScreenSizes;

  // Filter for specific device types
  Set<DeviceType> _deviceTypes = {};

  String _fileNamePrefix = 'screenshot';
  bool _showButtonsInDebugOnly = true;

  // Predefined screen sizes for different platforms
  static const Map<DeviceType, List<Map<String, dynamic>>> _deviceSizes = {
    DeviceType.android: [
      {'width': 1080, 'height': 1920, 'suffix': 'android_1080x1920'},
      {'width': 1440, 'height': 2560, 'suffix': 'android_1440x2560'},
    ],
    DeviceType.iphone: [
      {'width': 1242, 'height': 2688, 'suffix': 'iphone_6.5_disp'},
      {'width': 1284, 'height': 2778, 'suffix': 'iphone_6.7_disp'},
    ],
    DeviceType.ipad: [
      {'width': 2064, 'height': 2752, 'suffix': 'ipad_12.9_disp'},
      {'width': 2048, 'height': 2732, 'suffix': 'ipad_12.9_pro_2nd'},
    ],
    // Fallback or empty others for now
    DeviceType.macos: [],
    DeviceType.windows: [],
    DeviceType.linux: [],
  };

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
  List<Map<String, dynamic>> get screenSizes {
    // If user provided a specific list of maps, use it (highest priority)
    if (_customScreenSizes != null) {
      return _customScreenSizes!;
    }

    // If no specific device types selected, return all known mobile definitions (Android, iPhone, iPad)
    if (_deviceTypes.isEmpty) {
      final allSizes = <Map<String, dynamic>>[];
      _deviceSizes.forEach((key, value) {
        if (key == DeviceType.android ||
            key == DeviceType.iphone ||
            key == DeviceType.ipad) {
          allSizes.addAll(value);
        }
      });
      return allSizes;
    }

    // Return only selected types
    return _deviceTypes
        .expand((type) => _deviceSizes[type] ?? [])
        .toList()
        .cast<Map<String, dynamic>>();
  }

  /// Prefix for screenshot filenames
  String get fileNamePrefix => _fileNamePrefix;

  /// Show capture buttons only in debug mode
  bool get showButtonsInDebugOnly => _showButtonsInDebugOnly;

  /// Check if Telegram configuration is valid
  bool get isTelegramConfigValid =>
      _telegramToken != null &&
      _telegramToken!.isNotEmpty &&
      _telegramChatId != null &&
      _telegramChatId!.isNotEmpty;

  /// Should the buttons be visible in the current build mode
  bool get shouldShowButtons => !_showButtonsInDebugOnly || kDebugMode;
}
