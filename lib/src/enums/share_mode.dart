// Enum para modos de compartilhamento
/// Defines the available modes for sharing screenshots
enum ShareMode {
  /// Send screenshots to Telegram using bot API
  telegram,
  
  /// Save screenshots to local storage
  localSave,
  
  /// Share screenshots with other apps using share dialog
  shareWithApps,
  
  /// Multiple modes enabled - will show options dialog
  multiple,
}