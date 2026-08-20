# English (U.S.) (`en-US`) · App Store Connect Metadata

> Draft for the first App Store release · 2026-08-20
> App Store Connect language: **English (U.S.)**
> App binary locale: `en` (development language)

## 0. Localization audit summary

| Item | Value |
|---|---|
| App locale | `en` |
| String Catalog | Managed in the shared catalog workstream; this document does not claim catalog completion |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/en.lproj/InfoPlist.strings` |
| Language behavior | `system_only`; follows the macOS per-app/system language |
| Persisted localized data | No localized display values introduced by this metadata work |
| AI claim boundary | Shares visual context with AI tools the user already uses; no built-in AI claim |

## 1. App Store Connect checklist

| Field | Limit |
|---|---:|
| App name | 30 characters |
| Subtitle | 30 characters |
| Promotional text | 170 characters |
| Description | 4,000 characters |
| Keywords | 100 characters |
| What's New | 4,000 characters |

## 2. Metadata

### 2.1 App Name

```text
DoraZoom: Screen Annotation
```

### 2.2 Subtitle

```text
Guide attention on your Mac
```

### 2.3 Promotional Text

```text
Zoom, draw, annotate, capture, OCR, and record without losing your flow. Make every explanation easier to follow—for collaborators, audiences, and the AI tools you use.
```

### 2.4 Description

```text
Make the important part impossible to miss.

DoraZoom is a native macOS attention-guidance tool for creators who explain ideas, demonstrate work, and collaborate visually. Zoom into any screen, draw directly over what you see, and capture the context people need—without breaking your flow.

CORE TOOLS
• Guide attention with static or live zoom.
• Draw with pens, shapes, arrows, text, highlights, numbered callouts, blur, and redaction.
• Capture a region or window to the clipboard or a file, then extract visible text with OCR.
• Record a display, region, or window with optional microphone, system audio, webcam picture-in-picture, and pause/resume.
• Build scrolling panorama captures for pages and conversations that do not fit on one screen.
• Use DemoType, whiteboard and blackboard canvases, and a break timer when a live explanation needs structure.

BUILT FOR
• Tutorial makers, educators, presenters, and streamers.
• Designers, developers, and product teams reviewing work together.
• Creators sharing clear visual context with people or the AI tools they already use.

DoraZoom does not claim built-in AI or cloud inference. Your capture and permission choices remain under your control.

Privacy Policy: TBD
Terms of Use: TBD
```

### 2.5 Keywords

```text
draw,screenshot,recording,presentation,whiteboard,ocr,panorama,tutorial,creator,collaboration
```

### 2.6 What's New

```text
Welcome to DoraZoom. This first App Store release brings attention-guided zoom and drawing, screenshots and OCR, screen recording, panorama capture, DemoType, and privacy-focused blur and redaction tools to macOS creators.
```

## 3. Promotional screenshot copy

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Make the point instantly** | Zoom in and draw over any screen |
| 02 | **Explain without switching apps** | Use pens, shapes, arrows, text, and highlights |
| 03 | **Share context with people and AI** | Capture screenshots or extract visible text with OCR |
| 04 | **Record where attention moves** | Keep live visual emphasis in your screen recording |
| 05 | **Share clearly, not accidentally** | Blur or cover sensitive details before capture |
| 06 | **Work in your language** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Copy-ready list:

```text
01 Make the point instantly · Zoom in and draw over any screen
02 Explain without switching apps · Use pens, shapes, arrows, text, and highlights
03 Share context with people and AI · Capture screenshots or extract visible text with OCR
04 Record where attention moves · Keep live visual emphasis in your screen recording
05 Share clearly, not accidentally · Blur or cover sensitive details before capture
06 Work in your language · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Character-limit results

| Field | Characters | Limit | Status |
|---|---:|---:|---|
| App name | 27 | 30 | Pass |
| Subtitle | 27 | 30 | Pass |
| Promotional text | 168 | 170 | Pass |
| Description | 1,241 | 4,000 | Pass |
| Keywords | 93 | 100 | Pass |
| What's New | 222 | 4,000 | Pass |

The keyword field is also 93 UTF-8 bytes.

## 5. Engineering changes

| File | Change |
|---|---|
| `Sources/ZoomItMacCore/Resources/en.lproj/InfoPlist.strings` | Localized microphone/camera permission purposes |
| `docs/app-store/metadata/en-US-app-store-metadata.md` | Store metadata and six screenshot captions |

## 6. Runtime and release checks

- The app follows the macOS per-app/system language; it does not add an in-app language switch.
- Permission dialogs follow the macOS language and read this locale's `InfoPlist.strings`.
- Verify the app name, status menu, settings, capture/OCR, recording, panorama, and DemoType on a clean English launch.
- **Release blocker:** replace both `TBD` legal links with approved public URLs before App Store submission.
