/// Enum defining different device types for screenshot generation.
///
/// Each value maps to a set of portrait resolutions used to generate one image
/// variant per entry. Use [ScreenshotConfig.configure] with `deviceTypes` to
/// restrict generation to a subset.
enum DeviceType {
  /// Android devices (phones and tablets).
  android,

  /// iOS phones (iPhone - all supported App Store portrait resolutions).
  iphone,

  /// iPhone with Dynamic Island (medium display: 6.1" and 6.3" - 1179x2556, 1206x2622).
  iphoneDynamicIsland,

  /// iPhone with large display (6.5", 6.7" and 6.9" - 1242x2688, 1284x2778, 1290x2796, 1320x2868).
  iphoneLarge,

  /// iOS tablets (iPad).
  ipad,

  /// macOS desktop.
  macos,

  /// Windows desktop.
  windows,

  /// Linux desktop.
  linux,
}
