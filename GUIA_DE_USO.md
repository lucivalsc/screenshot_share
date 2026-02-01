# Como usar

Este é um guia rápido para integrar o pacote `screenshot_share_telegram` em seu projeto Flutter.

## 1. Configuração Inicial

No seu arquivo `main.dart`, inicialize a configuração antes de rodar o app:

```dart
void main() {
  ScreenshotConfig.configure(
    // (Opcional) Token e Chat ID do Telegram
    telegramToken: 'SEU_TOKEN_AQUI',
    telegramChatId: 'SEU_CHAT_ID_AQUI',
    
    // (Opcional) Configurações visuais e de comportamento
    shareMode: ShareMode.telegram, // Ou localSave, shareWithApps
    showButtonsInDebugOnly: true, // Se true, some em release
    
    // (Novo) Filtrar dispositivos específicos para gerar screenshot
    deviceTypes: [
      DeviceType.iphone, // Apenas resoluções de iPhone
      DeviceType.android, // Apenas resoluções de Android
    ],
  );

  runApp(const MyApp());
}
```

## 2. Envolvendo sua App

Para que os botões de captura apareçam sobre sua aplicação, use o método estático `wrapScreen` no `builder` do seu `MaterialApp`:

**Modo Simples (1 Botão - Captura e Envia):**
```dart
MaterialApp(
  builder: (context, child) {
    return ScreenshotService.wrapScreen(
      child: child ?? const SizedBox(),
      showButton: true,
    );
  },
  home: HomePage(),
);
```

**Modo Gerenciador (2 Botões - Captura vários, Envia depois):**
```dart
MaterialApp(
  builder: (context, child) {
    return ScreenshotManagerService.wrapScreen(
      child: child ?? const SizedBox(),
      showButtons: true, // Botão Vermelho (Captura) e Azul (Envia)
    );
  },
  home: HomePage(),
);
```

## 3. Dispositivos Suportados

O pacote gera automaticamente versões redimensionadas da sua tela para simular diferentes devices:

*   **iPhone**: 6.5" e 6.7" (Portrait)
*   **iPad**: 12.9" e 12.9" Pro (Portrait)
*   **Android**: 1080p e 1440p

Você pode controlar quais são gerados usando a propriedade `deviceTypes` na configuração.

---

# Manutenção e Publicação

## Publicando no pub.dev

Para publicar uma nova versão deste pacote:

1. **Verifique se tudo está correto (Dry Run):**
   ```bash
   flutter pub publish --dry-run
   ```

2. **Publique o pacote:**
   ```bash
   flutter pub publish
   ```
   
> **Nota:** Certifique-se de ter atualizado a versão no `pubspec.yaml` e documentado as mudanças no `CHANGELOG.md` antes de publicar.
