import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/screenshot_config.dart';
import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_result.dart';
import '../services/capture_pipeline.dart';
import '../services/screenshot_service.dart';
import 'feedback_overlay.dart';
import 'share_mode_sheet.dart';

/// Wraps an application with a single capture-and-share button.
class ScreenshotWrapper extends StatefulWidget {
  /// The widget to wrap (usually the whole application).
  final Widget child;

  /// Whether the capture button is shown.
  ///
  /// Unlike version 0.1.4, changing this at runtime now takes effect: the
  /// buttons live in a rebuilt [Stack] instead of an `Overlay`'s
  /// `initialEntries`, which were only ever read once.
  final bool mostrarBotao;

  /// Where the capture button sits.
  final AlignmentGeometry posicaoBotao;

  /// Colour of the capture button.
  final Color? corBotao;

  /// Destination used for the generated archive.
  final ShareMode shareMode;

  /// User-facing strings.
  final ScreenshotStrings strings;

  /// Whether `Ctrl`/`Cmd` + `Shift` + `S` triggers a capture.
  final bool enableKeyboardShortcut;

  /// Called with the typed outcome of every capture attempt.
  final ValueChanged<ScreenshotResult>? onResult;

  /// Creates a single-button screenshot wrapper.
  const ScreenshotWrapper({
    super.key,
    required this.child,
    this.mostrarBotao = true,
    this.posicaoBotao = Alignment.bottomRight,
    this.corBotao,
    this.shareMode = ShareMode.shareWithApps,
    this.strings = ScreenshotStrings.en,
    this.enableKeyboardShortcut = true,
    this.onResult,
  });

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

class _ScreenshotWrapperState extends State<ScreenshotWrapper>
    with ScreenshotFeedbackMixin<ScreenshotWrapper> {
  final GlobalKey _repaintKey = GlobalKey();

  bool _botaoVisivel = true;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableKeyboardShortcut) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    disposeFeedback();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;

    final keyboard = HardwareKeyboard.instance;
    final modifier = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (modifier &&
        keyboard.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      if (!_processando) _captureScreen();
      return true;
    }
    return false;
  }

  /// `Tooltip` asserts without an [Overlay] ancestor, and when the wrapper is
  /// installed through `MaterialApp.builder` it sits above the Navigator that
  /// provides one. The semantic label is always set, so screen readers work
  /// either way; the visual tooltip is added only where it is supported.
  bool get _tooltipsAvailable => Overlay.maybeOf(context) != null;

  @override
  Widget build(BuildContext context) {
    final toast = currentToast;

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          RepaintBoundary(key: _repaintKey, child: widget.child),
          if (widget.mostrarBotao)
            Positioned.fill(
              child: Align(
                alignment: widget.posicaoBotao,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Visibility(
                    visible: _botaoVisivel,
                    maintainState: true,
                    child: _buildCaptureButton(),
                  ),
                ),
              ),
            ),
          if (toast != null) ScreenshotToast(message: toast),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Semantics(
      button: true,
      enabled: !_processando,
      label: widget.strings.captureButtonLabel,
      child: Material(
        type: MaterialType.circle,
        color: Colors.transparent,
        child: FloatingActionButton(
          mini: true,
          tooltip:
              _tooltipsAvailable ? widget.strings.captureButtonLabel : null,
          backgroundColor: widget.corBotao ?? Colors.red.withValues(alpha: 0.7),
          onPressed: _processando ? null : _captureScreen,
          child: _processando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.camera_alt, size: 20),
        ),
      ),
    );
  }

  Future<void> _captureScreen() async {
    final pixelRatio = CapturePipeline.resolvePixelRatio(context);

    setState(() {
      _processando = true;
      _botaoVisivel = false;
    });

    // Wait for the frame that no longer paints the button, instead of
    // guessing with a fixed 300 ms delay as version 0.1.4 did.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final result = await ScreenshotService().captureAndShare(
      _repaintKey,
      pixelRatio: pixelRatio,
      overrideMode: widget.shareMode,
      modePicker: () => showShareModePicker(context, widget.strings),
    );

    if (!mounted) return;

    setState(() {
      _processando = false;
      _botaoVisivel = true;
    });

    widget.onResult?.call(result);

    final message = describeResult(result, widget.strings, isShare: true);
    if (message != null) {
      showToast(message.text, color: message.color);
    }
  }
}

/// Convenience wrapper that reads its defaults from [ScreenshotConfig].
///
/// Equivalent to [ScreenshotService.wrapScreen].
Widget wrapWithScreenshotButton({required Widget child}) =>
    ScreenshotService.wrapScreen(child: child);
