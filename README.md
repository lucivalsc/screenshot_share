# Screenshot Share

A Flutter package for capturing screenshots of your app and delivering them as
a **single ZIP archive** — saved to the device or handed to the native share
sheet.

[![pub package](https://img.shields.io/pub/v/screenshot_share_telegram.svg)](https://pub.dev/packages/screenshot_share_telegram)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **Note on the package name.** The published name keeps its `_telegram`
> suffix for pub.dev compatibility, but **Telegram support was removed in
> 0.2.0**. The package no longer accepts, stores or transmits any credential.
> See [Why Telegram was removed](#why-telegram-was-removed).

## Features

- ✅ Capture any widget subtree, including your whole app
- ✅ Generate one resized variant per target device resolution
- ✅ **Aspect ratio preserved by default** — no stretched screenshots
- ✅ Every destination receives one ZIP archive, never loose files
- ✅ Two modes: single-button (capture and deliver) or dual-button (batch)
- ✅ Typed results with real diagnostic messages
- ✅ No credentials, no network calls, no runtime permissions
- ✅ Variants buffered on disk with configurable memory caps
- ✅ Localisable strings, screen-reader support, keyboard shortcuts
- ✅ Buttons restricted to debug builds (configurable)

## Installation

```yaml
dependencies:
  screenshot_share_telegram: ^0.2.0
```

```sh
flutter pub get
```

## Usage

### Configuration

```dart
void main() {
  ScreenshotConfig.configure(
    // Where the archive goes: localSave, shareWithApps or askUser
    shareMode: ShareMode.askUser,

    // Image pipeline
    imageQuality: 90,                             // JPEG quality, 1-100
    resizeStrategy: ResizeStrategy.fitContain,    // default; never distorts
    backgroundColor: const Color(0xFF000000),     // padding for fitContain
    pixelRatio: null,                             // null = derive from view

    // Which resolutions to generate
    deviceTypes: [DeviceType.android, DeviceType.iphone],

    // Naming and behaviour
    fileNamePrefix: 'myapp',
    showButtonsInDebugOnly: true,

    // Memory caps for the dual-button buffer
    maxStoredCaptures: 20,
    maxTotalBytes: 40 * 1024 * 1024,

    // Localisation
    strings: ScreenshotStrings.ptBr,
  );

  runApp(const MyApp());
}
```

Every argument is validated: an out-of-range value throws `ArgumentError` at
the call site instead of failing later inside the processing isolate.

### Single-button mode

Captures and delivers immediately:

```dart
MaterialApp(
  builder: (context, child) => ScreenshotService.wrapScreen(
    child: child ?? const SizedBox.shrink(),
    buttonPosition: Alignment.bottomRight,
    buttonColor: Colors.red,
    onResult: (result) => debugPrint('$result'),
  ),
  home: const HomeScreen(),
);
```

### Dual-button mode

Captures several screens, then delivers them all in one archive:

```dart
MaterialApp(
  builder: (context, child) => ScreenshotManagerService.wrapScreen(
    child: child ?? const SizedBox.shrink(),
    captureButtonColor: Colors.red,
    shareButtonColor: Colors.blue,
    onShareResult: (result) => debugPrint('$result'),
  ),
  home: const HomeScreen(),
);
```

> Wrap inside `MaterialApp.builder` rather than above `MaterialApp`:
> `ShareMode.askUser` needs a `Navigator` ancestor to host its picker.

### Handling results

Public operations return a `ScreenshotResult`, so you can tell a real failure
from "an operation is already running":

```dart
final result = await ScreenshotManagerService().processScreenshots();

switch (result) {
  case ScreenshotSuccess(count: final n, location: final path):
    // `location` is non-null only for localSave
    showInfo(path == null ? 'Shared $n images' : 'Saved to $path');

  case ScreenshotBusy():
    break; // Not an error — do not show one

  case ScreenshotCancelled():
    showInfo('Cancelled');

  case ScreenshotFailure(kind: final kind, message: final message):
    if (kind == ScreenshotErrorKind.bufferFull) {
      showWarning(message);
    } else {
      showError(message);
    }
}
```

`ScreenshotErrorKind` covers `configuration`, `noRenderBoundary`, `encoding`,
`processing`, `storage`, `permission`, `bufferFull`, `noData` and `unknown`.

### Resize strategies

| Strategy | Behaviour | Use when |
|---|---|---|
| `fitContain` *(default)* | Scales to fit, pads with `backgroundColor` | App-store screenshots; never distorts |
| `fitCover` | Scales to cover, centre-crops the overflow | You want a full-bleed frame |
| `stretch` | Scales to the exact target, ignoring aspect ratio | Compatibility with 0.1.x output |

### Custom resolutions

```dart
ScreenshotConfig.configure(
  screenSizes: [
    ScreenSize(width: 1080, height: 1920, suffix: 'phone'),
    ScreenSize(width: 2048, height: 2732, suffix: 'tablet'),
  ],
);
```

Migrating from the 0.1.x map format:

```dart
ScreenshotConfig.configure(
  screenSizes: ScreenshotConfig.screenSizesFromMaps([
    {'width': 1080, 'height': 1920, 'suffix': 'phone'},
  ]),
);
```

### Keyboard shortcuts

Enabled by default (`enableKeyboardShortcut: true`):

| Shortcut | Action |
|---|---|
| `Ctrl` / `Cmd` + `Shift` + `S` | Capture |
| `Ctrl` / `Cmd` + `Shift` + `E` | Share (dual-button mode) |

### Localisation

```dart
// Built-in tables
ScreenshotConfig.configure(strings: ScreenshotStrings.ptBr);

// Partial override
ScreenshotConfig.configure(
  strings: ScreenshotStrings.en.copyWith(
    captureButtonLabel: 'Grab this screen',
  ),
);
```

## Where files end up

| Mode | Destination |
|---|---|
| `localSave` | `savePath` if set, otherwise the app's external/documents directory (Android/iOS) or the downloads directory (desktop). The final path is returned in `ScreenshotSuccess.location`. |
| `shareWithApps` | A temporary ZIP handed to the native share sheet; the user picks the target. |
| `askUser` | A bottom sheet lets the user choose between the two above. |

## Permissions

**None.** The default destinations are directories your app can always write
to, so no runtime permission is requested on any platform.

> Versions up to 0.1.4 requested `Permission.storage`, which has been
> obsolete since Android 13 (API 33) and is permanently denied there — for a
> directory that never required it. That made local saving fail on most
> Android devices in circulation. If you follow an older README and declare
> `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE`, you can remove them.

If you set a custom `savePath`, it must be writable by your app without extra
permissions; otherwise the operation fails with
`ScreenshotErrorKind.permission` and an actionable message.

To let the user file the archive anywhere on the device, use
`ShareMode.shareWithApps` — the native sheet handles that without permissions.

## Memory behaviour

Variants are written to the cache directory and referenced by path, so a
pending batch costs a few dozen bytes of heap per image instead of its full
size. Two caps protect the buffer:

- `maxStoredCaptures` (default 20) — number of capture groups
- `maxTotalBytes` (default 40 MB) — total size on disk

Exceeding either fails with `ScreenshotErrorKind.bufferFull` and rolls the
capture back. Temporary artefacts older than 24 hours are cleaned up
automatically via `StorageService.cleanupTemporaryArtifacts()`.

## Why Telegram was removed

Up to 0.1.4 the package required a Telegram Bot Token through
`ScreenshotConfig.configure()`. In practice — and as the README then showed —
that token ended up hardcoded in the consuming app's `main.dart`. With
`showButtonsInDebugOnly: false` the package stayed active in release builds,
embedding the token in the shipped binary where it is recoverable with
`strings` on the APK/IPA. The token also formed part of the request URL,
exposing it to any proxy or traffic capture.

A credential that leaks grants control of the bot, so the feature was removed
rather than patched. If you need automated delivery, do it in your own app,
with the secret under your control, consuming `ScreenshotData` through the
public API.

## Example

A runnable demo lives in [`example/`](example):

```sh
cd example
flutter pub get
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
