/// Enum defining different device types for screenshot generation.
///
/// Each value maps to a set of portrait resolutions used to generate one image
/// variant per entry. Use [ScreenshotConfig.configure] with `deviceTypes` to
/// restrict generation to a subset.
enum DeviceType {
  /// Android devices (phones and tablets).
  android,

  /// iOS phones (iPhone).
  iphone,

  /// iOS tablets (iPad).
  ipad,

  /// macOS desktop.
  macos,

  /// Windows desktop.
  windows,

  /// Linux desktop.
  linux,
}
