# Português (Brasil) (`pt-BR`) · Metadados do App Store Connect

> Rascunho para a primeira versão na App Store · 2026-08-20
> Idioma no App Store Connect: **Português (Brasil)**
> Localidade do app: `pt-BR`

## 0. Resumo da localização

| Item | Valor |
|---|---|
| Localidade do app | `pt-BR` |
| String Catalog | Gerenciado no fluxo compartilhado do catálogo; este documento não afirma que o catálogo esteja completo |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/pt-BR.lproj/InfoPlist.strings` |
| Comportamento de idioma | `system_only`; segue o idioma do app ou do sistema no macOS |
| Dados localizados persistentes | Este trabalho de metadados não adiciona textos localizados aos dados persistentes |
| Limite de IA | Compartilha contexto visual com ferramentas de IA que a pessoa já usa; não afirma ter IA integrada |

## 1. Limites do App Store Connect

| Campo | Limite |
|---|---:|
| Nome do app | 30 caracteres |
| Subtítulo | 30 caracteres |
| Texto promocional | 170 caracteres |
| Descrição | 4.000 caracteres |
| Palavras-chave | 100 caracteres |
| Novidades | 4.000 caracteres |

## 2. Metadados

### 2.1 App Name

```text
DoraZoom: anote sua tela
```

### 2.2 Subtitle

```text
Guie a atenção no seu Mac
```

### 2.3 Promotional Text

```text
Amplie, desenhe, anote, extraia texto com OCR e grave sem perder o ritmo. Explique com clareza para sua equipe, seu público e as ferramentas de IA que você já usa.
```

### 2.4 Description

```text
Torne o que importa impossível de ignorar.

O DoraZoom é uma ferramenta nativa do macOS para criadores que explicam ideias, demonstram trabalhos e colaboram visualmente. Amplie qualquer tela, desenhe diretamente sobre ela e capture o contexto que outras pessoas precisam sem interromper seu fluxo.

FERRAMENTAS PRINCIPAIS
• Direcione a atenção com zoom estático ou ao vivo.
• Desenhe com canetas, formas, setas, texto, marca-texto, marcadores numerados, desfoque e tarja.
• Capture uma região ou janela para a área de transferência ou um arquivo e extraia o texto visível com OCR.
• Grave uma tela, região ou janela com microfone, áudio do sistema, câmera em imagem sobre imagem e pausa/retomada opcionais.
• Crie capturas panorâmicas com rolagem para páginas e conversas que não cabem em uma tela.
• Use DemoType, os modos quadro branco e quadro preto e um temporizador de pausa para dar estrutura a explicações ao vivo.

FEITO PARA
• Criadores de tutoriais, educadores, apresentadores e streamers.
• Designers, desenvolvedores e equipes de produto que analisam trabalhos em conjunto.
• Criadores que compartilham contexto visual claro com pessoas ou com as ferramentas de IA que já usam.

O DoraZoom não inclui IA integrada nem inferência na nuvem. Você controla o que captura e compartilha.

Política de Privacidade: https://dorazoom.iwalk.pro/privacy/
Termos de Uso: https://dorazoom.iwalk.pro/terms/
```

### 2.5 Keywords

```text
desenho,captura,gravação,apresentação,quadro,ocr,panorama,tutorial,criador,colaboração
```

### 2.6 What's New

```text
Boas-vindas ao DoraZoom. Esta primeira versão na App Store traz aos criadores no Mac zoom e desenho para guiar a atenção, capturas e OCR, gravação de tela, capturas panorâmicas, DemoType e ferramentas de desfoque e tarja.
```

## 3. Textos para capturas promocionais

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Vá direto ao que importa** | Amplie e desenhe sobre qualquer tela |
| 02 | **Explique sem trocar de app** | Use canetas, formas, setas, texto e marca-texto |
| 03 | **Contexto para pessoas e ferramentas de IA** | Capture imagens ou extraia texto visível com OCR |
| 04 | **Grave onde está a atenção** | Mantenha a ênfase visual na gravação de tela |
| 05 | **Compartilhe com clareza e controle** | Desfoque ou cubra detalhes sensíveis antes da captura |
| 06 | **Trabalhe no seu idioma** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Lista pronta para copiar:

```text
01 Vá direto ao que importa · Amplie e desenhe sobre qualquer tela
02 Explique sem trocar de app · Use canetas, formas, setas, texto e marca-texto
03 Contexto para pessoas e ferramentas de IA · Capture imagens ou extraia texto visível com OCR
04 Grave onde está a atenção · Mantenha a ênfase visual na gravação de tela
05 Compartilhe com clareza e controle · Desfoque ou cubra detalhes sensíveis antes da captura
06 Trabalhe no seu idioma · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Resultado da validação de caracteres

Verificado com o validador do projeto. Os valores medidos constam no relatório de implementação.

## 5. Alterações técnicas

| Arquivo | Alteração |
|---|---|
| `Sources/ZoomItMacCore/Resources/pt-BR.lproj/InfoPlist.strings` | Motivos localizados de acesso ao microfone e à câmera |
| `docs/app-store/metadata/pt-BR-app-store-metadata.md` | Metadados da loja e seis textos para capturas |

## 6. Verificações de execução e lançamento

- O app segue o idioma do app ou do sistema no macOS; não adiciona um seletor de idioma interno.
- Os diálogos de permissão seguem o idioma do macOS e usam o arquivo `InfoPlist.strings` localizado.
- Verifique o nome, menu de status, ajustes, captura/OCR, gravação, panorama e DemoType após uma inicialização limpa em português do Brasil.
- **Bloqueio de lançamento:** substitua os dois links legais the public legal pages por URLs públicas aprovadas antes de enviar o app à App Store.
