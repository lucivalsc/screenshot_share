# CLAUDE.md — Regras obrigatórias do pacote `screenshot_share_telegram`

Este arquivo consolida as regras que **todo** contribuidor (humano ou agente)
deve seguir neste repositório. Em caso de conflito, este arquivo vence sobre
`.github/copilot-instructions.md`.

Complementos:
- Papéis e especialidades: [`AGENTS.md`](AGENTS.md)
- Contexto e comandos: [`.github/copilot-instructions.md`](.github/copilot-instructions.md)
- Histórico de decisões técnicas: [`docs/`](docs/)

---

## 1. Identidade do projeto

| Item | Valor |
|---|---|
| Nome | `screenshot_share_telegram` |
| Tipo | Flutter **package** (não é aplicação) |
| Versão | ver `pubspec.yaml` — fonte única de verdade |
| Dart SDK | `>=3.0.0 <4.0.0` |
| Flutter | `>=3.35.0` |
| Dependências | `archive`, `image`, `path_provider`, `share_plus` |

> **Atenção:** o nome do pacote conserva `_telegram` por compatibilidade com
> o pub.dev, mas **não existe mais integração com o Telegram** desde a 0.2.0.
> Não reintroduza.

---

## 2. Segurança de credenciais — regra absoluta

**O pacote não aceita, não armazena e não transmite credenciais.**

- ❌ Proibido adicionar token, chave de API, segredo ou `chat_id` à
  `ScreenshotConfig` ou a qualquer outra classe.
- ❌ Proibido adicionar dependência de rede (`http`, `dio`, `web_socket`) para
  enviar capturas a um serviço externo.
- ✅ Destinos permitidos: sistema de arquivos local e share sheet nativo.

**Motivo:** até a 0.1.4 o pacote exigia um Bot Token do Telegram que, seguindo
a documentação então vigente, acabava hardcoded no `main.dart` do app
consumidor e embutido no binário de release, extraível por `strings` no
APK/IPA. O token também compunha a URL da requisição, aparecendo em logs de
proxy. Era a falha mais grave do pacote e foi eliminada pela raiz, removendo
a funcionalidade em vez de mitigá-la.

Se um integrador precisar de envio automatizado, ele deve fazê-lo no **app
dele**, com o segredo sob o controle dele, consumindo `ScreenshotData` via a
API pública.

---

## 3. Memória e recursos nativos

Regras não negociáveis, cada uma correspondendo a um bug corrigido:

1. **`ui.Image` sempre em `try/finally` com `dispose()`.** O bitmap vive na
   memória nativa, fora do GC do Dart; cada captura vazava 8–30 MB.
2. **Bytes de imagem nunca residem em campo de longa duração.** Variantes são
   gravadas no cache e referenciadas por caminho (`ScreenshotData.path`).
   Nunca reintroduza `Uint8List bytes` no modelo.
3. **Todo buffer acumulativo tem limite.** Respeite `maxStoredCaptures` e
   `maxTotalBytes`; ao exceder, falhe com `ScreenshotErrorKind.bufferFull` e
   faça rollback dos arquivos já gravados.
4. **ZIP sempre via streaming** (`ZipFileEncoder` para arquivo). Nunca monte
   um `Archive` completo em memória.
5. **Nenhum `Timer`/`Future.delayed` recorrente para observar estado.** Use
   `ValueNotifier`/`Listenable`. Todo `Timer` criado é guardado em campo e
   cancelado em `dispose()`.
6. **Arquivos temporários são limpos.** Toda rota que grava em
   `getTemporaryDirectory()` tem contraparte em
   `StorageService.cleanupTemporaryArtifacts()`.

---

## 4. Contrato da API pública

1. **Resultado tipado, nunca `bool`.** Operações públicas retornam
   `ScreenshotResult` (`ScreenshotSuccess` / `ScreenshotBusy` /
   `ScreenshotCancelled` / `ScreenshotFailure`). `ScreenshotBusy` **não é
   erro** e não deve ser exibido como tal.
2. **Nenhum `Map<String, dynamic>` em parâmetro público.** Use tipos
   validados (`ScreenSize`, `ScreenshotStrings`).
3. **Validação na fronteira.** `configure()` lança `ArgumentError` em valor
   inválido. É proibido deixar um erro de configuração emergir três camadas
   abaixo como "lista vazia".
4. **Erros tipados, nunca engolidos.** Proibido `catch (e) { return []; }` ou
   equivalente. Use a hierarquia de `screenshot_exceptions.dart`, preservando
   `cause` e `stackTrace`.
