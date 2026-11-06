import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_example/main.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

void main() {
  setUp(ScreenshotConfig.resetToDefaults);
  tearDown(ScreenshotConfig.resetToDefaults);

  testWidgets('demo renders wrapped in the dual-button wrapper',
      (tester) async {
    ScreenshotConfig.configure(
      shareMode: ShareMode.askUser,
      strings: ScreenshotStrings.ptBr,
      showButtonsInDebugOnly: false,
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Screenshot Demo'), findsOneWidget);
    expect(find.text('Capture esta tela!'), findsOneWidget);

    // The wrapper's capture and share buttons sit above the app content.
    expect(find.byType(DualButtonScreenshotWrapper), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('pending counter starts empty', (tester) async {
    await ScreenshotManagerService().clearScreenshots();

    ScreenshotConfig.configure(showButtonsInDebugOnly: false);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Pendentes: 0 variantes'), findsOneWidget);
  });
}
