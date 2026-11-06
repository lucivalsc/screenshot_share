# Análise Técnica e Funcional — Fluxo de Captura e Compartilhamento de Screenshots

> ## ✅ Status: implementado na versão 0.2.0
>
> Os **28 GAPs** descritos neste documento foram corrigidos. O plano da seção 3
> foi executado, com três decisões que divergem do proposto:
>
> 1. **GAP-01 resolvido por remoção, não por mitigação.** A integração com o
>    Telegram foi eliminada (`TelegramService`, `ShareMode.telegram`,
>    `ShareMode.multiple`, token e `chat_id`), junto com a dependência `http`.
>    O item 3.1 propunha um resolvedor de credenciais seguro; a decisão do
>    responsável pelo projeto foi retirar a funcionalidade, o que extingue a
>    classe de falha em vez de reduzi-la.
> 2. **GAP-08 resolvido removendo `permission_handler`.** Com o Telegram fora,
>    todos os destinos passaram a ser diretórios graváveis sem permissão, então
>    a dependência não tem mais nenhum uso legítimo. `Permission.storage`
>    (obsoleta na API 33+) foi eliminada em vez de substituída.
> 3. **Todo destino recebe um único ZIP.** O modo `shareWithApps` entregava
>    arquivos soltos, um por resolução; agora salvamento e compartilhamento
>    compartilham a mesma rota de arquivamento.
>
> GAPs 06 e 07 (timeout de rede e limite de 50 MB do Telegram) tornaram-se
> inaplicáveis com a remoção da integração.
>
> **Verificação:** `flutter analyze --fatal-infos` limpo (sem supressões),
> 60 testes passando (de 1), `flutter pub publish --dry-run` sem avisos de
> conteúdo, `example/` compilando. Detalhes em
> [`CHANGELOG.md`](../CHANGELOG.md); regras derivadas desta análise em
> [`CLAUDE.md`](../CLAUDE.md).
>
> O texto abaixo é preservado como registro do estado da versão 0.1.4.

---

| Item | Valor |
|---|---|
| **Projeto** | `screenshot_share_telegram` (pacote Flutter) |
| **Caminho** | `d:/Projetos/Flutter/Lucival/screenshot_share` |
| **Versão analisada** | 0.1.4 (commit `f613184`) |
| **Data da análise** | 06/11/2026 |
| **Escopo** | Fluxo ponta a ponta: UI (overlay de botões) → Serviços → Processamento em isolate → Persistência local / Telegram Bot API / Share nativo |
| **Regras aplicadas** | `.github/copilot-instructions.md` (não existe `CLAUDE.md` neste repositório — ver GAP-25) |
| **Agentes aplicados** | `AGENTS.md`: Package Maintainer, Feature Implementer, Bug Hunter, Doc Writer |
| **Base de código** | 1.605 linhas em 13 arquivos Dart (`lib/`), 1 teste unitário |
| **Estado estático** | `flutter analyze` → *No issues found* (porém com supressão ativa — ver GAP-21) / `flutter test` → 1 teste, 1 aprovado |

---

## 1. Mapeamento do Fluxo Atual

### 1.1 Visão de camadas

O pacote **não** segue Clean Architecture (não há camadas de Domínio/Dados/UseCases). A arquitetura real é de **3 níveis acoplados por singletons globais**:

```
┌─────────────────────────────────────────────────────────────────┐
│ CAMADA DE APRESENTAÇÃO (lib/src/widgets/)                       │
│  ScreenshotWrapper (1 botão)  │ DualButtonScreenshotWrapper (2) │
│  - Overlay como raiz da árvore + RepaintBoundary(GlobalKey)     │
│  - Estado local: _processando / _capturando / _enviando         │
│  - Feedback: OverlayEntry manual (não usa SnackBar/Scaffold)    │
└───────────────────────┬─────────────────────────────────────────┘
                        │ chamada direta ao singleton (sem DI)
┌───────────────────────▼─────────────────────────────────────────┐
│ CAMADA DE SERVIÇO (lib/src/services/)                           │
│  ScreenshotService          — captura e compartilha na hora     │
│  ScreenshotManagerService   — captura em lote, envia depois     │
│  (ambos singletons com flags bool de reentrância)               │
└───────────────────────┬─────────────────────────────────────────┘
                        │
         ┌──────────────┼───────────────┬──────────────────┐
         ▼              ▼               ▼                  ▼
┌────────────────┐┌─────────────┐┌──────────────┐┌─────────────────┐
│ ImageProcessor ││StorageService││TelegramService││ScreenshotConfig │
│ (compute/      ││(FS, ZIP,     ││(HTTP          ││(singleton de    │
│  isolate)      ││ permissões,  ││ multipart)    ││ configuração    │
│ decode+resize+ ││ share_plus)  ││               ││ global mutável) │
│ encodeJpg      ││              ││               ││                 │
└────────────────┘└──────┬───────┘└──────┬────────┘└─────────────────┘
                         ▼               ▼
              ┌──────────────────┐ ┌──────────────────────────┐
              │ Sistema de       │ │ api.telegram.org         │
              │ arquivos         │ │ /bot<TOKEN>/sendDocument │
              │ (app-private)    │ │ (HTTPS, multipart)       │
              └──────────────────┘ └──────────────────────────┘
```

### 1.2 Inventário de arquivos participantes

| Arquivo | LOC | Papel no fluxo |
|---|---|---|
| `lib/screenshot_share.dart` | 22 | Barrel de exportação da API pública |
| `lib/main.dart` | 20 | **Hello World residual** — não participa do fluxo (GAP-19) |
| `lib/src/config/screenshot_config.dart` | 160 | Configuração global (token, qualidade, modo, resoluções) |
| `lib/src/enums/share_mode.dart` | 14 | `telegram`, `localSave`, `shareWithApps`, `multiple` |
| `lib/src/enums/device_type.dart` | 20 | `android`, `iphone`, `ipad`, `macos`, `windows`, `linux` |
| `lib/src/models/screenshot_data.dart` | 40 | DTO: `bytes`, `filename`, `width`, `height`, `group`, `timestamp` |
| `lib/src/services/screenshot_service.dart` | 178 | Fluxo A (captura + envio imediato) |
| `lib/src/services/screenshot_manager_service.dart` | 266 | Fluxo B (captura em lote + envio posterior) |
| `lib/src/services/storage_service.dart` | 233 | ZIP, salvamento local, share nativo, permissões |
| `lib/src/services/telegram_service.dart` | 92 | `POST multipart /sendDocument` + `TelegramSendResult` |
| `lib/src/utils/image_processor.dart` | 95 | `compute()` → decode PNG, `copyResize`, `encodeJpg` |
| `lib/src/widgets/screenshot_wrapper.dart` | 181 | Overlay + 1 FAB |
| `lib/src/widgets/dual_button_wrapper.dart` | 284 | Overlay + 2 FABs + Badge contador |

**Estruturas de dados externas:** nenhuma. **Não há SQLite, Hive, nem qualquer persistência estruturada** — o estado de capturas vive apenas em memória (`Map<String, List<ScreenshotData>>` + `List<ScreenshotData>`). Os únicos artefatos persistidos são arquivos `.jpg`/`.zip` soltos no diretório privado do app.

**Endpoints externos:** 1 — `POST https://api.telegram.org/bot{token}/sendDocument` (campos `chat_id`, `caption`, arquivo `document`).

### 1.3 Fluxo A — Modo Botão Único (captura e envia imediatamente)

`ScreenshotService.wrapScreen()` → `ScreenshotWrapper`

```
1. Usuário toca no FAB vermelho
   └─ _ScreenshotWrapperState._captureScreen()           [screenshot_wrapper.dart:111]
2. setState → _processando = true; _botaoVisivel = false
3. await Future.delayed(300ms)                           ← espera arbitrária (GAP-15)
4. ScreenshotService().captureAndShare(_repaintKey, overrideMode: widget.shareMode)
   ├─ if (_isProcessing) return false                    ← guarda de reentrância global
   ├─ Resolve config: screenName, screenSizes, imageQuality, shareMode
   ├─ repaintKey.currentContext.findRenderObject() as RenderRepaintBoundary
   ├─ boundary.toImage(pixelRatio: 2.0)                  ← hardcoded (GAP-04)
   ├─ image.toByteData(format: png) → Uint8List          ← ui.Image nunca é dispose() (GAP-05)
   ├─ ImageProcessor().processImage(...)
   │   └─ compute(_processImageIsolate)                  [image_processor.dart:29]
   │       ├─ img.decodePng(pngBytes)
   │       ├─ para cada size em screenSizes (padrão: 6):
   │       │   ├─ img.copyResize(w, h, linear)           ← distorce aspect ratio (GAP-04)
   │       │   ├─ img.encodeJpg(quality)
   │       │   └─ ScreenshotData(group: "<name>_<ts>")
   │       └─ catch (e) → return []                      ← engole a causa raiz (GAP-11)
   ├─ if (screenshots.isEmpty) → erro genérico
   └─ switch (shareMode):
      ├─ telegram        → StorageService().createZipArchive()
      │                    → TelegramService().sendDocument()   ← sem timeout (GAP-06)
      ├─ localSave       → StorageService().saveScreenshotsLocally()
      │                    → _requestStoragePermission()        ← API obsoleta (GAP-08)
      │                    → getExternalStorageDirectory()      ← pasta privada (GAP-08)
      ├─ shareWithApps   → StorageService().shareScreenshots()
      │                    → grava em temp + Share.shareXFiles() ← deprecado (GAP-21)
      └─ multiple        → idêntico a `telegram`                 ← não implementado (GAP-09)
5. setState → _processando = false; _botaoVisivel = true  (guardado por `mounted`)
6. _showSimpleMessage(context, "Screenshot shared!" | "Error sharing screenshot", cor)
   └─ OverlayEntry + Future.delayed(2s, _removeOverlay)  ← race entre toasts (GAP-14)
```

### 1.4 Fluxo B — Modo Botão Duplo (lote)

`ScreenshotManagerService.wrapScreen()` → `DualButtonScreenshotWrapper`

