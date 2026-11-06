import 'package:flutter/material.dart';

import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';

/// Asks the user where the capture archive should go.
///
/// Implements what [ShareMode.askUser] promises. Up to version 0.1.4 the
/// equivalent mode (`ShareMode.multiple`) documented an options dialog but
/// silently sent to a single hardcoded destination instead.
///
/// Returns the chosen mode, or `null` when the user cancels or when no
/// [Navigator] is available in [context].
Future<ShareMode?> showShareModePicker(
  BuildContext context,
  ScreenshotStrings strings,
) async {
  if (Navigator.maybeOf(context) == null) {
    // Without a Navigator there is nowhere to host the sheet. The caller
    // turns this into a configuration failure with an actionable message.
    return null;
  }

  return showModalBottomSheet<ShareMode>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              strings.chooseDestination,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(strings.destinationLocalSave),
            onTap: () => Navigator.of(sheetContext).pop(ShareMode.localSave),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(strings.destinationShareWithApps),
            onTap: () =>
                Navigator.of(sheetContext).pop(ShareMode.shareWithApps),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(strings.cancel),
            onTap: () => Navigator.of(sheetContext).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
