import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../enums/device_type.dart';
import '../enums/resize_strategy.dart';
import '../enums/share_mode.dart';
import '../models/screen_size.dart';
import '../utils/file_name_sanitizer.dart';
import 'screenshot_strings.dart';

/// Global configuration for the screenshot package.
///
/// Every setter validates its input and throws [ArgumentError] on invalid
/// values, so a configuration mistake fails at the call site instead of
/// surfacing three layers down as an empty variant list.
class ScreenshotConfig {
  static final ScreenshotConfig _instance = ScreenshotConfig._internal();

  /// Returns the singleton configuration instance.
  factory ScreenshotConfig() => _instance;

  ScreenshotConfig._internal();

  // ---------------------------------------------------------------- defaults

  /// Default JPEG quality.
  static const int defaultImageQuality = 90;

  /// Default maximum number of capture groups held before sharing.
  static const int defaultMaxStoredCaptures = 20;

  /// Default maximum total size on disk of pending captures, in bytes.
  static const int defaultMaxTotalBytes = 40 * 1024 * 1024;

  /// Lower bound applied to the capture pixel ratio.
  static const double minPixelRatio = 1.0;

  /// Upper bound applied to the capture pixel ratio, guarding against huge
  /// intermediate bitmaps on high-density tablets.
  static const double maxPixelRatio = 3.0;

  // ------------------------------------------------------------------ fields

  int _imageQuality = defaultImageQuality;
  String? _savePath;
  ShareMode _shareMode = ShareMode.shareWithApps;
  List<ScreenSize>? _customScreenSizes;
  Set<DeviceType> _deviceTypes = const {};
  String _fileNamePrefix = 'screenshot';
  bool _showButtonsInDebugOnly = true;
  ResizeStrategy _resizeStrategy = ResizeStrategy.fitContain;
  Color _backgroundColor = const Color(0xFF000000);
  double? _pixelRatio;
  int _maxStoredCaptures = defaultMaxStoredCaptures;
  int _maxTotalBytes = defaultMaxTotalBytes;
  ScreenshotStrings _strings = ScreenshotStrings.en;