```
B1. initState → _updateCounter()
    └─ setState(_captureCount = service.storedScreenshotsCount)
       + Future.delayed(1s, _updateCounter)              ← polling recursivo infinito (GAP-03)

B2. Toque no FAB vermelho (capturar)
    └─ _service.captureScreen(_repaintKey)
       ├─ passos idênticos a A (captura → isolate → List<ScreenshotData>)
       └─ ARMAZENA EM MEMÓRIA:
          _captureGroups[captureId] = screenshots
          _allScreenshots.addAll(screenshots)            ← crescimento ilimitado (GAP-02)

B3. Toque no FAB azul (enviar) — habilitado só se _captureCount > 0
    └─ _service.processScreenshots(overrideMode, clearAfterProcessing: true)
       ├─ if (_allScreenshots.isEmpty) → erro
       └─ switch (shareMode): mesmos 4 ramos de A, aplicados a TODAS as capturas
          └─ se success && clearAfterProcessing → limpa os dois buffers
             (se falhar, o buffer NÃO é limpo — correto, mas sem retry nem fila)
```

### 1.5 Pontos de decisão de configuração

| Decisão | Resolvida em | Precedência |
|---|---|---|
| Resoluções a gerar | `ScreenshotConfig.screenSizes` | `customSizes` (param) > `_customScreenSizes` (config) > `_deviceTypes` filtrado > todos os mobile (6 tamanhos) |
| Modo de compartilhamento | `overrideMode` > `widget.shareMode` > `config.shareMode` | `telegram` por padrão |
| Visibilidade dos botões | `showButton(s)` (param) > `config.shouldShowButtons` | `!_showButtonsInDebugOnly \|\| kDebugMode` |
| Qualidade JPEG | `quality` (param) > `config.imageQuality` | 90 |
| Diretório de salvamento | `config.savePath` > `getExternalStorageDirectory()` (Android) / `getApplicationDocumentsDirectory()` | — |

---

## 2. Matriz de GAPs Encontrados

Severidade: **Crítico** = perda de dados / crash / exposição de credencial · **Alto** = falha funcional recorrente · **Médio** = inconsistência, dívida arquitetural · **Baixo** = qualidade, documentação, acessibilidade.

### 🔴 Críticos

---

#### GAP-01 · Exposição do Bot Token do Telegram em build de produção
**Severidade:** Crítico · **Agente:** Bug Hunter / Package Maintainer
**Arquivos:** `lib/src/services/telegram_service.dart:31-32,52`, `lib/src/config/screenshot_config.dart:104`, `README.md:50`

**Causa raiz:** O token é passado por `ScreenshotConfig.configure()` e, na prática, fica hardcoded no `main.dart` do app consumidor (como o próprio `example/lib/main.dart` e o README demonstram). Com `showButtonsInDebugOnly: false` — valor usado no exemplo oficial, linha 12 — o pacote permanece ativo em release e o token é embutido no binário, extraível por `strings` no APK/IPA. Agrava-se:
- o token compõe a **URL** da requisição (`/bot$token/sendDocument`), aparecendo em logs de proxy/MITM e em qualquer captura de tráfego;
- `debugPrint('📤 Telegram API Response: $statusCode')` e `'Falha na API ($statusCode): $responseBody'` (linha 58) propagam o corpo bruto da API para o callback de erro, que os wrappers podem exibir;
- não há validação de formato do token nem aviso quando o modo Telegram está ativo em release.

**Impacto:** Qualquer pessoa que extraia o token assume controle do bot: envio de mensagens arbitrárias ao `chat_id`, leitura de updates, e — se o bot for compartilhado com outros grupos — acesso a eles. É a falha mais grave do pacote, e ela é **induzida pela própria documentação**.

---

#### GAP-02 · Crescimento ilimitado do buffer de capturas em memória (risco de OOM)
**Severidade:** Crítico · **Agente:** Expert em Flutter/Dart (Bug Hunter)
**Arquivos:** `lib/src/services/screenshot_manager_service.dart:25-28,120-123`

**Causa raiz:** No modo botão duplo, cada captura gera **N** imagens (padrão: 6 resoluções, incluindo 2048×2732 e 2064×2752) e **todas** são retidas como `Uint8List` em dois buffers simultâneos (`_captureGroups` e `_allScreenshots`) — ou seja, cada imagem é referenciada duas vezes. Não existe:
- limite máximo de capturas ou de bytes acumulados;
- descarga para disco (spill-to-disk) com retenção apenas de caminhos;
- política de descarte (LRU/FIFO).

Estimativa conservadora a 90% de qualidade: ~400 KB–1,2 MB por imagem × 6 = **~3–7 MB por captura**. Dez capturas antes do envio chegam a **30–70 MB de heap Dart**, e durante `createZipArchive` o conteúdo é **duplicado integralmente** (o `Archive` referencia os bytes e o `ZipEncoder` materializa um `List<int>` completo antes do `Uint8List.fromList`, o que triplica o pico).

**Impacto:** `OutOfMemoryError` / morte do processo pelo sistema em dispositivos de baixa/média memória exatamente no momento do envio — o pior momento possível, pois **perde todas as capturas acumuladas** sem qualquer persistência de recuperação. O usuário perde trabalho de uma sessão inteira de testes.

---

#### GAP-03 · Polling recursivo com `setState` a cada segundo, reconstruindo a árvore inteira da aplicação
**Severidade:** Crítico · **Agente:** Expert em Flutter/Dart
**Arquivos:** `lib/src/widgets/dual_button_wrapper.dart:63-79`

**Causa raiz:**
```dart
void _updateCounter() {
  if (mounted) {
    setState(() { _captureCount = _service.storedScreenshotsCount; });
    Future.delayed(const Duration(seconds: 1), _updateCounter); // ← recursão infinita
  }
}
```
Três problemas somados:
1. **Nenhum `Timer` é guardado**, logo não há nada a cancelar em `dispose()`. A cadeia só se interrompe na iteração *seguinte* ao desmonte (até 1 s depois), e enquanto isso mantém viva uma referência ao `State` e, por ele, a toda a subárvore — impedindo a coleta.
2. O `DualButtonScreenshotWrapper` é documentado para envolver **a aplicação inteira** (via `MaterialApp.builder`, conforme `GUIA_DE_USO.md`). Portanto `setState` dispara `build()` do wrapper **1× por segundo, perpetuamente, durante toda a vida do app** — mesmo com zero capturas e nenhuma interação.
3. É *busy polling* de um valor que o serviço conhece com exatidão: `_captureScreen` e `_shareScreenshots` já atualizam o contador explicitamente (linhas 199 e 230), tornando o polling inteiramente redundante.

**Impacto:** Degradação contínua de desempenho e consumo de bateria em toda a aplicação hospedeira, jank perceptível em telas com listas/animações, e retenção de memória após o desmonte. Como o pacote se anuncia como ferramenta de desenvolvimento *e* produção, o custo é pago pelo app final.

---

### 🟠 Altos

---

#### GAP-04 · Distorção das imagens e `pixelRatio` fixo
**Severidade:** Alto · **Agente:** Feature Implementer / Designer UI-UX
**Arquivos:** `lib/src/utils/image_processor.dart:50-55`, `screenshot_service.dart:76`, `screenshot_manager_service.dart:88`

**Causa raiz:** `img.copyResize(decodedImage, width: width, height: height)` passa **ambas** as dimensões, o que força a imagem à razão de aspecto alvo **sem preservar a proporção original** e sem letterbox/crop. Uma captura de celular (≈9:19.5) redimensionada para o alvo de iPad 2048×2732 (≈3:4) fica visivelmente **esticada na horizontal**. Complementarmente, `toImage(pixelRatio: 2.0)` é fixo: ignora `MediaQuery.of(context).devicePixelRatio`, produzindo capturas de baixa resolução em telas 3x/4x e desperdício de memória em telas 1x — e em tablets grandes gera um bitmap intermediário enorme sem necessidade.

**Impacto:** O artefato principal do pacote — a screenshot — sai **visualmente incorreto** em praticamente toda combinação de dispositivo real × resolução alvo. Para o caso de uso declarado (gerar screenshots para lojas de aplicativos), as imagens são inutilizáveis: a Apple e o Google rejeitam capturas distorcidas.

---

#### GAP-05 · `ui.Image` nunca liberado (vazamento de memória nativa)
**Severidade:** Alto · **Agente:** Expert em Flutter/Dart
**Arquivos:** `screenshot_service.dart:76-85`, `screenshot_manager_service.dart:88-97`

**Causa raiz:** `final ui.Image image = await boundary.toImage(...)` aloca um bitmap no heap **nativo** (Skia/Impeller), fora do alcance do GC do Dart. `image.dispose()` nunca é chamado — nem no caminho de sucesso, nem no `catch`, nem quando `toByteData()` retorna `null`. Não há `try/finally`.

**Impacto:** Cada captura vaza um bitmap de tamanho `(largura×pixelRatio) × (altura×pixelRatio) × 4 bytes` — tipicamente **8–30 MB** por captura em um celular moderno a `pixelRatio: 2.0`. Em uma sessão de 10 capturas, isso são centenas de megabytes de memória nativa irrecuperável, independente e cumulativa ao GAP-02. É um dos principais candidatos a causa de crashes relatados como "app fecha ao tirar várias screenshots".

---

#### GAP-06 · Requisição ao Telegram sem timeout, cancelamento ou retry
**Severidade:** Alto · **Agente:** Bug Hunter
**Arquivos:** `lib/src/services/telegram_service.dart:48-50`

**Causa raiz:** `await request.send()` e `await response.stream.bytesToString()` não têm `.timeout(...)`, não usam um `http.Client` configurável nem reaproveitado, e não há `CancelToken`/`client.close()`. Em rede instável (captive portal, 2G, perda de sinal durante o upload de um ZIP de vários MB) a Future pode pendurar por minutos — o padrão do sistema operacional, não um limite da aplicação.

Isso **viola diretriz explícita** de `.github/copilot-instructions.md`, seção *Práticas de Código*: «Use `async/await` para operações de I/O e rede. **Trate erros de timeout e falhas de conexão.**»

**Impacto:** O botão de envio fica travado em `_enviando = true` indefinidamente, com `CircularProgressIndicator` eterno, sem meio de abortar; e a flag singleton `_isSendingProcessing` permanece `true`, **bloqueando qualquer envio futuro em toda a aplicação** até o restart. Não há retry: uma falha transitória de rede exige repetir manualmente todo o fluxo. Também não há `Connectivity`/detecção de offline — nenhuma estratégia de resiliência ou consistência eventual (fila de envio pendente) existe no pacote.

---

#### GAP-07 · Limite de 50 MB do Telegram Bot API não verificado nem tratado
**Severidade:** Alto · **Agente:** Bug Hunter / Feature Implementer
**Arquivos:** `telegram_service.dart:34-42`, `screenshot_manager_service.dart:167-181`

