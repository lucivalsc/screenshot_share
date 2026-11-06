import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../config/screenshot_strings.dart';
import '../models/screenshot_result.dart';

/// A transient message rendered above the wrapped application.
@immutable
class ToastMessage {
  /// Text shown to the user and announced to screen readers.
  final String text;

  /// Background colour of the bubble.
  final Color color;

  /// Creates a toast message.
  const ToastMessage({required this.text, required this.color});
}

/// Toast state shared by both wrappers.
///
/// The message is rendered as a child of the wrapper's own [Stack] rather than
/// through an [OverlayEntry]. Up to version 0.1.4 each message scheduled an
/// uncancellable `Future.delayed` that removed whichever entry happened to be
/// current, so a second message was wiped out by the first one's timer.
mixin ScreenshotFeedbackMixin<T extends StatefulWidget> on State<T> {
  ToastMessage? _toast;
  Timer? _toastTimer;

  /// How long a message stays on screen.
  static const Duration toastDuration = Duration(seconds: 3);

  /// The message currently being shown, if any.
  ToastMessage? get currentToast => _toast;

  /// Shows [message], replacing any message still on screen.
  void showToast(String message, {required Color color}) {
    _toastTimer?.cancel();
    setState(() => _toast = ToastMessage(text: message, color: color));

    SemanticsService.announce(message, TextDirection.ltr);

    _toastTimer = Timer(toastDuration, () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  /// Cancels the pending timer. Call from `dispose`.
  void disposeFeedback() {
    _toastTimer?.cancel();
    _toastTimer = null;
  }

  /// Turns [result] into a user-facing message, or `null` when nothing should
  /// be shown (a busy result is not an error).
  ///
  /// This is where the diagnostic text produced by the services finally
  /// reaches the user; version 0.1.4 discarded it and always showed one of two
  /// fixed strings.
  ToastMessage? describeResult(
    ScreenshotResult result,
    ScreenshotStrings strings, {
    required bool isShare,
  }) {
    switch (result) {
      case ScreenshotBusy():
        return null;

      case ScreenshotCancelled():
        return ToastMessage(
          text: strings.shareCancelled,
          color: Colors.blueGrey.shade700,
        );

      case ScreenshotSuccess(location: final location):
        final text = location != null
            ? strings.savedToFor(location)
            : (isShare ? strings.shareSuccess : strings.captureSuccess);
        return ToastMessage(text: text, color: Colors.green.shade700);

      case ScreenshotFailure(message: final message):
        return ToastMessage(text: message, color: Colors.red.shade700);
    }
  }
}

/// Renders a [ToastMessage] near the bottom of the wrapped application.
class ScreenshotToast extends StatelessWidget {
  /// The message to render.
  final ToastMessage message;

  /// Creates a toast.
  const ScreenshotToast({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: message.color,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Text(
                message.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
