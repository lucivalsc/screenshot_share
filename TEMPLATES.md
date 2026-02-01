# Templates de Solicitação - Screenshot Share Telegram

## Como Usar
Copie o template, preencha as informações e envie para a IA.

---

## Sumário
1. [Nova Feature](#1-template-nova-feature)
2. [Report de Bug](#2-template-report-de-bug)
3. [Atualização de Documentação](#3-template-atualização-de-documentação)

---

## 1. Template: Nova Feature

```markdown
## Nova Feature: [Nome da Feature]

### Descrição
[O que a feature deve fazer? Ex: Adicionar suporte a envio para WhatsApp]

### Tipo de Mudança
- [ ] Lógica de Captura
- [ ] Integração (Telegram/Local/Share)
- [ ] Widget/UI (Botões, Overlay)
- [ ] Configuração

### Requisitos
- [ ] Precisa de nova dependência? [Qual?]
- [ ] Afeta a API pública? [Sim/Não]
- [ ] Requer nova permissão no Android/iOS?

### Comportamento Esperado
[Descreva como o usuário vai interagir com essa feature]

### Exemplo de Uso (API)
```dart
// Como o usuário chamará essa feature?
ScreenshotConfig.configure(
  // ...
);
```
```

---

## 2. Template: Report de Bug

```markdown
## Bug: [Título do Erro]

### Descrição
[O que está acontecendo? Ex: Falha ao enviar para Telegram em Release mode]

### Passos para Reproduzir
1. [Configuração usada]
2. [Ação realizada]
3. [Erro observado]

### Logs / Stack Trace
```
[Cole o erro aqui]
```

### Ambiente
- Flutter version: [ex: 3.19.0]
- Platform: [Android / iOS / Web]
- Device: [ex: Pixel 7]

### Hipóteses
- [ ] Problema de Permissão
- [ ] Erro de Rede
- [ ] Configuração incorreta
```

---

## 3. Template: Atualização de Documentação

```markdown
## Docs: [Título]

### Arquivo a Alterar
- [ ] README.md
- [ ] CHANGELOG.md
- [ ] Dartdoc (Comentários no código)

### Conteúdo Atual
[Trecho desatualizado ou faltando]

### Novo Conteúdo Proposto
[O que deve ser escrito]

### Motivo
[Clareza, Nova Feature, Correção de erro]
```