**Causa raiz:** A Bot API limita `sendDocument` a **50 MB** por arquivo. O modo lote monta um único ZIP com **todas** as capturas acumuladas (GAP-02) — JPEGs já comprimidos, portanto o ZIP praticamente não reduz o tamanho. Com ~3–7 MB por captura, **8 a 16 capturas estouram o limite**. Não há:
- verificação de `zipBytes.length` antes do envio;
- fatiamento em múltiplos arquivos (chunking);
- tratamento específico para HTTP 413 / `"Request Entity Too Large"` / erro 400 `"file is too big"`.

**Impacto:** Falha de envio categórica num cenário absolutamente comum (uma sessão de testes de ~10 telas), reportada ao usuário como `"Error sharing screenshots"` sem causa nem orientação. E, pela interação com o GAP-06, pode ocorrer **depois** de um upload demorado de dezenas de megabytes consumidos do plano de dados do usuário.

---

#### GAP-08 · Fluxo de permissão e diretório de destino quebrados no Android moderno
**Severidade:** Alto · **Agente:** Bug Hunter / Package Maintainer
**Arquivos:** `storage_service.dart:193-232`, `README.md:166-172`, `android/app/src/main/AndroidManifest.xml`

**Causa raiz:** Três falhas encadeadas no modo `localSave`:

