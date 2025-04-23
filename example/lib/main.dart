// Exemplo de uso do pacote
import 'package:flutter/material.dart';
import 'package:screenshot_share/screenshot_share.dart';

void main() {
  // Configure the screenshot package
  ScreenshotConfig.configure(
    telegramToken: '',
    telegramChatId: '',
    shareMode: ShareMode.multiple,
    imageQuality: 90,
    showButtonsInDebugOnly: false, // Show in all build modes for the example
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screenshot Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Toggle between single and dual button modes
  bool _useDualButtons = true;

  @override
  Widget build(BuildContext context) {
    // Using wrapper in the build method for dynamic toggling
    Widget content = Scaffold(
      appBar: AppBar(
        title: const Text('Screenshot Demo'),
        actions: [
          // Toggle button
          IconButton(
            icon: Icon(_useDualButtons ? Icons.filter_1 : Icons.filter_2),
            onPressed: () {
              setState(() {
                _useDualButtons = !_useDualButtons;
              });
            },
            tooltip: _useDualButtons ? 'Switch to single button mode' : 'Switch to dual button mode',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mode indicator
            Text(
              _useDualButtons
                  ? 'Dual Button Mode\n(Capture + Share)'
                  : 'Single Button Mode\n(Capture & Share immediately)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Share mode explanation
            Text(
              'Current share mode: ${ScreenshotConfig().shareMode}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),

            // Colorful content to screenshot
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(5, 5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Take a screenshot of me!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Instructions
            const Text('Use the buttons in the bottom-right corner\nto capture screenshots'),
          ],
        ),
      ),
    );

    // Wrap with appropriate screenshot wrapper based on mode
    if (_useDualButtons) {
      // Dual button mode - Can capture multiple screenshots and send them later
      return ScreenshotManagerService.wrapScreen(
        child: content,
        showButtons: true,
        buttonPosition: Alignment.bottomRight,
        captureButtonColor: Colors.red,
        shareButtonColor: Colors.blue,
      );
    } else {
      // Single button mode - Captures and shares immediately
      return ScreenshotService.wrapScreen(
        child: content,
        showButton: true,
        buttonPosition: Alignment.bottomRight,
        buttonColor: Colors.green,
      );
    }
  }
}
