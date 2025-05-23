# Flutter Screenshot Telegram

A Flutter package for capturing screenshots and sharing them via Telegram, local storage, or sharing with other apps.

[![pub package](https://img.shields.io/pub/v/screenshot_share_telegram.svg)](https://pub.dev/packages/screenshot_share_telegram)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ Capture screenshots of your app in Flutter
- ✅ Two operation modes: Single-button (immediate share) or Dual-button (capture & share separately)
- ✅ Multiple sharing options:
  - Send to Telegram via Bot API
  - Save to local storage 
  - Share with other apps using system share dialog
- ✅ Generate resized screenshots for various device dimensions
- ✅ No Navigator dependency - works with any widget structure
- ✅ Show capture buttons only in debug mode (configurable)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  screenshot_share_telegram: ^0.1.0
```

Then run:

```
$ flutter pub get
```

## Usage

### Configuration

First, configure the package with your Telegram credentials and preferences:

```dart
// In your main.dart file
void main() {
  // Configure the package (do this before runApp)
  ScreenshotConfig.configure(
    // Required for Telegram sharing mode
    telegramToken: 'YOUR_TELEGRAM_BOT_TOKEN',
    telegramChatId: 'YOUR_TELEGRAM_CHAT_ID',
    
    // Optional configuration
    shareMode: ShareMode.telegram, // Options: telegram, localSave, shareWithApps, multiple
    imageQuality: 90, // JPEG quality (0-100)
    fileNamePrefix: 'myapp', // Prefix for filenames
    showButtonsInDebugOnly: true, // Only show buttons in debug mode
  );
  
  runApp(const MyApp());
}
```

### Single-Button Mode

Capture and share screenshots immediately with a single button:

```dart
// Wrap your app with the ScreenshotService
return ScreenshotService.wrapScreen(
  child: YourApp(),
  showButton: true, // Show the capture button
  buttonPosition: Alignment.bottomRight, // Position of the button
  buttonColor: Colors.red.withOpacity(0.7), // Button color
);
```

### Dual-Button Mode

Capture multiple screenshots and share them later:

```dart
// Wrap your app with the ScreenshotManagerService
return ScreenshotManagerService.wrapScreen(
  child: YourApp(),
  showButtons: true, // Show both buttons
  buttonPosition: Alignment.bottomRight, // Position of buttons
  captureButtonColor: Colors.red.withOpacity(0.7), // Capture button color
  shareButtonColor: Colors.blue.withOpacity(0.7), // Share button color
);
```

### Change Share Mode at Runtime

You can change the share mode at runtime:

```dart
// Capture and share with a specific mode
await ScreenshotService().captureAndShare(
  repaintKey,
  overrideMode: ShareMode.shareWithApps,
);

// Or when using the manager service
await ScreenshotManagerService().processScreenshots(
  overrideMode: ShareMode.localSave,
);
```

### Custom Screen Sizes

Customize the screenshot sizes:

```dart
ScreenshotConfig.configure(
  screenSizes: [
    {'width': 1080, 'height': 1920, 'suffix': 'phone'},
    {'width': 2048, 'height': 2732, 'suffix': 'tablet'},
  ],
);
```

## Examples

### Toggle Between Single and Dual Button Modes

```dart
bool _useDualButtons = true;

@override
Widget build(BuildContext context) {
  Widget app = YourAppContent();
  
  if (_useDualButtons) {
    return ScreenshotManagerService.wrapScreen(child: app);
  } else {
    return ScreenshotService.wrapScreen(child: app);
  }
}
```

### Use Inside MaterialApp Builder

```dart
MaterialApp(
  // Use builder to wrap your entire app
  builder: (context, child) {
    return ScreenshotManagerService.wrapScreen(
      child: child ?? Container(),
    );
  },
  home: HomeScreen(),
);
```

## Requirements

For different sharing modes:

- **Telegram:** Valid bot token and chat ID
- **Local Save:** Storage permission (automatically requested)
- **Share with Apps:** No special requirements

## Permissions

Add these permissions to your app:

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to save screenshots to your photo library</string>
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.#