1. **`Permission.storage` é obsoleta a partir do Android 13 (API 33).** Com `targetSdk ≥ 33` ela retorna permanentemente *denied*/*restricted*, pois `READ/WRITE_EXTERNAL_STORAGE` deixaram de ser concedíveis. O código então retorna `null` em `saveScreenshotsLocally` e o fluxo aborta. O correto é `Permission.photos` / `Permission.manageExternalStorage` conforme a versão, ou — melhor — **nenhuma permissão**, usando apenas diretórios privados do app (que nunca exigiram permissão).
2. **A verificação é desnecessária e prejudicial.** O destino padrão é `getExternalStorageDirectory()` — o diretório *privado* do app em `/Android/data/<pkg>/files/` —, que **jamais** requereu permissão em nenhuma versão do Android. O pacote pede uma permissão que não precisa, obtém negação, e falha por isso.
3. **O arquivo salvo é inalcançável para o usuário.** `/Android/data/...` é oculto ao app Arquivos desde o Android 11; as screenshots não aparecem na galeria (não há `MediaStore`/`MediaScanner`), então, mesmo quando o salvamento funciona, **o usuário não encontra o resultado**.

Além disso, o `README.md` instrui o consumidor a declarar `WRITE_EXTERNAL_STORAGE`/`READ_EXTERNAL_STORAGE` — orientação inócua em API 33+ —, enquanto o `AndroidManifest.xml` do próprio projeto não declara nenhuma permissão, e o `Info.plist` não possui `NSPhotoLibraryAddUsageDescription` apesar de o README afirmar que é necessário.

**Impacto:** O modo `localSave` está **funcionalmente quebrado na maioria dos dispositivos Android em circulação**, com falha silenciosa (apenas `debugPrint`) e mensagem genérica ao usuário. É o cenário "Permission denied" previsto em `AGENTS.md § 3. Bug Hunter`.

---

#### GAP-09 · `ShareMode.multiple` não faz o que documenta
**Severidade:** Alto · **Agente:** Feature Implementer / Doc Writer
**Arquivos:** `share_mode.dart:13-14`, `screenshot_service.dart:140-153`, `screenshot_manager_service.dart:195-207`

**Causa raiz:** O enum declara: *«Multiple modes enabled — will show options dialog»*. A implementação **não exibe diálogo algum**. O comentário no código diz `// Default to Telegram + Local for multiple example`, mas o bloco executa **apenas o envio ao Telegram** — é uma cópia literal do ramo `ShareMode.telegram`, com a única diferença de omitir o `caption`. O salvamento local prometido pelo comentário jamais ocorre.

**Impacto:** O `example/lib/main.dart` oficial configura precisamente `shareMode: ShareMode.multiple` (linha 10). O usuário que seguir o exemplo espera escolher o destino ou obter ambos, e silenciosamente obtém só o Telegram — que, sem token configurado (o exemplo deixa `''`), falha de imediato. Primeira experiência do pacote: erro inexplicado. Três fontes de verdade divergem entre si: doc do enum, comentário do código e comportamento real.

---

#### GAP-10 · Falha silenciosa: mensagens de erro reais são descartadas na UI
**Severidade:** Alto · **Agente:** Designer UI-UX / Bug Hunter
**Arquivos:** `screenshot_wrapper.dart:121-140`, `dual_button_wrapper.dart:194-242`

**Causa raiz:** Os serviços oferecem callbacks `onError(String)` e `onSuccess()` bem construídos, que propagam mensagens diagnósticas precisas ("Could not find RenderRepaintBoundary", "Falha na API (401): ...", "Failed to save to local storage"). **Os dois wrappers ignoram completamente esses parâmetros** e se baseiam apenas no `bool` de retorno, exibindo strings fixas:

```dart
final success = await _service.captureScreen(_repaintKey);  // sem onError:
_showSimpleMessage(context, success ? "Screen captured!" : "Error capturing screen", ...);
```

A causa raiz só chega ao `debugPrint`, invisível em release.

**Impacto:** Todo o trabalho de diagnóstico feito nas camadas inferiores é jogado fora na borda da UI. O usuário recebe sempre a mesma mensagem genérica, seja por token inválido, ausência de rede, permissão negada, ZIP grande demais ou OOM no isolate. Isso contraria a diretriz de `copilot-instructions.md` § *Tratamento de Erros*: «Fornecer feedback via logs ou callbacks de erro quando o compartilhamento falhar» — os callbacks existem, mas não são consumidos. Torna o suporte a bugs em campo praticamente impossível.

---

#### GAP-11 · Isolate engole exceções e as converte em lista vazia
**Severidade:** Alto · **Agente:** Expert em Flutter/Dart
**Arquivos:** `lib/src/utils/image_processor.dart:75-78`

**Causa raiz:**
```dart
} catch (e) {
  debugPrint('❌ Error in image processing isolate: $e');
  return [];
}
```
Qualquer falha de processamento — PNG corrompido, `OutOfMemoryError` ao redimensionar para 2064×2752, `CastError` em `size['width'] as int`, chave `'suffix'` ausente — colapsa num único sintoma indistinguível: lista vazia. Os chamadores só conseguem reportar `'Failed to process screenshots (list is empty)'`. Pior: `debugPrint` executado dentro do isolate de `compute` **não é encaminhado de forma confiável** ao console do isolate principal em todas as plataformas, de modo que a mensagem original pode se perder por completo. Também não há `StackTrace` capturado nem rethrow de um erro tipado.

**Impacto:** A etapa mais provável de falhar (processamento de imagem pesado, sensível a memória e à entrada do usuário) é também a única sem rastreabilidade alguma. Combinado com o GAP-10, um OOM no isolate chega ao usuário como *"Error capturing screen"* e ao desenvolvedor como nada.

---

### 🟡 Médios

---

#### GAP-12 · Estado de concorrência global em singletons e falso-negativo de reentrância
**Severidade:** Médio · **Agente:** Arquiteto de Software
**Arquivos:** `screenshot_service.dart:24,56`, `screenshot_manager_service.dart:31-32,69,146`

**Causa raiz:** As flags `_isProcessing` / `_isCaptureProcessing` / `_isSendingProcessing` são campos de **singletons de processo**, não de instância por chamada. Consequências:
- Dois wrappers montados simultaneamente (cenário real: `example/lib/main.dart` alterna entre eles, e nada impede um `Navigator` com ambos vivos) compartilham e corrompem o mesmo estado.
- O early-return `if (_isProcessing) return false` é **indistinguível de uma falha real** para o chamador: a UI exibe *"Error capturing screen"* quando na verdade a operação foi apenas recusada por já haver outra em curso. Deveria ser um resultado tipado (`Result.busy`) ou uma exceção dedicada.
- Não há `Mutex`/fila serializada; o padrão de flag booleana não é à prova de interleaving entre o `await` do isolate e o `await` da rede.
- Não existe nenhuma noção de atomicidade (commit/rollback): em `processScreenshots`, se o ZIP é criado e o envio falha na metade, os buffers permanecem — correto — mas sem registro de tentativa, contador de falhas ou backoff.

**Impacto:** Mensagens de erro enganosas, estados travados após o GAP-06 (flag presa em `true` bloqueia o recurso globalmente), e impossibilidade de usar o pacote em dois contextos simultâneos (ex.: app multi-janela em desktop, que o `DeviceType` sugere suportar).

---

#### GAP-13 · `Overlay` como raiz da árvore e `initialEntries` estático
**Severidade:** Médio · **Agente:** Arquiteto de Software / Expert em Flutter/Dart
**Arquivos:** `screenshot_wrapper.dart:62-107`, `dual_button_wrapper.dart:94-180`

**Causa raiz:** Ambos os wrappers retornam `Overlay(initialEntries: [...])` como raiz. Dois defeitos:

1. **`initialEntries` é lido uma única vez**, na primeira construção do `Overlay`. Alterar `widget.mostrarBotao`/`mostrarBotoes` em runtime (ex.: um toggle de "modo desenvolvedor" no app hospedeiro) **não tem efeito algum** — a entrada do botão não é adicionada nem removida, porque o `if` dentro da lista não é reavaliado. A mudança de visibilidade anunciada como configurável só funciona se decidida antes da montagem.
2. **Antipadrão arquitetural:** envolver a aplicação em um `Overlay` adicional insere um `Overlay` "estranho" no caminho de `Overlay.of(context)`. Qualquer widget do app hospedeiro que resolva o overlay mais próximo (tooltips, `DropdownButton`, `SnackBar` via `ScaffoldMessenger`, drag-and-drop, `showMenu`) passa a inseri-los **neste** overlay — fora do controle do `Navigator`, sem gerenciamento de rota e sem participar das transições de página. Um `Stack` + `Positioned`, ou um `OverlayPortal`/`Overlay.of(context, rootOverlay: true)` sobre o overlay já existente do `MaterialApp`, seria o padrão correto.

**Impacto:** Visibilidade dinâmica não funcional (funcionalidade documentada e inoperante) e interferência sutil, difícil de diagnosticar, em widgets do app hospedeiro que dependem do overlay — classe de bug "botões sobrepõem conteúdo indevidamente" prevista em `AGENTS.md § 3`.

---

#### GAP-14 · Condição de corrida no toast de overlay
**Severidade:** Médio · **Agente:** Expert em Flutter/Dart
**Arquivos:** `screenshot_wrapper.dart:144-180`, `dual_button_wrapper.dart:246-283`

**Causa raiz:** `_showSimpleMessage` insere uma `OverlayEntry` e agenda `Future.delayed(2s, _removeOverlay)` — sem `Timer` cancelável e sem checagem de `mounted` no callback. Como `_removeOverlay()` opera sobre o campo `_overlayEntry` **atual**, e não sobre a entrada capturada no momento do agendamento:

- Duas mensagens em menos de 2 s (ex.: capturar e enviar em sequência rápida) fazem o timer da **primeira** remover a **segunda**, que desaparece prematuramente após alguns milissegundos.
- Se o widget for desmontado antes dos 2 s, `dispose()` já removeu a entrada; o `Future.delayed` pendente então executa `_removeOverlay()` sobre um `State` desmontado — inofensivo hoje apenas pelo acaso do `?.`, mas o `Future` mantém o `State` vivo por até 2 s após o desmonte.
- O `Future.delayed` não é cancelado em `dispose()`, perpetuando a retenção.

**Impacto:** Feedback visual que pisca ou desaparece antes de ser lido — e é o **único** canal de informação de resultado para o usuário (GAP-10). Retenção transitória de memória após a navegação.

---

#### GAP-15 · Sincronização frágil por `Future.delayed` antes da captura
**Severidade:** Médio · **Agente:** Expert em Flutter/Dart
**Arquivos:** `screenshot_wrapper.dart:112-118`, `dual_button_wrapper.dart:185-191`

**Causa raiz:** Para evitar que os botões apareçam na imagem, o código faz `setState(_botaoVisivel = false)` e aguarda `Future.delayed(300ms)`. Isso é uma suposição sobre o tempo de renderização, não uma garantia: o `AnimatedOpacity` leva 200 ms e, sob jank, GC ou dispositivo lento, o frame com opacidade 0 pode não ter sido composto quando `toImage()` é chamado. O correto é `WidgetsBinding.instance.addPostFrameCallback` (ou `endOfFrame`) após a mudança de estado. Além disso, `AnimatedOpacity` com opacidade 0 **mantém o widget na árvore e pintado** no ciclo de composição do `RepaintBoundary` — o uso de `Visibility`/`Offstage` seria mais seguro.

**Impacto:** Botões de captura intermitentemente visíveis nas screenshots geradas (bug clássico de difícil reprodução), e 300 ms de latência adicionados a cada captura sem necessidade.

---

#### GAP-16 · Ausência total de validação dos parâmetros de configuração
**Severidade:** Médio · **Agente:** Feature Implementer
**Arquivos:** `screenshot_config.dart:27-65`, `image_processor.dart:45-47`

**Causa raiz:** `ScreenshotConfig.configure()` aceita qualquer valor sem verificação:
- `imageQuality` não é restrito a 0–100 (`encodeJpg` com 500 ou −10 tem comportamento indefinido);
- `screenSizes` não é validado: as chaves `'width'`, `'height'`, `'suffix'` são assumidas existentes e com tipos exatos. `size['width'] as int` lança `TypeError` se o usuário escrever `1080.0` (um `double`, erro trivial em Dart), e `size['suffix'] as String` lança se a chave for omitida — tudo isso dentro do isolate, portanto convertido em lista vazia pelo GAP-11;
- larguras/alturas `≤ 0` ou absurdamente grandes não são rejeitadas (OOM direto);
- `savePath` não é validado quanto a existência, permissão de escrita ou travessia de caminho;
- `telegramToken`/`telegramChatId` não têm validação de formato (`isTelegramConfigValid` apenas testa não-vazio);
- `fileNamePrefix` não é sanitizado — caracteres `/ \ : * ? " < > |` vão direto para nomes de arquivo e entradas de ZIP (risco de *zip-slip* ao descompactar no destino).

**Impacto:** Erros de configuração do consumidor se manifestam tarde, longe da origem, e com mensagem inútil ("list is empty"). Em um pacote cuja única API de entrada é essa função estática, a ausência de `assert`/`ArgumentError` é uma lacuna séria de usabilidade de API pública — contrária à diretriz «Documente claramente todas as classes e métodos públicos exportados».

---

#### GAP-17 · Dependência não exportada torna parte da API pública inacessível, e há código morto
**Severidade:** Médio · **Agente:** Package Maintainer / Arquiteto de Software
**Arquivos:** `lib/screenshot_share.dart:1-22`, `storage_service.dart:110,139,169`, `screenshot_data.dart:35`, `screenshot_manager_service.dart:263`

**Causa raiz:** O barrel exporta `ScreenshotService`, `ScreenshotManagerService`, config, enums, model e os dois widgets — mas **não** `StorageService` nem `TelegramService`. Em consequência:
- `saveZipArchive()` e `shareZipArchive()` (61 linhas) são **inalcançáveis**: não são usadas internamente nem exportadas. Código morto publicado.
- `TelegramSendResult`, tipo de retorno de um serviço não exportado, é igualmente inacessível ao consumidor, embora carregue `statusCode` — exatamente o dado que o usuário precisaria para diagnosticar 400/401/404 (o cenário de `AGENTS.md § 3`).
- `createZipArchive(screenshots, archiveName)` recebe `archiveName` e **nunca o utiliza** (parâmetro morto); os chamadores passam `'screenshot'`/`'screenshots'` inutilmente.
- `ScreenshotData.fileSizeKB` e `ScreenshotManagerService.getAllGroupIds()` não têm nenhum consumidor.

**Impacto:** Superfície de API incoerente, código morto mantido e publicado, e o consumidor sem acesso programático ao diagnóstico de falhas de que mais precisa.

---

#### GAP-18 · Arquivos temporários nunca removidos
**Severidade:** Médio · **Agente:** Bug Hunter
**Arquivos:** `storage_service.dart:78-92,172-175`

**Causa raiz:** `shareScreenshots` cria `<temp>/share_<timestamp>/` e grava ali todos os JPEGs a cada invocação; `shareZipArchive` grava `<temp>/<name>_<timestamp>.zip`. Nenhum desses artefatos é removido — não há limpeza após o `Share` retornar, nem varredura de diretórios `share_*` antigos na inicialização, nem limite de retenção. Como o nome inclui um timestamp, cada compartilhamento cria um **novo** diretório, sem reuso.

**Impacto:** Crescimento monotônico do cache do app — alguns megabytes por compartilhamento. O sistema operacional pode eventualmente limpar o diretório temporário, mas sem garantia nem prazo; o usuário percebe o app ocupando centenas de megabytes de "cache" sem explicação.

---

#### GAP-19 · `lib/main.dart` "Hello World" publicado dentro do pacote
**Severidade:** Médio · **Agente:** Package Maintainer
**Arquivo:** `lib/main.dart` (20 linhas)

**Causa raiz:** Um `MainApp` com `Text('Hello World!')` reside em `lib/`, diretório cujo conteúdo é publicado e visível no pub.dev. O próprio `.github/copilot-instructions.md` marca explicitamente este arquivo: *«`main.dart` # (Evitar lógica aqui em packages)»*. Não há `.pubignore` para excluí-lo.

**Impacto:** Poluição da superfície do pacote, confusão para quem navega o código na página do pub.dev, e um `main()` extra no pacote que pode ser selecionado por engano como entrypoint por ferramentas e IDEs (o `.idea/runConfigurations/main_dart.xml` do repositório, de fato, aponta para um `main.dart`). Violação direta de uma regra escrita do projeto.

---

#### GAP-20 · O repositório não está estruturado como pacote publicável
**Severidade:** Médio · **Agente:** Package Maintainer
**Arquivos:** `example/` (sem `pubspec.yaml`), `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`

**Causa raiz:** Duas inconsistências estruturais:
1. **`example/` contém apenas `lib/main.dart`, sem `pubspec.yaml`.** Não é um pacote Dart: não compila, não roda (`cd example && flutter run` falha), e o pub.dev **não exibirá a aba "Example"** nem concederá os pontos de pontuação correspondentes. A diretriz «Manter o `example/` atualizado com novas funcionalidades» e o comando documentado `cd example && flutter run` são inexecutáveis hoje.
2. **O diretório raiz é um projeto de aplicação**, não de pacote: possui `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` completos (incluindo `MainActivity.kt`, `Info.plist`, `AppDelegate.swift`, ícones de launcher), além de `local.properties`, `.flutter-plugins` e `.flutter-plugins-dependencies` — artefatos de build versionados ou presentes em disco. Um pacote Dart puro não precisa de nenhuma dessas pastas; elas inflam o tarball publicado e induzem à leitura errada de que o `AndroidManifest.xml`/`Info.plist` da raiz é o do consumidor.

**Impacto:** Pontuação reduzida no pub.dev, exemplo não funcional (primeiro ponto de contato de todo novo usuário), tarball de publicação muito maior que o necessário, e ambiguidade sobre onde declarar permissões — ambiguidade que já se materializou no GAP-08.

---

#### GAP-21 · Supressão de lint mascarando API deprecada do `share_plus`
**Severidade:** Médio · **Agente:** Package Maintainer
**Arquivos:** `lib/src/services/storage_service.dart:1,95,178`

**Causa raiz:** O arquivo abre com `// ignore_for_file: deprecated_member_use`, ocultando dois usos de API removida na linha evolutiva do `share_plus` 12.x:
- `Share` (classe) → substituída por `SharePlus`;
- `Share.shareXFiles(...)` → substituída por `SharePlus.instance.share(ShareParams(files: ...))`.

É por isso que `flutter analyze` relata *"No issues found"* enquanto o `analysis.log` (artefato de uma execução anterior, ainda em disco) registra exatamente esses avisos. O `ignore_for_file` é de escopo largo: além dos dois usos conhecidos, ele silenciará **qualquer** depreciação futura introduzida neste arquivo — justamente o de maior contato com APIs de plataforma. Observa-se também, nas linhas 126-130, `final dynamic rawBytes = zipEncoder.encode(archive)` com cast via `dynamic` para contornar uma mudança de assinatura do `archive` 4.x — outra supressão de tipagem, essa implícita, que desativa a verificação estática do retorno.

**Impacto:** Um relatório de análise estática limpo, mas **falsamente** limpo: dívida técnica invisível ao CI e ao desenvolvedor. Na próxima major do `share_plus`, o código quebra em tempo de compilação sem qualquer aviso prévio acumulado. Contraria a diretriz «Siga as regras do `flutter_lints`».

---

#### GAP-22 · Internacionalização inexistente e idiomas misturados
**Severidade:** Médio · **Agente:** Doc Writer / Designer UI-UX
**Arquivos:** `screenshot_wrapper.dart:137`, `dual_button_wrapper.dart:209,239`, `telegram_service.dart:25,58,64`

**Causa raiz:** Todas as strings visíveis ao usuário são **hardcoded**, sem `Intl`, `ARB`, delegate de localização ou sequer parâmetros de override no construtor dos widgets. Pior, os idiomas estão **misturados dentro do mesmo fluxo**:

| Origem | Texto | Idioma |
|---|---|---|
| `screenshot_wrapper.dart:137` | `"Screenshot shared!"` / `"Error sharing screenshot"` | Inglês |
| `dual_button_wrapper.dart:209` | `"Screen captured!"` / `"Error capturing screen"` | Inglês |
| `telegram_service.dart:25` | `"Configuração inválida: Token ou Chat ID não definidos."` | Português |
| `telegram_service.dart:58` | `"Falha na API ($statusCode): $responseBody"` | Português |
| `telegram_service.dart:64` | `"Erro de conexão ou exceção: $e"` | Português |

Não há formatação localizada de datas (os timestamps são `millisecondsSinceEpoch` cru nos nomes de arquivo) nem de tamanhos de arquivo (`fileSizeKB` retorna um `double` sem formatação).

**Impacto:** Um app pt-BR exibe mensagens em inglês; um app internacional recebe mensagens em português vindas da camada de rede. Nenhuma das duas é customizável sem fork do pacote. Os textos em português só chegariam ao usuário via o callback `onError` — hoje descartado (GAP-10) —, o que mascara o problema sem resolvê-lo.

---

### 🔵 Baixos

---

#### GAP-23 · Acessibilidade: sem semântica, sem tooltip, sem suporte a teclado
**Severidade:** Baixo · **Agente:** Designer UI-UX
**Arquivos:** `screenshot_wrapper.dart:85-100`, `dual_button_wrapper.dart:126-172`

**Causa raiz:**
- Os `FloatingActionButton` não definem `tooltip` nem envolvem `Semantics(label:)`. Para TalkBack/VoiceOver, os botões se anunciam apenas como "botão" — sem indicar "capturar tela" ou "enviar capturas".
- O toast de overlay é um `Text` puro, sem `SemanticsService.announce()` nem `liveRegion: true`: o resultado da operação **não é anunciado** a leitores de tela. Combinado com o GAP-10, usuários de leitor de tela não recebem feedback algum.
- O `Badge` com o contador não tem rótulo semântico ("3 capturas pendentes").
- **Nenhum suporte a teclado físico:** não há `Shortcuts`/`Actions`/`CallbackShortcuts`, `Focus` explícito nem atalho configurável. O pacote declara `DeviceType.macos`, `windows` e `linux`, onde acionar uma captura por atalho de teclado é a interação natural e esperada; hoje só há toque/clique num FAB de 40 px.
- O estado `_processando` desabilita o botão (`onPressed: null`) sem anunciar a mudança.
- Contraste: as cores padrão usam `alpha: 0.7` sobre conteúdo arbitrário do app hospedeiro, sem garantia de razão de contraste WCAG para o ícone branco.

**Impacto:** Pacote inacessível a usuários de tecnologia assistiva e desconfortável em desktop. Baixo impacto funcional dado o perfil de ferramenta de desenvolvimento, mas relevante porque o pacote se propõe também a uso em produção.

---

#### GAP-24 · `DeviceType` de desktop mapeado para listas vazias
**Severidade:** Baixo · **Agente:** Feature Implementer
**Arquivos:** `screenshot_config.dart:97-100,119-143`, `device_type.dart:12-19`

**Causa raiz:** `_deviceSizes` declara `DeviceType.macos: []`, `windows: []`, `linux: []` — explicitamente comentado como *«Fallback or empty others for now»*. O getter `screenSizes` honra o filtro literalmente: configurar `deviceTypes: [DeviceType.windows]` produz uma lista **vazia**, que atravessa toda a pilha sem verificação até o isolate percorrer zero iterações e devolver `[]`, acionando o erro `'Failed to process screenshots (list is empty)'`. Também não há `assert` nem fallback no getter, e o `GUIA_DE_USO.md` lista apenas iPhone/iPad/Android como suportados — enquanto o enum público oferece seis opções, três delas inoperantes.

**Impacto:** Três dos seis valores da API pública de `DeviceType` são armadilhas: aceitos pela configuração, levam a uma falha genérica e inexplicável em tempo de execução. Deveriam ser ou implementados, ou marcados `@Deprecated`/removidos, ou rejeitados com `ArgumentError` claro.

---

#### GAP-25 · Documentação e instruções de projeto desatualizadas; ausência de `CLAUDE.md`
**Severidade:** Baixo · **Agente:** Doc Writer / Package Maintainer
**Arquivos:** `.github/copilot-instructions.md`, `README.md`, `CHANGELOG.md`, `GUIA_DE_USO.md`, `AGENTS.md`

**Causa raiz:** Divergências sistemáticas entre a documentação e o código atual (pubspec 0.1.4):

| Afirmação na documentação | Realidade no código |
|---|---|
| `copilot-instructions.md`: «Versão Atual: 0.1.1+1» | `pubspec.yaml`: 0.1.4 |
| `copilot-instructions.md`: «Dart SDK >=2.17.0 <4.0.0» | `pubspec.yaml`: `>=3.0.0 <4.0.0` |
| `copilot-instructions.md`: «Flutter >=2.5.0» | `pubspec.yaml`: `>=3.35.0` |
| `copilot-instructions.md`: `share_plus: ^10.1.2` | `^12.0.2` |
| `copilot-instructions.md`: `permission_handler: ^11.3.1` | `^13.0.2` |
| `copilot-instructions.md`: `archive: ^3.3.7` | `^4.6.0` |
| `copilot-instructions.md`: `image: ^4.0.17` | `^4.12.0` |
| `README.md:27`: `screenshot_share_telegram: ^0.1.0` | Deveria ser `^0.1.4` |
| `README.md:76,89-90`: `Colors.red.withOpacity(0.7)` | `withOpacity` está deprecado; o código usa `withValues(alpha:)` |
| `README.md`: não menciona `deviceTypes` | Recurso existe desde 0.1.2 e está no `GUIA_DE_USO.md` |
| `README.md:166-172`: permissões `WRITE/READ_EXTERNAL_STORAGE` | Inócuas em Android 13+ (ver GAP-08) |
| `README.md:176-179`: exige `NSPhotoLibraryAddUsageDescription` | Ausente de `ios/Runner/Info.plist` |

Adicionalmente, **o `CLAUDE.md` referenciado pelo documento-guia desta análise não existe neste repositório** — as regras obrigatórias ali previstas (padrões de UI, DDL v3 de banco, teclas de atalho, offline-first) não têm contraparte formal aqui; o mais próximo é o `.github/copilot-instructions.md`, usado como substituto nesta análise. E o checklist de `AGENTS.md § 1` («Verificar compatibilidade do SDK») não foi cumprido ao atualizar as dependências em 0.1.3/0.1.4, dado que as instruções ficaram atrasadas.

**Impacto:** Qualquer agente (humano ou IA) que siga `copilot-instructions.md` como fonte de verdade tomará decisões sobre uma matriz de dependências e um alvo de SDK errados — e, no caso das permissões, reproduzirá o GAP-08. O `README.md` é a primeira impressão no pub.dev e ensina API deprecada.

---

#### GAP-26 · Workflow de CI pertence a outro projeto
**Severidade:** Baixo · **Agente:** Package Maintainer
**Arquivo:** `.github/workflows/integrations.yml` (178 linhas)

**Causa raiz:** O único workflow do repositório é um pipeline de build Android **de um aplicativo de transporte universitário**: flavors `assuma`, `autape`, `taperatur`, `juletur`, com `--dart-define=DEFINE_API_ADDRESS=https://assuma.com.br/api`, targets `lib/app/layers/flavors/main_*.dart` (caminhos que não existem aqui), assinatura por keystore `autape.jks` e secrets `KEYSTORE_BASE64`. Além de não pertencer a este projeto, o workflow:
- dispara em `branches: [master]`, mas a branch deste repositório é **`main`** — portanto nunca executa;
- fixa `flutter-version: '3.32.5'`, abaixo do mínimo `>=3.35.0` declarado no `pubspec.yaml`;
- não executa `flutter analyze`, `flutter test` nem `flutter pub publish --dry-run` — nenhuma verificação do pacote, que é o que este repositório contém.

**Impacto:** Zero cobertura de CI: regressões não são detectadas automaticamente (os GAPs 01–24 passariam intactos por qualquer merge). Se a branch fosse renomeada para `master`, o pipeline falharia em todos os quatro flavors. E o arquivo é um vetor de confusão — sugere ao leitor que o repositório tem CI funcional.

---

#### GAP-27 · Cobertura de testes mínima e teste acoplado a estado global
**Severidade:** Baixo · **Agente:** Expert em Flutter/Dart
**Arquivo:** `test/flutter_screenshot_telegram_test.dart` (14 linhas)

**Causa raiz:** O único teste existente verifica três getters de `ScreenshotConfig` após um `configure()`. Não há cobertura de:
- `ImageProcessor` (a lógica mais complexa e mais propensa a falhar — GAP-04, GAP-11, GAP-16);
- `TelegramService` (nenhum mock de `http.Client`; os caminhos 200/400/401/413 e timeout são inteiramente não testados);
- `StorageService` (ZIP, permissões, diretórios);
- a lógica de precedência de `screenSizes` (`customSizes` > config > `deviceTypes` > padrão) — regra de negócio com quatro ramos;
- os wrappers (nenhum `testWidgets`);
- os guards de reentrância.

Além disso, o teste muta um **singleton global** sem chamar `ScreenshotConfig.resetToDefaults()` em `setUp`/`tearDown`. O método `resetToDefaults()` existe (`screenshot_config.dart:14`) e não é usado em nenhum lugar. Qualquer teste adicionado depois herdará `telegramToken: 'test_token'`, tornando a suíte dependente da ordem de execução.

**Impacto:** Nenhuma rede de segurança para as refatorações propostas na seção 3. A ausência de `resetToDefaults()` nos testes é uma bomba-relógio que se manifestará ao adicionar o segundo teste.

---

#### GAP-28 · Artefatos de desenvolvimento no repositório e ausência de `.pubignore`
**Severidade:** Baixo · **Agente:** Package Maintainer
**Arquivos:** `estrutura.py`, `analysis.log`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `android/local.properties`

**Causa raiz:** `estrutura.py` — um script de *scaffolding* que gera a árvore de diretórios do pacote com arquivos vazios/comentados — está **versionado** (`git ls-files` o confirma). Ele é a origem dos comentários-cabeçalho ainda presentes no código (`// Configurações para captura de tela`, `// Enum para modos de compartilhamento`, `// Serviço de armazenamento`) e, se executado por engano, **sobrescreveria** os arquivos-fonte com placeholders. `analysis.log` (saída UTF-16 de um `flutter analyze` antigo, hoje desatualizada e enganosa — ver GAP-21) está em disco, coberto por `*.log` no `.gitignore` mas presente no workspace. `.flutter-plugins`, `.flutter-plugins-dependencies` e `android/local.properties` (que contém caminhos absolutos da máquina do desenvolvedor) existem no diretório de trabalho. Não há `.pubignore` para controlar o que entra no tarball de publicação.

**Impacto:** Risco real de perda de código por execução acidental de `estrutura.py`; tarball de publicação maior que o necessário; e um `analysis.log` desatualizado em disco que pode levar um leitor a conclusões erradas sobre o estado da análise estática.

---

### 2.1 Resumo da matriz

| # | GAP | Severidade | Camada | Agente principal |
|---|---|---|---|---|
| 01 | Exposição do Bot Token em release | 🔴 Crítico | Serviço / Config | Bug Hunter |
| 02 | Buffer de capturas sem limite (OOM) | 🔴 Crítico | Serviço | Expert Flutter/Dart |
| 03 | Polling com `setState` a cada 1 s | 🔴 Crítico | UI | Expert Flutter/Dart |
| 04 | Distorção de aspect ratio + `pixelRatio` fixo | 🟠 Alto | Processamento | Feature Implementer |
| 05 | `ui.Image` nunca liberado | 🟠 Alto | Serviço | Expert Flutter/Dart |
| 06 | Sem timeout/retry na rede | 🟠 Alto | Integração | Bug Hunter |
| 07 | Limite de 50 MB do Telegram ignorado | 🟠 Alto | Integração | Bug Hunter |
| 08 | Permissão e diretório quebrados no Android 13+ | 🟠 Alto | Persistência | Bug Hunter |
| 09 | `ShareMode.multiple` não implementado | 🟠 Alto | Serviço | Feature Implementer |
| 10 | Mensagens de erro descartadas na UI | 🟠 Alto | UI | Designer UI-UX |
| 11 | Isolate engole exceções | 🟠 Alto | Processamento | Expert Flutter/Dart |
| 12 | Concorrência global em singletons | 🟡 Médio | Serviço | Arquiteto |
| 13 | `Overlay` raiz + `initialEntries` estático | 🟡 Médio | UI | Arquiteto |
| 14 | Corrida no toast de overlay | 🟡 Médio | UI | Expert Flutter/Dart |
| 15 | `Future.delayed(300ms)` antes da captura | 🟡 Médio | UI | Expert Flutter/Dart |
| 16 | Zero validação de configuração | 🟡 Médio | Config | Feature Implementer |
| 17 | API não exportada / código morto | 🟡 Médio | API pública | Package Maintainer |
| 18 | Temporários nunca limpos | 🟡 Médio | Persistência | Bug Hunter |
| 19 | `lib/main.dart` Hello World publicado | 🟡 Médio | Estrutura | Package Maintainer |
| 20 | Repositório não é um pacote publicável | 🟡 Médio | Estrutura | Package Maintainer |
| 21 | `ignore_for_file` mascarando depreciações | 🟡 Médio | Qualidade | Package Maintainer |
| 22 | i18n inexistente, idiomas misturados | 🟡 Médio | UI | Doc Writer |
| 23 | Acessibilidade e teclado físico ausentes | 🔵 Baixo | UI | Designer UI-UX |
| 24 | `DeviceType` desktop com listas vazias | 🔵 Baixo | Config | Feature Implementer |
| 25 | Documentação desatualizada; sem `CLAUDE.md` | 🔵 Baixo | Docs | Doc Writer |
| 26 | CI de outro projeto, nunca executa | 🔵 Baixo | DevOps | Package Maintainer |
| 27 | Cobertura de testes mínima | 🔵 Baixo | Testes | Expert Flutter/Dart |
| 28 | Artefatos de dev versionados, sem `.pubignore` | 🔵 Baixo | Estrutura | Package Maintainer |

**Totais:** 3 Críticos · 8 Altos · 11 Médios · 6 Baixos = **28 GAPs**

### 2.2 Observações sobre eixos não aplicáveis

As diretrizes do documento-guia pressupõem uma aplicação com Clean Architecture e persistência relacional. Registro explicitamente o que **não se aplica** a este alvo, para que a ausência não seja lida como omissão:

- **DDL v3 / SQLite / Hive:** inexistentes. O pacote não possui persistência estruturada. Isso é, em si, a causa raiz do GAP-02 (nada sobrevive ao fechamento do app) e remove qualquer discussão de migrações, índices ou integridade referencial.
- **Clean Architecture (UseCases / Entities / Repositories / Datasources):** não implementada. Não há violações a apontar porque não há camadas — há acoplamento direto de widget → singleton de serviço → I/O, sem inversão de dependência nem interface alguma (ver plano de solução, item 3.9). Nenhuma dependência é injetável, o que também é a razão da intestabilidade descrita no GAP-27.
- **Offline-first / sincronização / commit-rollback:** não existem como conceito no pacote. A operação de envio é *fire-and-forget* sem fila, sem persistência de pendências e sem detecção de conectividade. O comportamento atual em perda de conexão está coberto pelos GAPs 06 e 12.
- **WebSockets / microsserviços / múltiplos endpoints:** há uma única integração HTTP (Telegram `sendDocument`).
- **Cálculos de negócio / regras monetárias:** não há domínio de negócio. A única "regra de cálculo" é o redimensionamento de imagem, tratada no GAP-04.

---

## 3. Plano de Solução Recomendado

Organizado em 4 ondas, respeitando a arquitetura existente (singletons + serviços) nas primeiras e propondo a evolução arquitetural apenas na última. Cada item indica os arquivos a ajustar.

### Onda 1 — Correções críticas (alvo: versão `0.2.0`, *breaking* permitido)

#### 3.1 Segurança do token (GAP-01)

**Arquivos:** `telegram_service.dart`, `screenshot_config.dart`, `README.md`, `GUIA_DE_USO.md`, `example/lib/main.dart`

1. Introduzir um resolvedor de credenciais assíncrono em vez de `String` literal, permitindo que o consumidor busque o token de fonte segura em runtime:
   ```dart
   typedef TelegramCredentialsResolver = Future<TelegramCredentials?> Function();

   ScreenshotConfig.configure(
     credentialsResolver: () async => TelegramCredentials(
       token: await secureStorage.read(key: 'tg_token'),
       chatId: await secureStorage.read(key: 'tg_chat'),
     ),
   );
   ```
   Manter `telegramToken`/`telegramChatId` como atalho `@Deprecated` para não quebrar a 0.1.x de imediato.
2. Em `ScreenshotConfig`, adicionar verificação em modo release quando `shareMode` envolve Telegram e as credenciais vieram de literal: emitir aviso em `debugPrint` **uma única vez** e documentar a exposição.
3. **Nunca logar o corpo da resposta nem a URL completa.** Em `telegram_service.dart`, substituir por um log que não revela o token:
   ```dart
   debugPrint('📤 Telegram sendDocument → status $statusCode');
   // mensagem de erro: apenas statusCode + `description` extraída do JSON, nunca o body cru
   ```
4. Alterar `README.md` e `GUIA_DE_USO.md` para **não** mostrar token literal; recomendar `--dart-define` + `flutter_secure_storage` e alertar explicitamente que `showButtonsInDebugOnly: false` embute credenciais no binário.
5. Corrigir `example/lib/main.dart` para ler o token de `String.fromEnvironment('TELEGRAM_TOKEN')` e usar `shareMode: ShareMode.shareWithApps` como padrão do exemplo (funciona sem credencial e sem permissão).

#### 3.2 Buffer de capturas com limite e spill-to-disk (GAP-02, GAP-07, GAP-18)

**Arquivos:** `screenshot_manager_service.dart`, `storage_service.dart`, `screenshot_data.dart`

1. Alterar `ScreenshotData` para referenciar **arquivo em disco** em vez de manter `bytes` em memória:
   ```dart
   class ScreenshotData {
     final String path;          // arquivo no cache temporário
     final String filename;
     final int width, height, sizeInBytes;
     final String group;
     final int timestamp;
     Future<Uint8List> readBytes() => File(path).readAsBytes();
   }
   ```
   `ImageProcessor` passa a gravar cada JPEG no diretório de cache dentro do próprio isolate e devolver apenas os metadados. Isso elimina de uma vez o GAP-02 e o pico de memória do `createZipArchive`.
2. Eliminar a duplicação de referências: manter **apenas** `_captureGroups` e derivar a lista completa por `_captureGroups.values.expand(...)`, removendo `_allScreenshots`.
3. Adicionar à `ScreenshotConfig`: `maxStoredCaptures` (padrão 20) e `maxTotalBytes` (padrão 40 MB). Ao exceder, rejeitar a captura com erro **explícito e acionável** (`CaptureRejected.bufferFull`), não com `false` genérico.
4. Em `createZipArchive`, usar `ZipFileEncoder` em **modo streaming** para disco (`ZipFileEncoder()..create(path)..addFile(...)`) em vez de montar o `Archive` inteiro em memória; devolver o `File` do ZIP.
5. Antes de enviar ao Telegram, verificar `zipFile.lengthSync() > 45 * 1024 * 1024` e, se exceder, **fatiar em múltiplos ZIPs** sequenciais (`parte_1_de_3.zip`, ...), reportando progresso. Tratar HTTP 413 e o erro 400 `"file is too big"` com mensagem específica.
6. Implementar `StorageService.cleanupTemporaryArtifacts()`: remover diretórios `share_*` e ZIPs anteriores a 24 h; chamar no início de cada compartilhamento e após o envio bem-sucedido. Apagar o diretório `share_<ts>` logo após o `Share` retornar.

#### 3.3 Eliminar o polling de 1 segundo (GAP-03)

**Arquivos:** `screenshot_manager_service.dart`, `dual_button_wrapper.dart`

1. Expor o contador como `ValueListenable<int>` no serviço:
   ```dart
   final ValueNotifier<int> storedCount = ValueNotifier(0);
   // atualizar em captureScreen(), processScreenshots() e clearScreenshots()
   ```
2. No wrapper, **remover `_updateCounter()` por completo** e envolver somente o `Badge` em `ValueListenableBuilder<int>`. Isso reduz o escopo de rebuild do app inteiro para um único widget e elimina tanto o custo contínuo quanto a retenção pós-`dispose`.
3. Garantir `storedCount.dispose()` no `dispose` do serviço, ou documentar que o `ValueNotifier` é de ciclo de vida de processo (singleton).

### Onda 2 — Correções altas (alvo: `0.2.0`)

#### 3.4 Qualidade da imagem (GAP-04)

**Arquivos:** `image_processor.dart`, `screenshot_service.dart`, `screenshot_manager_service.dart`, `screenshot_config.dart`

1. Adicionar `ResizeStrategy { stretch, fitContain, fitCover }` à configuração, com **`fitContain` como padrão** (preserva proporção, preenche as bordas com uma cor configurável — comportamento esperado para screenshots de loja):
   ```dart
   final scale = math.min(target.width / src.width, target.height / src.height);
   final fitted = img.copyResize(src,
       width: (src.width * scale).round(),
       height: (src.height * scale).round(),
       interpolation: img.Interpolation.cubic);
   final canvas = img.Image(width: target.width, height: target.height)..clear(backgroundColor);
   img.compositeImage(canvas, fitted,
       dstX: (target.width - fitted.width) ~/ 2,
       dstY: (target.height - fitted.height) ~/ 2);
   ```
   Manter `stretch` como opção explícita para quem depender do comportamento atual.
2. Substituir `pixelRatio: 2.0` por um valor derivado do contexto, com teto para conter memória:
   ```dart
   final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
   final ratio = (config.captureOverridePixelRatio ?? dpr).clamp(1.0, 3.0);
   ```
   Isso exige propagar o `pixelRatio` do wrapper ao serviço — adicionar parâmetro `double? pixelRatio` em `captureAndShare`/`captureScreen`.
3. Trocar `Interpolation.linear` por `cubic` (ou `average` para redução) — reduções grandes com `linear` produzem aliasing visível.

#### 3.5 Robustez de I/O e permissões (GAP-05, GAP-06, GAP-08, GAP-11)

**Arquivos:** `screenshot_service.dart`, `screenshot_manager_service.dart`, `telegram_service.dart`, `storage_service.dart`, `image_processor.dart`

1. **Liberar o `ui.Image`** em `try/finally` nos dois serviços:
   ```dart
   ui.Image? image;
   try {
     image = await boundary.toImage(pixelRatio: ratio);
     final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
     // ...
   } finally {
     image?.dispose();
   }
   ```
2. **Timeout e cliente injetável** em `TelegramService`:
   ```dart
   TelegramService({http.Client? client, Duration? timeout})
       : _client = client ?? http.Client(),
         _timeout = timeout ?? const Duration(seconds: 60);

   final streamed = await _client.send(request).timeout(_timeout);
   ```
   Adicionar `sendTimeout`/`connectTimeout` à `ScreenshotConfig`, retry com *exponential backoff* (3 tentativas) apenas para erros de rede e HTTP 5xx/429 — **nunca** para 400/401 (erro de configuração, retry é inútil) —, e honrar o header `Retry-After` em 429.
3. **Corrigir o fluxo de permissão:**
   - Remover a chamada a `Permission.storage` quando o destino é diretório privado do app (caso padrão) — ela nunca foi necessária.
   - Para salvar em local visível ao usuário, usar `Permission.photos` (`addOnly` no iOS) ou a API de galeria, e gravar via `MediaStore` no Android (ou delegar a um pacote como `gal`), tornando as screenshots **encontráveis**.
   - Preferir `getDownloadsDirectory()`/`MediaStore.Downloads` em Android 10+ como destino padrão visível.
   - Distinguir `denied` de `permanentlyDenied` e, no segundo caso, oferecer `openAppSettings()` na mensagem de erro.
   - Atualizar `README.md` com a matriz real de permissões por versão de Android/iOS e adicionar `NSPhotoLibraryAddUsageDescription` ao `ios/Runner/Info.plist`.
4. **Erros tipados no isolate:** criar `ImageProcessingException` com `stage` (`decode`/`resize`/`encode`), índice do tamanho em processamento e `StackTrace`, e **relançar** em vez de retornar `[]`. `compute` propaga exceções ao chamador normalmente; capturá-las no serviço e encaminhá-las a `onError` com a mensagem detalhada. Substituir `debugPrint` no isolate por informação carregada na exceção (logs do isolate não são confiáveis).

#### 3.6 Feedback de erro e `ShareMode.multiple` (GAP-09, GAP-10, GAP-12, GAP-22)

**Arquivos:** ambos os wrappers, ambos os serviços, novo `lib/src/models/screenshot_result.dart`, novo `lib/src/config/screenshot_strings.dart`

1. **Substituir `Future<bool>` por um resultado tipado** em `captureAndShare`, `captureScreen` e `processScreenshots`:
   ```dart
   sealed class ScreenshotResult {
     const ScreenshotResult();
   }
   class ScreenshotSuccess extends ScreenshotResult { final int count; /* ... */ }
   class ScreenshotBusy extends ScreenshotResult {}   // resolve o falso-negativo do GAP-12
   class ScreenshotFailure extends ScreenshotResult {
     final ScreenshotErrorKind kind;   // network, auth, permission, tooLarge, processing, config, noData
     final String message;
     final int? statusCode;
     final Object? cause;
     final StackTrace? stackTrace;
   }
   ```
   Isso elimina a ambiguidade entre "ocupado" e "falhou", preserva `statusCode` (hoje inacessível — GAP-17) e dá aos wrappers o material para uma mensagem útil.
2. **Consumir o resultado nos wrappers:** exibir `failure.message` no toast, com a cor derivada de `kind`, e expor callbacks `onCaptureResult`/`onShareResult` nos construtores dos wrappers para que o app hospedeiro possa integrar seu próprio sistema de notificação (SnackBar, Crashlytics, Sentry).
3. **Implementar `ShareMode.multiple` de verdade:** exibir um `showModalBottomSheet`/diálogo com as opções disponíveis (Telegram só se `isTelegramConfigValid`), ou — se a intenção for executar todos — renomear o enum para `ShareMode.telegramAndLocal` e executar ambos, agregando os resultados. **Escolher uma das duas semânticas e alinhar enum, Dartdoc, README e código.** Recomendo o diálogo, por ser o que a documentação pública já promete.
4. **Externalizar as strings:** criar `ScreenshotStrings` com todos os textos como campos, `const ScreenshotStrings.ptBr()` / `.en()`, e aceitar `strings:` em `ScreenshotConfig.configure()` e nos wrappers. Eliminar todo literal visível ao usuário de dentro de widgets e serviços — incluindo as três mensagens em português do `TelegramService` (GAP-22). Padronizar o idioma interno do código e dos comentários em um só (recomendo inglês no código, dado o público do pub.dev; a documentação pode permanecer bilíngue).

### Onda 3 — Correções médias (alvo: `0.2.x`)

#### 3.7 Camada de UI (GAP-13, GAP-14, GAP-15, GAP-23)

**Arquivos:** `screenshot_wrapper.dart`, `dual_button_wrapper.dart`

1. **Substituir `Overlay(initialEntries:)` por `Stack`**, resolvendo o GAP-13 em ambas as frentes:
   ```dart
   return Stack(children: [
     RepaintBoundary(key: _repaintKey, child: widget.child),
     if (widget.mostrarBotoes)
       Positioned.fill(
         child: IgnorePointer(ignoring: !_botoesVisiveis, child: Align(/* ... */)),
       ),
   ]);
   ```
   Como o `build` é reavaliado, a visibilidade passa a responder a mudanças em runtime, e o overlay do `MaterialApp` deixa de ser sombreado.
2. **Toast cancelável e correto:** guardar `Timer? _toastTimer`, cancelá-lo antes de agendar um novo e em `dispose()`; capturar a `OverlayEntry` na closure para que cada timer remova **a sua própria** entrada. Alternativamente, expor `onMessage` e deixar o app hospedeiro usar `ScaffoldMessenger` (preferível: integra-se ao tema e à acessibilidade do app).
3. **Sincronização determinística antes da captura:** substituir `Future.delayed(300ms)` por
   ```dart
   setState(() => _botoesVisiveis = false);
   await WidgetsBinding.instance.endOfFrame;   // garante o frame sem botões composto
   ```
   e usar `Visibility(visible: _botoesVisiveis, maintainState: true)` em vez de `AnimatedOpacity`, para que o widget realmente não seja pintado.
4. **Acessibilidade:** adicionar `tooltip` e `Semantics(label:, button: true)` a cada FAB (textos vindos de `ScreenshotStrings`); `SemanticsService.announce(message, TextDirection.ltr)` ao exibir o toast; rótulo semântico no `Badge`; e suporte a atalho de teclado configurável via `CallbackShortcuts` (`Ctrl/Cmd + Shift + S` como padrão sugerido), atendendo ao requisito de teclado físico e aos `DeviceType` de desktop.

#### 3.8 Validação, API pública e estrutura do pacote (GAP-16, GAP-17, GAP-19, GAP-20, GAP-21, GAP-24)

**Arquivos:** `screenshot_config.dart`, `screenshot_share.dart`, `storage_service.dart`, `lib/main.dart`, `example/pubspec.yaml`, novo `.pubignore`

1. **Validar em `configure()`**, falhando rápido e com mensagem clara:
   ```dart
   if (imageQuality != null) {
     if (imageQuality < 1 || imageQuality > 100) {
       throw ArgumentError.value(imageQuality, 'imageQuality', 'Deve estar entre 1 e 100');
     }
     _instance._imageQuality = imageQuality;
   }
   ```
   Criar uma classe tipada `ScreenSize({required int width, required int height, required String suffix})` para **substituir `Map<String, dynamic>`** — elimina de raiz os `as int`/`as String` do isolate (GAP-16) e documenta a API. Manter uma sobrecarga que aceite `List<Map>` convertendo com validação, marcada `@Deprecated`. Sanitizar `fileNamePrefix` e `suffix` contra `/ \ : * ? " < > |` e `..` (zip-slip).
