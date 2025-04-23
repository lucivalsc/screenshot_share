// Widget que encapsula a lógica de screenshot
import 'package:flutter/material.dart';

import '../enums/share_mode.dart';
import '../services/screenshot_service.dart';

/// Widget wrapper that adds a single button for capturing and sharing screenshots
class ScreenshotWrapper extends StatefulWidget {
  /// The child widget to wrap (usually your entire app)
  final Widget child;

  /// Whether to show the capture button
  final bool mostrarBotao;

  /// Position of the capture button
  final AlignmentGeometry posicaoBotao;

  /// Color of the capture button
  final Color? corBotao;

  /// Mode for sharing screenshots
  final ShareMode shareMode;

  /// Creates a screenshot wrapper with a single capture button
  const ScreenshotWrapper({
    Key? key,
    required this.child,
    this.mostrarBotao = true,
    this.posicaoBotao = Alignment.bottomRight,
    this.corBotao,
    this.shareMode = ShareMode.telegram,
  }) : super(key: key);

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  // Key for RepaintBoundary
  final GlobalKey _repaintKey = GlobalKey();

  // Button state
  bool _botaoVisivel = true;
  bool _processando = false;

  // Overlay for messages
  OverlayEntry? _overlayEntry;

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

        // Second overlay entry: capture button
        if (widget.mostrarBotao)
          OverlayEntry(
            builder: (context) => Align(
              alignment: widget.posicaoBotao,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedOpacity(
                  opacity: _botaoVisivel ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Material(
                    type: MaterialType.circle,
                    color: Colors.transparent,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: widget.corBotao ?? Colors.red.withOpacity(0.7),
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
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Capture and share screen
  Future<void> _captureScreen() async {
    setState(() {
      _processando = true;
      _botaoVisivel = false;
    });

    // Wait for button to disappear
    await Future.delayed(const Duration(milliseconds: 300));

    // Capture and share the screen
    final success = await ScreenshotService().captureAndShare(
      _repaintKey,
      overrideMode: widget.shareMode,
    );

    if (mounted) {
      setState(() {
        _processando = false;
        _botaoVisivel = true;
      });
    }

    // Show result message
    if (mounted) {
      _showSimpleMessage(
        context,
        success ? "Screenshot shared!" : "Error sharing screenshot",
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
                color: color ?? Colors.black.withOpacity(0.7),
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
