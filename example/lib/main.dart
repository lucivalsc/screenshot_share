// Example app for the screenshot_share_telegram package.
import 'package:flutter/material.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

void main() {
  // Configure the package before runApp. No credentials are involved: the
  // archive either stays on this device or goes through the native share
  // sheet, so nothing secret is ever embedded in the binary.
  ScreenshotConfig.configure(
    shareMode: ShareMode.askUser,
    imageQuality: 90,
    fileNamePrefix: 'demo',
    resizeStrategy: ResizeStrategy.fitContain,
    backgroundColor: const Color(0xFF101010),
    deviceTypes: [DeviceType.android, DeviceType.iphone],
    strings: ScreenshotStrings.ptBr,
    // Show the buttons in every build mode so the example is usable in
    // release too. Leave this at its default (true) in real apps.
    showButtonsInDebugOnly: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screenshot Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      // Wrapping in `builder` keeps the buttons above every route while
      // leaving the Navigator intact, which ShareMode.askUser needs.
      builder: (context, child) => ScreenshotManagerService.wrapScreen(
        child: child ?? const SizedBox.shrink(),
        captureButtonColor: Colors.red,
        shareButtonColor: Colors.blue,
        onShareResult: (result) => debugPrint('Resultado do envio: $result'),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScreenshotManagerService _service = ScreenshotManagerService();

  @override
  Widget build(BuildContext context) {
    final config = ScreenshotConfig();

    return Scaffold(
      appBar: AppBar(title: const Text('Screenshot Demo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Modo gerenciador\n(captura várias, envia um ZIP)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Destino: ${config.shareMode.name}'),
              Text('Estratégia: ${config.resizeStrategy.name}'),
              Text('Resoluções geradas: ${config.screenSizes.length}'),
              const SizedBox(height: 24),

              // Live pending counter, driven by the service's notifier.
              ValueListenableBuilder<int>(
                valueListenable: _service.storedCount,
                builder: (context, count, _) => ValueListenableBuilder<int>(
                  valueListenable: _service.storedBytes,
                  builder: (context, bytes, __) => Text(
                    'Pendentes: $count variantes '
                    '(${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(5, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Capture esta tela!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Use os botões no canto inferior direito, ou\n'
                'Ctrl/Cmd + Shift + S para capturar e\n'
                'Ctrl/Cmd + Shift + E para enviar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _service.clearScreenshots,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Descartar pendentes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