2. **Resolver os `DeviceType` vazios (GAP-24):** preencher resoluções reais para `macos`/`windows`/`linux` (ex.: 1280×800, 1920×1080, 2560×1600) **ou** marcá-los `@Deprecated('Not supported yet')`. Em qualquer caso, fazer o getter `screenSizes` lançar `StateError` com mensagem explícita se o resultado final for vazio, em vez de deixar a falha emergir como "list is empty" três camadas abaixo.
3. **Exportar o que é API (GAP-17):** adicionar `export 'src/services/telegram_service.dart';` (ao menos `TelegramSendResult`) e `export 'src/services/storage_service.dart';`, **ou** remover `saveZipArchive`/`shareZipArchive` como código morto. Remover o parâmetro inutilizado `archiveName` de `createZipArchive` (ou passá-lo a usar). Remover `ScreenshotData.fileSizeKB` e `getAllGroupIds()` se permanecerem sem consumidor.
4. **Remover `lib/main.dart` (GAP-19)** — nenhum pacote deve expor um `main()` acidental.
5. **Reparar `example/` (GAP-20):** criar `example/pubspec.yaml` apontando para a raiz por caminho:
   ```yaml
   name: screenshot_share_example
   environment:
     sdk: '>=3.0.0 <4.0.0'
   dependencies:
     flutter:
       sdk: flutter
     screenshot_share_telegram:
       path: ../
   ```
   e um `example/android` + `example/ios` mínimos, movendo para lá as plataformas hoje na raiz. Adicionar `.pubignore` excluindo `estrutura.py`, `analysis.log`, `.idea/`, `*.iml`, `android/local.properties` e as pastas de plataforma da raiz (GAP-28).
