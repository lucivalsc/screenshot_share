import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

/// Host that can flip the wrapper's button visibility at runtime.
class _ToggleHost extends StatefulWidget {
  const _ToggleHost();

  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          ElevatedButton(
            onPressed: () => setState(() => _visible = !_visible),
            child: const Text('toggle'),
          ),
          Expanded(
            child: ScreenshotWrapper(
              mostrarBotao: _visible,
              enableKeyboardShortcut: false,
              child: const Center(child: Text('conteúdo')),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(ScreenshotConfig.resetToDefaults);
  tearDown(ScreenshotConfig.resetToDefaults);

  group('ScreenshotWrapper', () {
    testWidgets('renders the child and the capture button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: Center(child: Text('conteúdo')),
          ),
        ),
      );

      expect(find.text('conteúdo'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('hides the button when asked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenshotWrapper(
            mostrarBotao: false,
            enableKeyboardShortcut: false,
            child: Center(child: Text('conteúdo')),
          ),
        ),
      );

      expect(find.text('conteúdo'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsNothing);
    });

    // In 0.1.4 the buttons lived in Overlay.initialEntries, read exactly once,
    // so toggling visibility at runtime had no effect at all.
    testWidgets('honours visibility changes at runtime', (tester) async {
      await tester.pumpWidget(const _ToggleHost());
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);

      await tester.tap(find.text('toggle'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.camera_alt), findsNothing);

      await tester.tap(find.text('toggle'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('exposes an accessible label and tooltip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenshotWrapper(
            enableKeyboardShortcut: false,
            strings: ScreenshotStrings.ptBr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, ScreenshotStrings.ptBr.captureButtonLabel);

      expect(
        find.bySemanticsLabel(ScreenshotStrings.ptBr.captureButtonLabel),
        findsWidgets,
      );
    });

    // The documented setup puts the wrapper in MaterialApp.builder, which is
    // above the Navigator that provides an Overlay. Tooltip asserts without
    // one, so the visual tooltip must be skipped there while the semantic
    // label stays.
    testWidgets('survives being mounted above the Navigator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ScreenshotWrapper(
            enableKeyboardShortcut: false,
            strings: ScreenshotStrings.ptBr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('conteúdo')),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('conteúdo'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, isNull, reason: 'tooltip sem Overlay quebraria');

      // Accessibility is unaffected.
      expect(
        find.bySemanticsLabel(ScreenshotStrings.ptBr.captureButtonLabel),
        findsWidgets,
      );
    });

    testWidgets('dual-button variant also survives above the Navigator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DualButtonScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('conteúdo')),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('does not install its own Overlay above the app',
        (tester) async {
      // The wrapper used to wrap the app in an extra Overlay, capturing
      // tooltips, menus and SnackBars meant for the app's own overlay.
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: Scaffold(body: Text('conteúdo')),
          ),
        ),
      );

      expect(find.byType(Stack), findsWidgets);
      // Only the Overlay that MaterialApp's Navigator provides.
      expect(find.byType(Overlay), findsOneWidget);
    });
  });

  group('DualButtonScreenshotWrapper', () {
    testWidgets('renders both buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DualButtonScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: Center(child: Text('conteúdo')),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('conteúdo'), findsOneWidget);
    });

    testWidgets('share button is disabled while nothing is pending',
        (tester) async {
      await ScreenshotManagerService().clearScreenshots();

      await tester.pumpWidget(
        const MaterialApp(
          home: DualButtonScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final shareFab = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.send),
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(shareFab.onPressed, isNull);
    });

    testWidgets('badge tracks the service notifier without polling',
        (tester) async {
      await ScreenshotManagerService().clearScreenshots();

      await tester.pumpWidget(
        const MaterialApp(
          home: DualButtonScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(ValueListenableBuilder<int>), findsOneWidget);

      // Nothing is scheduled: with 0.1.4's recursive Future.delayed loop this
      // would report pending timers for the lifetime of the widget.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('does not leave timers behind after dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DualButtonScreenshotWrapper(
            enableKeyboardShortcut: false,
            child: SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 5));
      // The test framework fails the test itself if a timer is still pending.
    });
  });
}
