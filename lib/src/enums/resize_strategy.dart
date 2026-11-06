/// Controls how a capture is fitted into each target [ScreenSize].
enum ResizeStrategy {
  /// Scales the capture to exactly the target size, ignoring its original
  /// aspect ratio. Fast, but distorts the image whenever the source and the
  /// target ratios differ.
  ///
  /// This was the only behaviour available up to version 0.1.4.
  stretch,

  /// Scales the capture down until it fits entirely inside the target size,
  /// preserving its aspect ratio and padding the remaining area with the
  /// configured background colour (letterbox / pillarbox).
  ///
  /// This is the default: it never distorts the image and is what app stores
  /// expect from submitted screenshots.
  fitContain,

  /// Scales the capture up until it covers the whole target size, preserving
  /// its aspect ratio, then centre-crops the overflow.
  ///
  /// No padding is added, but content near the edges may be cut off.
  fitCover,
}