6. **Remover `// ignore_for_file: deprecated_member_use` (GAP-21)** e migrar para a API atual do `share_plus` 12:
   ```dart
   await SharePlus.instance.share(
     ShareParams(files: filesToShare, subject: 'Screenshots', text: '...'),
   );
   ```
   Se alguma supressão ainda for inevitável, usar `// ignore:` **na linha específica**, nunca no arquivo. Substituir o `final dynamic rawBytes = zipEncoder.encode(...)` por tipagem explícita conforme a assinatura do `archive` 4.x.

### Onda 4 — Evolução estrutural (alvo: `0.3.0`)

#### 3.9 Testabilidade e injeção de dependência (GAP-12, GAP-27)

**Arquivos:** todos os serviços, novas interfaces em `lib/src/services/`, `test/`

1. Extrair interfaces (`ScreenshotCapturer`, `ImageProcessorInterface`, `ScreenshotUploader`, `ScreenshotStorage`) e permitir injeção nos construtores dos serviços, mantendo os singletons apenas como **conveniência de fachada**:
   ```dart
   class ScreenshotManagerService {
     ScreenshotManagerService({ScreenshotUploader? uploader, ScreenshotStorage? storage});
     static final ScreenshotManagerService instance = ScreenshotManagerService();
   }
   ```
   Essa é a mudança mínima que viabiliza mock de `http.Client` e de sistema de arquivos — hoje impossível, e a razão pela qual a cobertura de testes é de um único getter.
