/// Defines the available modes for sharing a capture archive.
///
/// Every mode produces a single ZIP archive containing all generated image
/// variants — screenshots are never handed over as loose files.
enum ShareMode {
  /// Saves the ZIP archive to the device storage and reports the final path.
  localSave,

  /// Hands the ZIP archive to the native share sheet.
  shareWithApps,

  /// Asks the user which destination to use, then applies the chosen mode.
  ///
  /// Requires a widget context with a [Navigator] ancestor (the wrappers
  /// provide one automatically). When no picker is available the operation
  /// fails with [ScreenshotErrorKind.configuration].
  askUser,
}
