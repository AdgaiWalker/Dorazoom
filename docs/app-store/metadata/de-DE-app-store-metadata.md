# Deutsch (Deutschland) (`de-DE`) · App Store Connect-Metadaten

> Entwurf für die erste App-Store-Version · 2026-08-20
> App Store Connect-Sprache: **Deutsch**
> App-Locale: `de`

## 0. Zusammenfassung der Lokalisierung

| Punkt | Wert |
|---|---|
| App-Locale | `de` |
| String Catalog | Wird im gemeinsamen Katalog-Workstream gepflegt; dieses Dokument beansprucht keine vollständige Katalogabdeckung |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/de.lproj/InfoPlist.strings` |
| Sprachverhalten | `system_only`; folgt der App- bzw. Systemsprache von macOS |
| Persistierte lokalisierte Daten | Durch diese Metadatenarbeit werden keine lokalisierten Anzeigewerte gespeichert |
| KI-Grenze | Teilt visuellen Kontext mit bereits genutzten KI-Tools; keine integrierte KI behauptet |

## 1. App Store Connect-Grenzwerte

| Feld | Limit |
|---|---:|
| App-Name | 30 Zeichen |
| Untertitel | 30 Zeichen |
| Werbetext | 170 Zeichen |
| Beschreibung | 4.000 Zeichen |
| Keywords | 100 Zeichen |
| Neuigkeiten | 4.000 Zeichen |

## 2. Metadaten

### 2.1 App Name

```text
DoraZoom: Bildschirm markieren
```

### 2.2 Subtitle

```text
Aufmerksamkeit gezielt lenken
```

### 2.3 Promotional Text

```text
Zoome, zeichne, markiere, nutze OCR und nimm den Bildschirm auf, ohne Zeit zu verlieren. Erkläre deinem Team, deinem Publikum und deinen KI-Tools klar, was zählt.
```

### 2.4 Description

```text
Mach das Wichtige unübersehbar.

DoraZoom ist ein natives macOS-Werkzeug für Kreative, die Ideen erklären, Arbeit zeigen und visuell zusammenarbeiten. Zoome in jeden Bildschirminhalt, zeichne direkt darüber und erfasse genau den Kontext, den andere brauchen – ohne deinen Arbeitsfluss zu unterbrechen.

KERNWERKZEUGE
• Lenke Aufmerksamkeit mit statischem oder Live-Zoom.
• Zeichne mit Stiften, Formen, Pfeilen, Text, Markierungen, nummerierten Hinweisen, Weichzeichnung und Abdeckung.
• Erfasse einen Bereich oder ein Fenster in der Zwischenablage oder als Datei und erkenne sichtbaren Text per OCR.
• Nimm einen Bildschirm, Bereich oder ein Fenster auf – optional mit Mikrofon, Systemaudio, Kamera im Bild-in-Bild-Modus und Pause/Fortsetzen.
• Erstelle scrollende Panoramaaufnahmen für Seiten und Unterhaltungen, die nicht auf einen Bildschirm passen.
• Nutze DemoType, weiße und schwarze Tafeln sowie einen Pausentimer, um Live-Erklärungen zu strukturieren.

ENTWICKELT FÜR
• Tutorial-Produzenten, Lehrende, Vortragende und Streamer.
• Designer, Entwickler und Produktteams, die Arbeit gemeinsam prüfen.
• Kreative, die Menschen oder bereits genutzten KI-Tools klaren visuellen Kontext geben.

DoraZoom enthält keine integrierte KI und führt keine Cloud-Inferenz aus. Du bestimmst selbst, was du aufnimmst und teilst.

Datenschutzrichtlinie: TBD
Nutzungsbedingungen: TBD
```

### 2.5 Keywords

```text
zeichnen,bildschirmfoto,aufnahme,präsentation,whiteboard,ocr,panorama,tutorial,kreative,teamarbeit
```

### 2.6 What's New

```text
Willkommen bei DoraZoom. Die erste App-Store-Version bringt Kreativen auf dem Mac Zoom- und Zeichenwerkzeuge zum gezielten Lenken der Aufmerksamkeit, Screenshots und OCR, Bildschirmaufnahme, Panorama, DemoType sowie Weichzeichnungs- und Abdeckwerkzeuge.
```

## 3. Texte für App-Store-Screenshots

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Sofort auf den Punkt kommen** | Hineinzoomen und auf jedem Bildschirm zeichnen |
| 02 | **Erklären ohne App-Wechsel** | Stifte, Formen, Pfeile, Text und Markierungen nutzen |
| 03 | **Kontext für Menschen und KI** | Bildschirmfotos erstellen oder sichtbaren Text per OCR erfassen |
| 04 | **Aufzeichnen, was zählt** | Visuelle Hervorhebungen bleiben in der Bildschirmaufnahme |
| 05 | **Klar teilen, Privates schützen** | Sensible Details vor der Aufnahme weichzeichnen oder abdecken |
| 06 | **In deiner Sprache arbeiten** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Kopierfertige Liste:

```text
01 Sofort auf den Punkt kommen · Hineinzoomen und auf jedem Bildschirm zeichnen
02 Erklären ohne App-Wechsel · Stifte, Formen, Pfeile, Text und Markierungen nutzen
03 Kontext für Menschen und KI · Bildschirmfotos erstellen oder sichtbaren Text per OCR erfassen
04 Aufzeichnen, was zählt · Visuelle Hervorhebungen bleiben in der Bildschirmaufnahme
05 Klar teilen, Privates schützen · Sensible Details vor der Aufnahme weichzeichnen oder abdecken
06 In deiner Sprache arbeiten · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Ergebnis der Zeichenprüfung

Mit dem Projekt-Validator geprüft. Die gemessenen Werte stehen im Implementierungsbericht.

## 5. Technische Änderungen

| Datei | Änderung |
|---|---|
| `Sources/ZoomItMacCore/Resources/de.lproj/InfoPlist.strings` | Lokalisierte Hinweise zur Mikrofon- und Kameranutzung |
| `docs/app-store/metadata/de-DE-app-store-metadata.md` | Store-Metadaten und sechs Screenshot-Texte |

## 6. Laufzeit- und Release-Prüfungen

- Die App folgt der App- bzw. Systemsprache von macOS; es gibt keinen Sprachschalter in der App.
- Berechtigungsdialoge folgen der macOS-Sprache und verwenden die lokalisierte `InfoPlist.strings`.
- App-Name, Statusmenü, Einstellungen, Aufnahme/OCR, Bildschirmaufnahme, Panorama und DemoType bei einem sauberen deutschen Start prüfen.
- **Release-Blocker:** Beide `TBD`-Rechtslinks vor der App-Store-Einreichung durch freigegebene öffentliche URLs ersetzen.