2. Substituir as flags `bool` por um **lock serializado** (`Completer`-based mutex ou `package:synchronized`), com `ScreenshotBusy` como resultado explícito em vez de `false` ambíguo.
3. **Suíte de testes mínima** (`test/`), em `setUp` sempre chamando `ScreenshotConfig.resetToDefaults()` para quebrar o acoplamento ao singleton global:
   - `screenshot_config_test.dart`: precedência de `screenSizes` (4 ramos), validações de `configure()`, `shouldShowButtons`, `isTelegramConfigValid`;
   - `image_processor_test.dart`: PNG válido → N imagens com dimensões corretas; preservação de proporção; PNG corrompido → `ImageProcessingException`; `ScreenSize` inválido → erro tipado;
   - `telegram_service_test.dart`: `MockClient` para 200, 400, 401, 413, 429 com `Retry-After`, timeout e exceção de socket;
   - `storage_service_test.dart`: ZIP com N entradas e nomes sanitizados; limpeza de temporários;
   - `wrapper_test.dart` (`testWidgets`): botão invisível no frame capturado; toggle de visibilidade em runtime; toast não removido prematuramente por timer anterior; ausência de rebuild periódico.

   Meta inicial de cobertura: **70%** em `lib/src/` (hoje, efetivamente ~5%).

