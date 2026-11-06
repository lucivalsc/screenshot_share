import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';
import '../models/screenshot_result.dart';
import '../services/capture_pipeline.dart';
import '../services/screenshot_manager_service.dart';
import 'feedback_overlay.dart';
import 'share_mode_sheet.dart';

/// Wraps an application with a capture button and a share button.
class DualButtonScreenshotWrapper extends StatefulWidget {
  /// The widget to wrap (usually the whole application).
  final Widget child;

  /// Whether the buttons are shown. Honoured on every rebuild.
  final bool mostrarBotoes;

  /// Where the buttons sit.
  final AlignmentGeometry posicaoBotoes;

  /// Colour of the capture button.
  final Color? corCapturarBotao;

  /// Colour of the share button.
  final Color? corEnviarBotao;

  /// Destination used for the generated archive.
  final ShareMode shareMode;

  /// User-facing strings.
  final ScreenshotStrings strings;

  /// Whether `Ctrl`/`Cmd` + `Shift` + `S` captures and `+ Shift + E` shares.
  final bool enableKeyboardShortcut;

  /// Called with the typed outcome of every capture attempt.
  final ValueChanged<ScreenshotResult>? onCaptureResult;

  /// Called with the typed outcome of every share attempt.
  final ValueChanged<ScreenshotResult>? onShareResult;

  /// Creates a dual-button screenshot wrapper.
  const DualButtonScreenshotWrapper({
    super.key,
    required this.child,
    this.mostrarBotoes = true,
    this.posicaoBotoes = Alignment.bottomRight,
    this.corCapturarBotao,
    this.corEnviarBotao,
    this.shareMode = ShareMode.shareWithApps,
    this.strings = ScreenshotStrings.en,
    this.enableKeyboardShortcut = true,
    this.onCaptureResult,
    this.onShareResult,
  });

  @override
  State<DualButtonScreenshotWrapper> createState() =>
      _DualButtonScreenshotWrapperState();
}

class _DualButtonScreenshotWrapperState
    extends State<DualButtonScreenshotWrapper>
    with ScreenshotFeedbackMixin<DualButtonScreenshotWrapper> {
  final GlobalKey _repaintKey = GlobalKey();
  final ScreenshotManagerService _service = ScreenshotManagerService();

  bool _botoesVisiveis = true;
  bool _capturando = false;
  bool _enviando = false;

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
    if (!modifier || !keyboard.isShiftPressed) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      if (!_capturando) _captureScreen();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      if (!_enviando && _service.storedCount.value > 0) _shareScreenshots();
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
          if (widget.mostrarBotoes)
            Positioned.fill(
              child: Align(
                alignment: widget.posicaoBotoes,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Visibility(
                    visible: _botoesVisiveis,
                    maintainState: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShareButton(),
                        const SizedBox(height: 8),
                        _buildCaptureButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (toast != null) ScreenshotToast(message: toast),
        ],
      ),
    );
  }

  /// The badge rebuilds from the service's [ValueNotifier]; version 0.1.4
  /// polled the count with `setState` once per second, rebuilding the entire
  /// application for the lifetime of the process.
  Widget _buildShareButton() {
    return ValueListenableBuilder<int>(
      valueListenable: _service.storedCount,
      builder: (context, count, _) {
        final enabled = !_enviando && count > 0;

        return Semantics(
          button: true,
          enabled: enabled,
          label: '${widget.strings.shareButtonLabel} — '
              '${widget.strings.pendingCapturesFor(count)}',
          child: Badge(
            backgroundColor:
                count > 0 ? Colors.green.shade700 : Colors.grey.shade700,
            label: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            isLabelVisible: count > 0,
            child: Material(
              type: MaterialType.circle,
              color: Colors.transparent,
              child: FloatingActionButton(
                mini: true,
                tooltip:
                    _tooltipsAvailable ? widget.strings.shareButtonLabel : null,
                backgroundColor:
                    widget.corEnviarBotao ?? Colors.blue.withValues(alpha: 0.7),
                onPressed: enabled ? _shareScreenshots : null,
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptureButton() {
    return Semantics(
      button: true,
      enabled: !_capturando,
      label: widget.strings.captureButtonLabel,
      child: Material(
        type: MaterialType.circle,
        color: Colors.transparent,
        child: FloatingActionButton(
          mini: true,
          tooltip:
              _tooltipsAvailable ? widget.strings.captureButtonLabel : null,
          backgroundColor:
              widget.corCapturarBotao ?? Colors.red.withValues(alpha: 0.7),
          onPressed: _capturando ? null : _captureScreen,
          child: _capturando
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
      _capturando = true;
      _botoesVisiveis = false;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final result = await _service.captureScreen(
      _repaintKey,
      pixelRatio: pixelRatio,
    );

    if (!mounted) return;

    setState(() {
      _capturando = false;
      _botoesVisiveis = true;
    });

    widget.onCaptureResult?.call(result);

    final message = describeResult(result, widget.strings, isShare: false);
    if (message != null) {
      showToast(message.text, color: message.color);
    }
  }

  Future<void> _shareScreenshots() async {
    setState(() => _enviando = true);

    final result = await _service.processScreenshots(
      overrideMode: widget.shareMode,
      modePicker: () => showShareModePicker(context, widget.strings),
    );

    if (!mounted) return;

    setState(() => _enviando = false);

    widget.onShareResult?.call(result);

    final message = describeResult(result, widget.strings, isShare: true);
    if (message != null) {
      showToast(message.text, color: message.color);
    }
  }
}
