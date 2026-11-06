## 0.2.0

Reescrita completa a partir da análise técnica em
`docs/analise_captura_e_compartilhamento_de_screenshots_2026-11-06.md`.
Resolve os 28 GAPs identificados. **Contém breaking changes.**

### ⚠️ Breaking changes

* **Integração com o Telegram removida.** `TelegramService`,
  `TelegramSendResult`, `ShareMode.telegram`, `ShareMode.multiple`,
  `telegramToken`, `telegramChatId` e `isTelegramConfigValid` não existem
  mais. O pacote não aceita, armazena nem transmite credenciais. Até a 0.1.4
  o Bot Token acabava embutido no binário de release (extraível por `strings`
  no APK/IPA) e compunha a URL da requisição.
* **`ShareMode` agora é `localSave`, `shareWithApps` e `askUser`.** `askUser`
  exibe de fato um seletor de destino — o antigo `multiple` prometia um
  diálogo na documentação e enviava a um destino fixo.
* **Operações públicas retornam `ScreenshotResult`, não `Future<bool>`.**
  `ScreenshotSuccess`, `ScreenshotBusy`, `ScreenshotCancelled` e
  `ScreenshotFailure` (com `kind`, `message`, `cause` e `stackTrace`).
  `ScreenshotBusy` não é erro e não deve ser exibido como tal.
* **`ScreenSize` substitui `Map<String, dynamic>`** em `screenSizes`. Use
  `ScreenshotConfig.screenSizesFromMaps()` para migrar o formato antigo (que
  agora aceita `double` inteiro, antes um `TypeError` dentro do isolate).
* **`ScreenshotData` não carrega mais `bytes`.** Expõe `path`, `sizeInBytes`,
  `readBytes()` e `delete()`.
* **`captureAndShare` e `captureScreen` exigem `pixelRatio`.** Os wrappers
  resolvem isso a partir do contexto automaticamente.
* **`lib/main.dart` removido** (um "Hello World" que era publicado no pub.dev).
* **Dependências `http` e `permission_handler` removidas.**

### 🔒 Segurança

* Removida a exposição do Bot Token em builds de produção (GAP-01), eliminando
  a funcionalidade em vez de mitigá-la.
* Nomes de arquivo e entradas de ZIP sanitizados contra separadores de
  caminho e sequências `..` (*zip-slip*).

### 🐛 Correções críticas

* **Vazamento de memória nativa:** `ui.Image` agora é liberado em
  `try/finally`. Cada captura vazava 8–30 MB invisíveis ao GC do Dart.
* **Crescimento ilimitado do buffer:** variantes são gravadas em disco e
  referenciadas por caminho, com limites `maxStoredCaptures` (20) e
  `maxTotalBytes` (40 MB) e rollback ao exceder.
* **Polling de 1 segundo removido:** o contador virou `ValueNotifier`. A
  0.1.4 reconstruía a aplicação inteira 1× por segundo, perpetuamente, e
  retinha a subárvore após o `dispose`.
* **Imagens distorcidas:** nova `ResizeStrategy` com `fitContain` como padrão
  (proporção preservada, bordas preenchidas), além de `fitCover` e `stretch`.
  A 0.1.4 esticava toda captura cuja proporção diferisse do alvo.
* **`pixelRatio` fixo em 2.0** substituído por valor derivado da view,
  limitado a 1.0–3.0.

### ✨ Melhorias

* **Todo destino recebe um único ZIP.** O modo "compartilhar com apps"
  entregava arquivos soltos, um por resolução.
* ZIP montado por streaming (`ZipFileEncoder`); o pico de memória não cresce
  mais com o número de capturas.
* Erros tipados: `ImageProcessingException` (com `stage` e `size`),
  `CaptureUnavailableException`, `StorageFailureException`,
  `CaptureBufferFullException`. O isolate não converte mais exceções em lista
  vazia.
* Mensagens de erro reais chegam ao usuário; os wrappers consumiam apenas o
  `bool` e descartavam o diagnóstico.
* `ScreenshotStrings` externaliza todo texto visível, com tabelas `en` e
  `ptBr` e `copyWith`. A 0.1.4 misturava inglês (widgets) e português (rede).
* Permissões: `Permission.storage` (obsoleta no Android 13+, sempre negada)
  eliminada; os destinos padrão não exigem permissão alguma.
* `Overlay` próprio substituído por `Stack`: a visibilidade dos botões passa a
  responder em runtime e o overlay do app hospedeiro não é mais sequestrado.
* Toast com `Timer` cancelável; duas mensagens em sequência não se anulam.
* Captura sincronizada com `endOfFrame` + `Visibility`, em vez de
  `Future.delayed(300ms)`.