#### 3.10 CI/CD e documentação (GAP-25, GAP-26, GAP-28)

**Arquivos:** `.github/workflows/`, `.github/copilot-instructions.md`, `README.md`, `CHANGELOG.md`, novo `CLAUDE.md`

1. **Excluir `integrations.yml`** (pertence a outro projeto, aponta para branch inexistente e nunca executou) e criar `.github/workflows/package_ci.yml` disparando em `push`/`pull_request` na branch **`main`**:
   ```yaml
   - uses: subosito/flutter-action@v2
     with: {flutter-version: '3.35.4', channel: stable}
   - run: flutter pub get
   - run: dart format --output=none --set-exit-if-changed .
   - run: flutter analyze --fatal-infos          # falha também em `info`
   - run: flutter test --coverage
   - run: flutter pub publish --dry-run
   - run: cd example && flutter pub get && flutter build apk --debug
   ```
   O `--fatal-infos` é essencial para que a dívida hoje escondida pelo `ignore_for_file` (GAP-21) não se reacumule.
2. **Sincronizar `.github/copilot-instructions.md`** com o `pubspec.yaml` real (versão, SDK, Flutter, 6 dependências) e adicionar uma nota de processo: *atualizar este arquivo faz parte do checklist de bump de versão* (`AGENTS.md § 1`).
3. **Criar `CLAUDE.md`** na raiz, consolidando as regras obrigatórias do pacote — o arquivo é referenciado pelo processo de análise e não existe. Conteúdo mínimo: política de segurança de credenciais (3.1), limites de memória e buffer (3.2), proibição de `ignore_for_file` amplo, exigência de resultado tipado em APIs públicas, padrão de i18n via `ScreenshotStrings`, e o checklist de publicação.
4. **Atualizar `README.md`:** versão de instalação `^0.2.0`; substituir `withOpacity` por `withValues(alpha:)`; documentar `deviceTypes`, `ScreenSize`, `ResizeStrategy`, `ScreenshotResult` e timeouts; reescrever a seção de permissões com a matriz real por versão de SO; adicionar o aviso de segurança do token em destaque.
5. **Registrar tudo em `CHANGELOG.md`** sob `0.2.0`, marcando claramente as **breaking changes** (retorno tipado em vez de `bool`, `ScreenSize` em vez de `Map`, remoção de `lib/main.dart`, resolvedor de credenciais), conforme SemVer exigido por `copilot-instructions.md § Versionamento`.
6. **Remover `estrutura.py` do versionamento** (`git rm --cached estrutura.py` + entrada no `.gitignore`) — é um gerador de scaffolding que sobrescreveria os fontes se executado — e apagar `analysis.log` do disco.

### 3.11 Sequenciamento sugerido

| Onda | Escopo | GAPs resolvidos | Breaking? |
|---|---|---|---|
| 1 | Segurança, memória, performance | 01, 02, 03, 07, 18 | Sim (credenciais, `ScreenshotData`) |
| 2 | Imagem, rede, permissões, feedback | 04, 05, 06, 08, 09, 10, 11, 22 | Sim (resultado tipado) |
| 3 | UI, validação, estrutura do pacote | 12\*, 13, 14, 15, 16, 17, 19, 20, 21, 23, 24 | Sim (`ScreenSize`, exports) |
| 4 | DI, testes, CI, documentação | 12, 25, 26, 27, 28 | Não |

\* O GAP-12 é parcialmente mitigado na Onda 2 (resultado `ScreenshotBusy`) e resolvido na Onda 4 (lock serializado + DI).

Como as Ondas 1–3 acumulam *breaking changes*, recomendo publicá-las juntas como **`0.2.0`**, mantendo a 0.1.4 disponível, e reservar a Onda 4 para **`0.3.0`** — que, por ser internamente aditiva (DI com padrões retrocompatíveis), não quebra consumidores.

---

## 4. Conclusão

O pacote entrega a funcionalidade central anunciada e tem organização de diretórios limpa e legível, com uma decisão arquitetural acertada: o processamento de imagem já roda em isolate via `compute`, evitando travar a UI. A separação em `config`/`enums`/`models`/`services`/`utils`/`widgets` é coerente e facilita a navegação.

Os problemas mais graves, porém, são concentrados e sistêmicos. Três deles afetam qualquer uso real:

1. **O token do Telegram é exposto** por indução da própria documentação (GAP-01) — a falha de maior consequência, porque o dano vaza para fora da aplicação.
2. **A memória é gerenciada incorretamente em duas frentes independentes e cumulativas** — buffer de capturas sem limite nem persistência (GAP-02) e `ui.Image` nativa nunca liberada (GAP-05) —, o que torna o crash por memória o desfecho provável de uma sessão de uso normal, exatamente no momento do envio e com perda total das capturas.
3. **O artefato produzido sai visualmente errado** (GAP-04): sem preservação de proporção, as screenshots ficam esticadas em praticamente toda combinação dispositivo × resolução alvo, inviabilizando o caso de uso de geração de imagens para as lojas de aplicativos.

Há ainda um padrão transversal que merece destaque, porque não é um defeito isolado mas uma característica do código: **a informação de erro é consistentemente degradada ao subir pelas camadas**. O isolate converte qualquer exceção em lista vazia (GAP-11), os serviços convertem causas distintas em `bool` (GAP-12), e os wrappers descartam os callbacks que carregariam a mensagem real (GAP-10). O resultado é que toda falha — token inválido, offline, permissão negada, ZIP grande demais ou OOM — chega ao usuário como a mesma frase genérica, e ao desenvolvedor como nada em release. Esse é o alvo mais rentável de refatoração: o `ScreenshotResult` tipado proposto em 3.6 resolve simultaneamente três GAPs e torna todos os demais diagnosticáveis em campo.

Por fim, o repositório **não está pronto para publicação como pacote**: o `example/` não compila por falta de `pubspec.yaml` (GAP-20), um `lib/main.dart` "Hello World" é publicado (GAP-19), o CI pertence a outro projeto e nunca executou (GAP-26), a análise estática está artificialmente limpa por supressão de lint (GAP-21), e a cobertura de testes é de um único getter (GAP-27). Nada disso afeta quem já usa a 0.1.4, mas tudo isso significa que **as correções acima não têm hoje nenhuma rede de proteção automática** — razão pela qual recomendo tratar a Onda 4 (DI, testes, CI) não como último item de prioridade, mas como pré-requisito executado em paralelo às Ondas 1–3.

---

*Análise realizada em 06/11/2026 sobre o commit `f613184` (branch `main`), seguindo as diretrizes de `d:/Projetos/Flutter/Lucival/pdv_app/pdv_app/docs/realizar-analise-tecnica.md`, as regras de `.github/copilot-instructions.md` (em substituição ao `CLAUDE.md` inexistente — GAP-25) e os papéis definidos em `AGENTS.md`.*
