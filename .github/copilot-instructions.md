# Copilot Instructions - Screenshot Share

> **Regras obrigatórias:** este arquivo descreve o contexto do projeto. As
> regras que **devem** ser seguidas estão em [`CLAUDE.md`](../CLAUDE.md), que
> prevalece em caso de conflito. Papéis especializados em
> [`AGENTS.md`](../AGENTS.md).

## Contexto do Projeto

- **Nome:** `screenshot_share_telegram`
- **Tipo:** Flutter Package (não é aplicação)
- **Versão Atual:** 0.2.0
- **Linguagem:** Dart (SDK `>=3.0.0 <4.0.0`)
- **Framework:** Flutter (`>=3.35.0`)
- **Repositório:** https://github.com/lucivalsc/screenshot_share.git

> O sufixo `_telegram` no nome é mantido apenas por compatibilidade com o
> pub.dev. **A integração com o Telegram foi removida na 0.2.0 e não deve ser
> reintroduzida** — ver `CLAUDE.md`, seção 2.

## Objetivo do Pacote

Capturar screenshots do app e entregá-las como **um único arquivo ZIP**,
salvando no dispositivo ou acionando o share sheet nativo. Projetado para
facilitar o reporte de bugs e a geração de imagens para lojas de aplicativos.

## Funcionalidades Principais

- Captura programática de qualquer subárvore de widgets.
- Dois modos: botão único (captura e entrega) ou botão duplo (lote).
- Destinos: salvamento local, share sheet nativo, ou seletor (`askUser`).
- Geração de variantes por resolução, com proporção preservada por padrão.
- Buffer de capturas em disco, com limites de memória configuráveis.
- Resultados tipados (`ScreenshotResult`) com mensagens diagnósticas.
- Strings localizáveis, acessibilidade e atalhos de teclado.
- Overlay de botões configurável (apenas debug ou sempre).
- **Zero credenciais, zero chamadas de rede, zero permissões de runtime.**

## Estrutura do Projeto

```
lib/
├── screenshot_share.dart              # Barrel de exportação pública
└── src/
    ├── config/
    │   ├── screenshot_config.dart     # Configuração global validada
    │   └── screenshot_strings.dart    # Textos (en / ptBr)
    ├── enums/
    │   ├── device_type.dart
    │   ├── resize_strategy.dart
    │   └── share_mode.dart
    ├── exceptions/
    │   └── screenshot_exceptions.dart # Hierarquia de erros tipados
    ├── models/
    │   ├── screen_size.dart           # Resolução alvo validada
    │   ├── screenshot_data.dart       # Metadados (bytes ficam em disco)
    │   └── screenshot_result.dart     # Resultado selado
    ├── services/
    │   ├── capture_pipeline.dart      # Captura + despacho compartilhados
    │   ├── screenshot_service.dart    # Modo botão único
    │   ├── screenshot_manager_service.dart # Modo lote
    │   └── storage_service.dart       # ZIP, arquivos, share nativo
    ├── utils/
    │   ├── async_lock.dart
    │   ├── file_name_sanitizer.dart
    │   └── image_processor.dart       # Isolate: decode/resize/encode/write
    └── widgets/
        ├── dual_button_wrapper.dart
        ├── feedback_overlay.dart      # Toast + mapeamento de resultado
        ├── screenshot_wrapper.dart
        └── share_mode_sheet.dart      # Seletor do ShareMode.askUser
example/                               # App de exemplo (pacote completo)
test/                                  # 60 testes
docs/                                  # Análises técnicas
```

**Não crie `lib/main.dart`** — um pacote não deve expor um `main()`.

## Dependências Principais

```yaml
archive: ^4.6.0        # Montagem do ZIP por streaming
image: ^4.12.0         # Decode, resize e encode
path_provider: ^2.1.1  # Diretórios de cache e destino
share_plus: ^12.0.2    # Share sheet nativo
```

Removidas na 0.2.0: `http` (sem rede) e `permission_handler` (sem permissões).
**Não as readicione** sem revisar `CLAUDE.md`, seções 2 e 6.

## Diretrizes de Desenvolvimento

### Práticas de Código
- **Public API:** documente com Dartdoc todo símbolo exportado.
- **Resultado tipado:** operações públicas retornam `ScreenshotResult`, nunca
  `bool`. `ScreenshotBusy` não é erro.
- **Sem `Map<String, dynamic>`** em parâmetro público — use `ScreenSize`.
- **Null safety** estrito e construtores `const` quando possível.
- **Assincronismo:** `async/await` em I/O. Libere recursos nativos
  (`ui.Image.dispose()`) em `try/finally`.
- **Linter:** `flutter analyze --fatal-infos` limpo. Proibido
  `ignore_for_file` de escopo amplo.

### Tratamento de Erros
- Valide a configuração na fronteira, com `ArgumentError`.
- Nunca engula exceções (`catch (e) { return []; }` é proibido); use a
  hierarquia de `screenshot_exceptions.dart` preservando `cause`/`stackTrace`.
- Propague a mensagem diagnóstica até a UI.

### Testes
- `ScreenshotConfig.resetToDefaults()` em todo `setUp`.
- Todo bug corrigido ganha teste de regressão. Meta: 70% em `lib/src/`.
- Mantenha o `example/` compilando e atualizado.

## Comandos Comuns

```bash
flutter pub get                  # Instalar dependências
dart format .                    # Formatar
flutter analyze --fatal-infos    # Analisar
flutter test --coverage          # Testar
flutter pub publish --dry-run    # Conferir o pacote

cd example && flutter pub get && flutter run   # Rodar o exemplo
```

## Versionamento

Seguir Semantic Versioning (SemVer):
- **Major:** mudanças que quebram compatibilidade.
- **Minor:** novas funcionalidades retrocompatíveis.
- **Patch:** correções retrocompatíveis.

> **Manter este arquivo sincronizado com o `pubspec.yaml` faz parte do
> checklist de bump de versão** (`CLAUDE.md`, seção 8). Ele ficou três versões
> atrasado entre a 0.1.1 e a 0.1.4.
