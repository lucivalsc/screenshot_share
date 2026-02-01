// Widget com dois botões para ações
import 'package:flutter/material.dart';

import '../enums/share_mode.dart';
import '../services/screenshot_manager_service.dart';

/// Widget wrapper that adds two buttons: one for capturing and one for sharing screenshots
class DualButtonScreenshotWrapper extends StatefulWidget {
  /// The child widget to wrap (usually your entire app)
  final Widget child;

  /// Whether to show the capture buttons
  final bool mostrarBotoes;

  /// Position of the capture buttons
  final AlignmentGeometry posicaoBotoes;

  /// Color of the capture button
  final Color? corCapturarBotao;

  /// Color of the share button
  final Color? corEnviarBotao;

  /// Mode for sharing screenshots
  final ShareMode shareMode;

  /// Creates a screenshot wrapper with capture and share buttons
  const DualButtonScreenshotWrapper({
    Key? key,
    required this.child,
    this.mostrarBotoes = true,
    this.posicaoBotoes = Alignment.bottomRight,
    this.corCapturarBotao,
    this.corEnviarBotao,
    this.shareMode = ShareMode.telegram,
  }) : super(key: key);

  @override
  State<DualButtonScreenshotWrapper> createState() =>
      _DualButtonScreenshotWrapperState();
}

class _DualButtonScreenshotWrapperState
    extends State<DualButtonScreenshotWrapper> {
  // Key for RepaintBoundary
  final GlobalKey _repaintKey = GlobalKey();

  // Button state
  bool _botoesVisiveis = true;
  bool _capturando = false;
  bool _enviando = false;

  // Screenshot counter (updated periodically)
  int _captureCount = 0;

  // Reference to service
  final _service = ScreenshotManagerService();

  // Overlay for messages
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // Update counter periodically
    _updateCounter();
  }

  void _updateCounter() {
    // Update counter only if mounted
    if (mounted) {
      setState(() {
        _captureCount = _service.storedScreenshotsCount;
      });

      // Schedule next update
      Future.delayed(const Duration(seconds: 1), _updateCounter);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        // First overlay entry: main content with RepaintBoundary
        OverlayEntry(
          builder: (context) => RepaintBoundary(
            key: _repaintKey,
            child: widget.child,
          ),
        ),

        // Second overlay entry: dual buttons
        if (widget.mostrarBotoes)
          OverlayEntry(
            builder: (context) => Align(
              alignment: widget.posicaoBotoes,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedOpacity(
                  opacity: _botoesVisiveis ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share button with badge showing count
                      Badge(
                        backgroundColor: _captureCount > 0
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                        label: Text('$_captureCount',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        isLabelVisible: _captureCount > 0,
                        child: Material(
                          type: MaterialType.circle,
                          color: Colors.transparent,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: widget.corEnviarBotao ??
                                Colors.blue.withValues(alpha: 0.7),
                            onPressed: (_enviando || _captureCount == 0)
                                ? null
                                : _shareScreenshots,
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

                      const SizedBox(height: 8),

                      // Capture button
                      Material(
                        type: MaterialType.circle,
                        color: Colors.transparent,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: widget.corCapturarBotao ??
                              Colors.red.withValues(alpha: 0.7),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Capture current screen
  Future<void> _captureScreen() async {
    setState(() {
      _capturando = true;
      _botoesVisiveis = false;
    });

    // Wait for button to disappear
    await Future.delayed(const Duration(milliseconds: 300));

    // Capture the screen
    final success = await _service.captureScreen(_repaintKey);

    // Update counter immediately
    if (mounted) {
      setState(() {
        _captureCount = _service.storedScreenshotsCount;
        _capturando = false;
        _botoesVisiveis = true;
      });
    }

    // Show result message
    if (mounted) {
      _showSimpleMessage(
        context,
        success ? "Screen captured!" : "Error capturing screen",
        success ? Colors.green.shade700 : Colors.red.shade700,
      );
    }
  }

  // Share captured screenshots
  Future<void> _shareScreenshots() async {
    setState(() {
      _enviando = true;
    });

    // Process and share screenshots
    final success = await _service.processScreenshots(
      overrideMode: widget.shareMode,
      clearAfterProcessing: true,
    );

    // Update counter immediately
    if (mounted) {
      setState(() {
        _captureCount = _service.storedScreenshotsCount;
        _enviando = false;
      });
    }

    // Show result message
    if (mounted) {
      _showSimpleMessage(
        context,
        success ? "Screenshots shared!" : "Error sharing screenshots",
        success ? Colors.green.shade700 : Colors.red.shade700,
      );
    }
  }

  // Show a simple message without relying on Navigator or Scaffold
  void _showSimpleMessage(BuildContext context, String message, Color? color) {
    // Remove any existing overlay
    _removeOverlay();

    // Get the overlay from the context

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 2), () {
      _removeOverlay();
    });
  }
}
