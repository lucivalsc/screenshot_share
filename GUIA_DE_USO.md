# Como usar

Guia rápido para integrar o pacote `screenshot_share_telegram` (v0.2.0) em um
projeto Flutter.

> **Atenção:** o envio para o Telegram **foi removido na 0.2.0**. O pacote não
> aceita, armazena nem transmite credenciais. Os destinos disponíveis são
> salvamento local e share sheet nativo, e **todo destino recebe um único
> arquivo ZIP**. O motivo está no `README.md`, seção *Why Telegram was
> removed*.

## 1. Configuração inicial

No `main.dart`, antes do `runApp`:

```dart
void main() {
  ScreenshotConfig.configure(
    // Destino: localSave, shareWithApps ou askUser
    shareMode: ShareMode.askUser,

    // Qualidade e redimensionamento
    imageQuality: 90,
    resizeStrategy: ResizeStrategy.fitContain, // padrão: preserva a proporção
    backgroundColor: const Color(0xFF000000),  // preenchimento das bordas

    // Quais resoluções gerar
    deviceTypes: [
      DeviceType.iphone,
      DeviceType.android,
    ],

    // Comportamento
    fileNamePrefix: 'meuapp',
    showButtonsInDebugOnly: true, // some em release

    // Limites de memória do buffer (modo gerenciador)
    maxStoredCaptures: 20,
    maxTotalBytes: 40 * 1024 * 1024,

    // Textos
    strings: ScreenshotStrings.ptBr,
  );

  runApp(const MyApp());
}
```

Todo parâmetro é validado: um valor fora da faixa lança `ArgumentError`
imediatamente, em vez de falhar depois dentro do isolate.

## 2. Envolvendo sua aplicação

Use `wrapScreen` no `builder` do `MaterialApp`.

**Modo simples (1 botão — captura e entrega na hora):**

```dart
MaterialApp(
  builder: (context, child) => ScreenshotService.wrapScreen(
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
);
```

**Modo gerenciador (2 botões — captura várias, envia um ZIP depois):**

```dart
MaterialApp(
  builder: (context, child) => ScreenshotManagerService.wrapScreen(
    child: child ?? const SizedBox.shrink(),
    onShareResult: (result) => debugPrint('$result'),
  ),
  home: const HomePage(),
);
```

> Envolva **dentro** do `builder`, não acima do `MaterialApp`: o
> `ShareMode.askUser` precisa de um `Navigator` ancestral para exibir o
> seletor de destino.

## 3. Tratando o resultado

As operações retornam `ScreenshotResult`, o que permite distinguir uma falha
real de "já existe uma operação em andamento":

```dart
final result = await ScreenshotManagerService().processScreenshots();

switch (result) {
  case ScreenshotSuccess(count: final n, location: final path):
    // `location` só vem preenchido no modo localSave
    mostrarInfo(path == null ? '$n imagens enviadas' : 'Salvo em $path');

  case ScreenshotBusy():
    break; // não é erro — não exiba mensagem de falha

  case ScreenshotCancelled():
    mostrarInfo('Cancelado');

  case ScreenshotFailure(kind: final kind, message: final message):
    mostrarErro(message); // mensagem diagnóstica real
}
```

Os wrappers já fazem isso e exibem a mensagem; os callbacks `onResult` /
`onCaptureResult` / `onShareResult` existem para integrar ao seu próprio
sistema de notificação (SnackBar, Crashlytics, Sentry).

## 4. Dispositivos suportados

O pacote gera versões redimensionadas da tela para simular diferentes devices:

| Tipo | Resoluções (portrait) |
|---|---|
| `DeviceType.android` | 1080×1920, 1440×2560 |
| `DeviceType.iphone` | 1242×2688 (6.5"), 1284×2778 (6.7") |
| `DeviceType.ipad` | 2064×2752, 2048×2732 |
| `DeviceType.windows` | 1366×768, 1920×1080 |
| `DeviceType.macos` | 1280×800, 2560×1600 |
| `DeviceType.linux` | 1366×768, 1920×1080 |

Sem filtro, o padrão é o conjunto móvel (android + iphone + ipad = 6
variantes). Para resoluções próprias, use `screenSizes` com `ScreenSize`.

## 5. Atalhos de teclado

Habilitados por padrão:

| Atalho | Ação |
|---|---|
| `Ctrl` / `Cmd` + `Shift` + `S` | Capturar |
| `Ctrl` / `Cmd` + `Shift` + `E` | Enviar (modo gerenciador) |

Desative com `enableKeyboardShortcut: false` no `wrapScreen`.

## 6. Permissões

**Nenhuma.** Os destinos padrão são diretórios que o app sempre pode escrever.

Se você seguiu um README antigo e declarou `WRITE_EXTERNAL_STORAGE` /
`READ_EXTERNAL_STORAGE` no `AndroidManifest.xml`, pode removê-los.

---

# Manutenção e Publicação

Antes de publicar, siga o checklist completo em
[`CLAUDE.md`](CLAUDE.md#8-checklist-de-publicação).

```bash
# Verificações locais
dart format .
flutter analyze --fatal-infos
flutter test --coverage

# Conferir o pacote
flutter pub publish --dry-run

# Validar o exemplo
cd example && flutter pub get && flutter build apk --debug && cd ..

# Publicar
flutter pub publish
```

> Atualize `version` no `pubspec.yaml`, documente as mudanças no
> `CHANGELOG.md` (marcando *breaking changes*) e sincronize
> `.github/copilot-instructions.md` com o `pubspec.yaml`.