  /// Portrait resolutions generated for each device type.
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
    DeviceType.macos: [
      {'width': 1280, 'height': 800, 'suffix': 'macos_1280x800'},
      {'width': 2560, 'height': 1600, 'suffix': 'macos_2560x1600'},
    ],
    DeviceType.windows: [
      {'width': 1366, 'height': 768, 'suffix': 'windows_1366x768'},
      {'width': 1920, 'height': 1080, 'suffix': 'windows_1920x1080'},
    ],
    DeviceType.linux: [
      {'width': 1366, 'height': 768, 'suffix': 'linux_1366x768'},
      {'width': 1920, 'height': 1080, 'suffix': 'linux_1920x1080'},
    ],
  };

  /// Device types included when no explicit filter is configured.
  static const Set<DeviceType> _defaultDeviceTypes = {
    DeviceType.android,
    DeviceType.iphone,
    DeviceType.ipad,
  };

  // ------------------------------------------------------------------- setup

  /// Restores every setting to its default value.
  ///
  /// Call this from `setUp` in tests: the configuration is a process-wide
  /// singleton, so leaving state behind makes a suite order-dependent.
  static void resetToDefaults() {
    _instance
      .._imageQuality = defaultImageQuality
      .._savePath = null
      .._shareMode = ShareMode.shareWithApps
      .._customScreenSizes = null
      .._deviceTypes = const {}
      .._fileNamePrefix = 'screenshot'
      .._showButtonsInDebugOnly = true
      .._resizeStrategy = ResizeStrategy.fitContain
      .._backgroundColor = const Color(0xFF000000)
      .._pixelRatio = null
      .._maxStoredCaptures = defaultMaxStoredCaptures
      .._maxTotalBytes = defaultMaxTotalBytes
      .._strings = ScreenshotStrings.en;
  }

  /// Configures the package. Only the supplied arguments are changed.
  ///
  /// Throws [ArgumentError] when a value is outside its valid range.
  static void configure({
    int? imageQuality,
    String? savePath,
    ShareMode? shareMode,
    List<ScreenSize>? screenSizes,
    List<DeviceType>? deviceTypes,
    String? fileNamePrefix,
    bool? showButtonsInDebugOnly,
    ResizeStrategy? resizeStrategy,
    Color? backgroundColor,
    double? pixelRatio,
    int? maxStoredCaptures,
    int? maxTotalBytes,
    ScreenshotStrings? strings,
  }) {
    if (imageQuality != null) {
      if (imageQuality < 1 || imageQuality > 100) {
        throw ArgumentError.value(
          imageQuality,
          'imageQuality',
          'Deve estar entre 1 e 100',
        );
      }
      _instance._imageQuality = imageQuality;
    }

    if (savePath != null) {
      if (savePath.trim().isEmpty) {
        throw ArgumentError.value(
          savePath,
          'savePath',
          'Não pode ser vazio; use null para o destino padrão',
        );
      }
      _instance._savePath = savePath;
    }

    if (shareMode != null) {
      _instance._shareMode = shareMode;
    }

    if (screenSizes != null) {
      if (screenSizes.isEmpty) {
        throw ArgumentError.value(
          screenSizes,
          'screenSizes',
          'Não pode ser vazio; use null para usar os tamanhos padrão',
        );
      }
      _instance._customScreenSizes = List.unmodifiable(screenSizes);
    }

    if (deviceTypes != null) {
      if (deviceTypes.isEmpty) {
        throw ArgumentError.value(
          deviceTypes,
          'deviceTypes',
          'Não pode ser vazio; use null para incluir todos os tipos móveis',
        );
      }
      _instance._deviceTypes = deviceTypes.toSet();
    }

    if (fileNamePrefix != null) {
      _instance._fileNamePrefix = sanitizeFileNameComponent(
        fileNamePrefix,
        fallback: 'screenshot',
      );
    }

    if (showButtonsInDebugOnly != null) {
      _instance._showButtonsInDebugOnly = showButtonsInDebugOnly;
    }

    if (resizeStrategy != null) {
      _instance._resizeStrategy = resizeStrategy;
    }

    if (backgroundColor != null) {
      _instance._backgroundColor = backgroundColor;
    }

    if (pixelRatio != null) {
      if (pixelRatio < minPixelRatio || pixelRatio > maxPixelRatio) {
        throw ArgumentError.value(
          pixelRatio,
          'pixelRatio',
          'Deve estar entre $minPixelRatio e $maxPixelRatio',
        );
      }
      _instance._pixelRatio = pixelRatio;
    }

    if (maxStoredCaptures != null) {
      if (maxStoredCaptures < 1) {
        throw ArgumentError.value(
          maxStoredCaptures,
          'maxStoredCaptures',
          'Deve ser pelo menos 1',
        );
      }
      _instance._maxStoredCaptures = maxStoredCaptures;
    }

    if (maxTotalBytes != null) {
      if (maxTotalBytes < 1024) {
        throw ArgumentError.value(
          maxTotalBytes,
          'maxTotalBytes',
          'Deve ser pelo menos 1024 bytes',
        );
      }
      _instance._maxTotalBytes = maxTotalBytes;
    }

    if (strings != null) {
      _instance._strings = strings;
    }
  }

  /// Converts the legacy `List<Map<String, dynamic>>` size format into
  /// validated [ScreenSize] instances.
  ///
  /// Provided to ease migration from 0.1.x, where sizes were untyped maps.
  static List<ScreenSize> screenSizesFromMaps(
    List<Map<String, dynamic>> maps,
  ) =>
      maps.map(ScreenSize.fromMap).toList(growable: false);

  // ----------------------------------------------------------------- getters

  /// JPEG quality used when encoding variants (1-100).
  int get imageQuality => _imageQuality;

  /// Custom destination directory for saved archives, when configured.
  ///
  /// The directory must be writable by the app without extra OS permissions.
  String? get savePath => _savePath;

  /// Destination used when no override is supplied.
  ShareMode get shareMode => _shareMode;

  /// How captures are fitted into each target resolution.
  ResizeStrategy get resizeStrategy => _resizeStrategy;

  /// Padding colour used by [ResizeStrategy.fitContain].
  Color get backgroundColor => _backgroundColor;

  /// Explicit capture pixel ratio, or `null` to derive it from the view.
  double? get pixelRatio => _pixelRatio;

  /// Maximum number of capture groups held before sharing.
  int get maxStoredCaptures => _maxStoredCaptures;

  /// Maximum total size on disk of pending captures, in bytes.
  int get maxTotalBytes => _maxTotalBytes;

  /// The active string table.
  ScreenshotStrings get strings => _strings;

  /// Sanitised prefix used for generated filenames.
  String get fileNamePrefix => _fileNamePrefix;

  /// Whether the overlay buttons are restricted to debug builds.
  bool get showButtonsInDebugOnly => _showButtonsInDebugOnly;

  /// Whether the overlay buttons should be visible in the current build mode.
  bool get shouldShowButtons => !_showButtonsInDebugOnly || kDebugMode;

  /// Resolved list of target resolutions.
  ///
  /// Precedence: explicit `screenSizes` > `deviceTypes` filter > the default
  /// mobile set. Throws [StateError] when the resolution is empty, instead of
  /// letting the failure surface later as an empty variant list.
  List<ScreenSize> get screenSizes {
    final custom = _customScreenSizes;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }

    final types = _deviceTypes.isEmpty ? _defaultDeviceTypes : _deviceTypes;
    final resolved = <ScreenSize>[
      for (final type in types) ...?_deviceSizes[type]?.map(ScreenSize.fromMap),
    ];

    if (resolved.isEmpty) {
      throw StateError(
        'Nenhuma resolução disponível para deviceTypes='
        '${types.map((t) => t.name).join(', ')}. '
        'Informe "screenSizes" explicitamente em ScreenshotConfig.configure().',
      );
    }

    return List.unmodifiable(resolved);
  }

  /// Resolutions known for [type].
  static List<ScreenSize> sizesForDeviceType(DeviceType type) =>
      (_deviceSizes[type] ?? const []).map(ScreenSize.fromMap).toList();

  /// Clamps [ratio] to the supported capture range.
  static double clampPixelRatio(double ratio) =>
      ratio.clamp(minPixelRatio, maxPixelRatio);
}