* Limpeza automática de artefatos temporários com mais de 24 h.
* `AsyncLock` substitui as flags booleanas que podiam ficar presas em `true`.
* Acessibilidade: `tooltip`, `Semantics` e `SemanticsService.announce()`.
* Atalhos de teclado: `Ctrl/Cmd + Shift + S` captura,
  `Ctrl/Cmd + Shift + E` envia.
* `DeviceType.macos`, `windows` e `linux` ganham resoluções reais; antes
  mapeavam para listas vazias e causavam falha genérica.
* Validação completa em `configure()` com `ArgumentError`.
* Pipeline de captura unificado, eliminando a duplicação entre os dois
  serviços.

### 🧰 Infraestrutura

* `example/` virou um pacote real, com `pubspec.yaml` e plataformas — antes
  não compilava e o pub.dev não exibia a aba Example.
* CI substituído: o workflow anterior pertencia a outro projeto (flavors de
  um app de transporte universitário), apontava para a branch `master` e
  nunca executou. O novo roda `format`, `analyze --fatal-infos`, `test
  --coverage`, `publish --dry-run` e build do exemplo.
* Suíte de testes: de 1 para 60 testes, cobrindo configuração, `ScreenSize`,
  processamento de imagem, ZIP, lock e widgets. `resetToDefaults()` em todo
  `setUp`.
* `ignore_for_file: deprecated_member_use` removido; migrado para
  `SharePlus.instance.share(ShareParams(...))`. A análise estática estava
  falsamente limpa.
* Adicionados `CLAUDE.md` (regras obrigatórias) e `.pubignore`.
* Removidos do repositório `estrutura.py` (gerador de scaffolding que
  sobrescreveria os fontes) e `analysis.log`.

### 🔁 Guia rápido de migração

```dart
// 0.1.4
ScreenshotConfig.configure(
  telegramToken: 'TOKEN',
  telegramChatId: 'CHAT',
  shareMode: ShareMode.telegram,
  screenSizes: [{'width': 1080, 'height': 1920, 'suffix': 'phone'}],
);
final ok = await ScreenshotService().captureAndShare(key);
if (!ok) showError('Erro');

// 0.2.0
ScreenshotConfig.configure(
  shareMode: ShareMode.askUser,
  screenSizes: ScreenshotConfig.screenSizesFromMaps(
    [{'width': 1080, 'height': 1920, 'suffix': 'phone'}],
  ),
);
// Os wrappers já tratam o resultado; para chamada direta:
final result = await ScreenshotService().captureAndShare(
  key,
  pixelRatio: CapturePipeline.resolvePixelRatio(context),
);
switch (result) {
  case ScreenshotSuccess(location: final path):
    showInfo(path == null ? 'Compartilhado' : 'Salvo em $path');
  case ScreenshotBusy():
    break; // não é erro
  case ScreenshotCancelled():
    break;
  case ScreenshotFailure(message: final message):
    showError(message);
}
```

## 0.1.4
* Atualização de dependências: `permission_handler` para ^13.0.2, `archive` para ^4.6.0, `image` para ^4.12.0 e `share_plus` para ^12.0.2.
* Correção de codificação de arquivos ZIP em `StorageService` para versões recentes do `archive`.
* Adição e correção de testes unitários para `ScreenshotConfig`.

## 0.1.3
* Atualização de dependências para compatibilidade com Flutter 3.35.4 e Dart 3.9.2.
* Atualizado constraint de SDK para >=3.0.0 <4.0.0.
* Atualizado constraint de Flutter para >=3.35.0.
* Atualizado archive para ^4.0.9.
* Atualizado image para ^4.8.0.

## 0.1.2
* Atualização de pacotes para a versão mais recente.
* Atualização das resoluções para focar apenas em modo portrait (celular e tablet).
* Adicionado enum DeviceType para filtrar os dispositivos desejados.
* Otimização do processamento de imagens utilizando Isolates para não travar a UI.
* Refatoração da estrutura de serviços (TelegramService separado).

## 0.1.1+1
* Correção de versão.

## 0.1.0
* Lançamento inicial com as seguintes funcionalidades:
* Modo de botão único para captura e compartilhamento imediato.
* Modo de botão duplo para capturar várias capturas de tela e compartilhar posteriormente.
* Várias opções de compartilhamento:
    * Enviar para o Telegram via Bot API.
    * Salvar no armazenamento local.
    * Compartilhar com outros aplicativos.
* Tamanhos e qualidade de captura de tela configuráveis.
* Opção de mostrar botões apenas no modo debug.
