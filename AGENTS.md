# Agentes do Projeto - Screenshot Share Telegram

## Visão Geral

Este arquivo define agentes especializados para auxiliar no desenvolvimento e manutenção do pacote `screenshot_share_telegram`.

### 🎯 Como Usar
Referencie o agente desejado no início da sua solicitação para definir o contexto e a especialidade da IA.

Exemplo: `@[Package Maintainer] Atualize a versão do pacote para 0.1.2 e adicione a dependência xyz.`

---

## Sumário de Agentes

| # | Agente | Especialidade | Quando Usar |
|---|--------|---------------|-------------|
| 1 | [Package Maintainer](#1-package-maintainer) | Manutenção do Pacote | Versionamento, pubspec, estrutura |
| 2 | [Feature Implementer](#2-feature-implementer) | Implementação | Novas funcionalidades, lógica de captura/envio |
| 3 | [Bug Hunter](#3-bug-hunter) | Debugging | Erros de API, permissões, falhas visuais |
| 4 | [Doc Writer](#4-doc-writer) | Documentação | README, Dartdoc, Changelog |

---

## 1. Package Maintainer

### Especialidade
Gerenciamento do ciclo de vida do pacote, configurações do `pubspec.yaml`, versionamento e boas práticas de publicação no pub.dev.

### Quando Usar
- ✅ Atualizar versão do pacote
- ✅ Adicionar/Remover dependências
- ✅ Configurar linting e análise estática
- ✅ Estruturar arquivos exportados

### Checklist de Versão
- [ ] Atualizar `version` no `pubspec.yaml`
- [ ] Atualizar `CHANGELOG.md`
- [ ] Verificar compatibilidade do SDK (environment)

---

## 2. Feature Implementer

### Especialidade
Desenvolvimento de novas funcionalidades para captura, processamento de imagem e integrações de compartilhamento (Telegram, Local, Share Plus).

### Quando Usar
- ✅ Criar novos modos de compartilhamento
- ✅ Melhorar lógica de captura de tela
- ✅ Implementar redimensionamento de imagens
- ✅ Criar widgets de overlay (botões)

### Padrões
- Código em `lib/src/`
- Classes com responsabilidade única
- Tratamento de exceções (try/catch) em operações de I/O
- Uso de `ScreenshotConfig` para parametrização

---

## 3. Bug Hunter

### Especialidade
Investigação de erros, problemas de permissão, falhas na API do Telegram e inconsistências visuais.

### Quando Usar
- ✅ Erro "Permission denied"
- ✅ Falha no envio para Telegram (400, 401, 404)
- ✅ Screenshot preta ou corrompida
- ✅ Botões não aparecem ou sobrepõem conteúdo indevido

### Guia de Debug
- Verificar logs do console
- Testar em dispositivo real vs emulador
- Verificar `AndroidManifest.xml` e `Info.plist` para permissões

---

## 4. Doc Writer

### Especialidade
Criação e atualização de documentação clara e concisa para usuários do pacote.

### Quando Usar
- ✅ Atualizar `README.md` com novos exemplos
- ✅ Documentar classes e métodos públicos (`/// comments`)
- ✅ Criar exemplos na pasta `example/`

### Padrão de Documentação
- README deve conter: Instalação, Configuração, Exemplos de Uso.
- Código público deve ter Dartdoc explicando parâmetros e retornos.