5. **Todo símbolo exportado é documentado** com Dartdoc. Nada de código morto
   ou inalcançável em `lib/`.
6. **Nenhum `main()` em `lib/`.**

---

## 5. UI, i18n e acessibilidade

1. **Proibido envolver a app em um `Overlay` próprio.** Use `Stack`; isso
   sequestrava tooltips, menus e `SnackBar` do app hospedeiro.
2. **Visibilidade reavaliada em todo `build`.** Nada de
   `Overlay.initialEntries`, que é lido uma única vez.
3. **Sincronização de frame determinística.** Antes de capturar, use
   `WidgetsBinding.instance.endOfFrame`, nunca `Future.delayed` arbitrário.
   Oculte botões com `Visibility`, não `AnimatedOpacity` (opacidade 0 continua
   sendo pintada no `RepaintBoundary`).
4. **Zero string hardcoded visível ao usuário.** Tudo em `ScreenshotStrings`.
   Um único idioma por tabela — nunca misture inglês e português no mesmo
   fluxo.
5. **Acessibilidade obrigatória:** `Semantics(label:)` em todo botão e
   `SemanticsService.announce()` em toda mensagem de resultado — ambos
   incondicionais. O `tooltip` é adicionado **somente** quando existe um
   `Overlay` ancestral (`Overlay.maybeOf(context) != null`): `Tooltip` lança
   assertion sem ele, e no uso documentado (`MaterialApp.builder`) o wrapper
   fica acima do `Navigator` que o fornece. Nunca torne o tooltip
   incondicional — há teste de regressão para isso.
6. **Teclado físico suportado** onde há `DeviceType` de desktop:
   `Ctrl/Cmd + Shift + S` captura, `Ctrl/Cmd + Shift + E` envia.
7. **Proporção preservada por padrão** (`ResizeStrategy.fitContain`).
   `stretch` existe apenas como opção explícita de compatibilidade.

---

## 6. Permissões e armazenamento

1. **Não adicione `permission_handler` de volta.** Os destinos padrão são
   diretórios que o app sempre pode escrever, sem permissão nenhuma.
2. **Proibido `Permission.storage`.** É obsoleta no Android 13+ (API 33) e
   retorna *denied* permanentemente; pedir permissão para um diretório
   privado do app quebrou o salvamento local na maioria dos aparelhos.
3. `savePath` customizado deve ser gravável sem permissão extra; se falhar,
   erre com `ScreenshotErrorKind.permission` e mensagem acionável.
4. **Todo destino recebe um único ZIP.** Nunca entregue arquivos soltos.

---

## 7. Qualidade e CI

1. `flutter analyze --fatal-infos` deve passar **limpo**.
2. **Proibido `// ignore_for_file:` de escopo amplo.** Se uma supressão for
   inevitável, use `// ignore:` na linha específica, com comentário
   justificando. Um relatório falsamente limpo é pior que um relatório sujo.
3. **Proibido contornar tipagem com `dynamic`** para acomodar mudança de
   assinatura de dependência. Ajuste o código ao tipo real.
4. `dart format` aplicado a todo o repositório.
5. Todo bug corrigido ganha um teste de regressão. Meta de cobertura em
   `lib/src/`: **70%**.
6. Testes **sempre** chamam `ScreenshotConfig.resetToDefaults()` em `setUp` —
   a configuração é um singleton de processo e vaza entre testes.
7. O `example/` deve compilar (`cd example && flutter pub get && flutter build
   apk --debug`). É o primeiro contato de todo usuário novo.

---

## 8. Checklist de publicação

Antes de `flutter pub publish`:

- [ ] `version` atualizada no `pubspec.yaml` seguindo **SemVer**
- [ ] `CHANGELOG.md` atualizado, com *breaking changes* explicitamente marcadas
- [ ] `README.md` sem API deprecada e com a versão de instalação correta
- [ ] `.github/copilot-instructions.md` sincronizado com o `pubspec.yaml`
      (versão, SDK, dependências) — este passo era omitido e deixou as
      instruções 3 versões atrasadas
- [ ] `flutter analyze --fatal-infos` limpo
- [ ] `flutter test` verde
- [ ] `flutter pub publish --dry-run` sem avisos
- [ ] `example/` compilando
- [ ] Nenhum artefato de desenvolvimento versionado (scripts de scaffolding,
      `*.log`, `local.properties`)
