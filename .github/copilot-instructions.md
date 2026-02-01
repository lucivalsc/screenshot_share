# Copilot Instructions - Screenshot Share Telegram Package

## Contexto do Projeto

- **Nome:** screenshot_share_telegram
- **Tipo:** Flutter Package
- **Versão Atual:** 0.1.1+1
- **Linguagem:** Dart (SDK >=2.17.0 <4.0.0)
- **Framework:** Flutter (>=2.5.0)
- **Repositório:** https://github.com/lucivalsc/screenshot_share.git

## Objetivo do Pacote

Pacote Flutter para capturar screenshots e compartilhá-las via Telegram (Bot API), armazenamento local ou diálogo de compartilhamento do sistema. Projetado para facilitar o reporte de bugs e compartilhamento de telas durante o desenvolvimento e produção.

## Funcionalidades Principais

- Captura de tela programática.
- Modos de operação: Botão Único (captura e envia) ou Botão Duplo (captura e gerencia).
- Envio para Telegram (Requer Bot Token e Chat ID).
- Salvamento em armazenamento local.
- Compartilhamento via `share_plus`.
- Redimensionamento de imagens.
- Overlay de botões configurável (apenas debug ou sempre).

## Estrutura do Projeto

```
lib/
├── screenshot_share.dart              # Arquivo de exportação principal
├── main.dart                          # (Evitar lógica aqui em packages)
└── src/                               # Implementação interna
    ├── config/                        # Configurações (ScreenshotConfig)
    ├── services/                      # Serviços (ScreenshotService, TelegramService)
    ├── widgets/                       # Widgets (Wrapper, Buttons)
    └── utils/                         # Utilitários (Image resizing, file handling)
example/                               # App de exemplo para testes
test/                                  # Testes unitários e de widget
```

## Dependências Principais

```yaml
http: ^1.1.0                # Comunicação com API do Telegram
archive: ^3.3.7             # Manipulação de arquivos (se necessário)
image: ^4.0.17              # Processamento e resize de imagens
path_provider: ^2.1.1       # Acesso ao sistema de arquivos
share_plus: ^10.1.2         # Compartilhamento nativo
permission_handler: ^11.3.1 # Gerenciamento de permissões
```

## Diretrizes de Desenvolvimento

### Práticas de Código
- **Public API:** Documente claramente todas as classes e métodos públicos exportados em `screenshot_share.dart`.
- **Null Safety:** Utilize null safety estritamente.
- **Assincronismo:** Use `async/await` para operações de I/O e rede. Trate erros de timeout e falhas de conexão.
- **Linter:** Siga as regras do `flutter_lints`.
- **Const:** Use construtores `const` sempre que possível para otimização.

### Tratamento de Erros
- Validar tokens e IDs do Telegram antes de enviar.
- Tratar negação de permissões de armazenamento.
- Fornecer feedback via logs ou callbacks de erro quando o compartilhamento falhar.

### Testes
- Manter o `example/` atualizado com novas funcionalidades.
- Testar em Android e iOS (verificar permissões no `AndroidManifest.xml` e `Info.plist`).

## Comandos Comuns

```bash
# Instalar dependências
flutter pub get

# Rodar exemplo
cd example
flutter run

# Analisar código
flutter analyze

# Rodar testes
flutter test
```

## Versionamento

Seguir Semantic Versioning (SemVer):
- **Major:** Mudanças que quebram compatibilidade (breaking changes).
- **Minor:** Novas funcionalidades compatíveis com versões anteriores.
- **Patch:** Correções de bugs compatíveis com versões anteriores.
