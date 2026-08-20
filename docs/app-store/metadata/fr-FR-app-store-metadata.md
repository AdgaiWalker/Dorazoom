# Français (France) (`fr-FR`) · Métadonnées App Store Connect

> Brouillon pour la première version App Store · 2026-08-20
> Langue App Store Connect : **Français**
> Locale de l’app : `fr`

## 0. Résumé de la localisation

| Élément | Valeur |
|---|---|
| Locale de l’app | `fr` |
| String Catalog | Géré dans le chantier de catalogue partagé ; ce document ne prétend pas que le catalogue est complet |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/fr.lproj/InfoPlist.strings` |
| Comportement linguistique | `system_only` ; suit la langue de l’app ou du système dans macOS |
| Données localisées persistantes | Ce travail de métadonnées n’ajoute aucune valeur d’affichage localisée aux données persistantes |
| Limite IA | Partage du contexte visuel avec les outils d’IA déjà utilisés ; aucune IA intégrée revendiquée |

## 1. Limites App Store Connect

| Champ | Limite |
|---|---:|
| Nom de l’app | 30 caractères |
| Sous-titre | 30 caractères |
| Texte promotionnel | 170 caractères |
| Description | 4 000 caractères |
| Mots-clés | 100 caractères |
| Nouveautés | 4 000 caractères |

## 2. Métadonnées

### 2.1 App Name

```text
DoraZoom : annoter l’écran
```

### 2.2 Subtitle

```text
Guidez l’attention sur Mac
```

### 2.3 Promotional Text

```text
Zoomez, dessinez, annotez, utilisez l’OCR et enregistrez l’écran sans perdre le fil. Expliquez clairement à vos équipes, à votre public et à vos outils d’IA.
```

### 2.4 Description

```text
Ne laissez plus l’essentiel passer inaperçu.

DoraZoom est un outil macOS natif pour les créateurs qui expliquent des idées, présentent leur travail et collaborent visuellement. Zoomez sur n’importe quel écran, dessinez directement par-dessus et capturez le contexte dont les autres ont besoin, sans interrompre votre élan.

OUTILS PRINCIPAUX
• Guidez l’attention avec un zoom statique ou en direct.
• Dessinez avec des crayons, formes, flèches, textes, surligneurs, repères numérotés, flou et masquage.
• Capturez une zone ou une fenêtre dans le presse-papiers ou un fichier, puis extrayez le texte visible avec l’OCR.
• Enregistrez un écran, une zone ou une fenêtre avec, au choix, le micro, le son du système, la caméra en incrustation et la pause/reprise.
• Créez des panoramas défilants pour les pages et conversations trop longues pour un seul écran.
• Utilisez DemoType, les modes tableau blanc et tableau noir et le minuteur de pause pour structurer une explication en direct.

CONÇU POUR
• Les créateurs de tutoriels, enseignants, présentateurs et streamers.
• Les designers, développeurs et équipes produit qui révisent un travail ensemble.
• Les créateurs qui partagent un contexte visuel clair avec des personnes ou les outils d’IA qu’ils utilisent déjà.

DoraZoom n’intègre ni IA ni inférence dans le cloud. Vous gardez le contrôle de ce que vous capturez et partagez.

Politique de confidentialité : TBD
Conditions d’utilisation : TBD
```

### 2.5 Keywords

```text
dessin,capture,vidéo,présentation,tableau,ocr,panorama,tutoriel,créateur,collaboration
```

### 2.6 What's New

```text
Bienvenue dans DoraZoom. Cette première version App Store apporte aux créateurs sur Mac le zoom et le dessin pour guider l’attention, les captures et l’OCR, l’enregistrement d’écran, les panoramas, DemoType ainsi que le flou et le masquage.
```

## 3. Textes des captures d’écran

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Allez droit à l’essentiel** | Zoomez et dessinez sur n’importe quel écran |
| 02 | **Expliquez sans changer d’app** | Crayons, formes, flèches, texte et surlignage |
| 03 | **Du contexte pour vos équipes et outils d’IA** | Capturez une image ou extrayez le texte visible avec l’OCR |
| 04 | **Enregistrez ce qui compte** | Conservez vos repères visuels dans l’enregistrement d’écran |
| 05 | **Partagez clairement, sans risque** | Floutez ou masquez les détails sensibles avant la capture |
| 06 | **Travaillez dans votre langue** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Liste prête à copier :

```text
01 Allez droit à l’essentiel · Zoomez et dessinez sur n’importe quel écran
02 Expliquez sans changer d’app · Crayons, formes, flèches, texte et surlignage
03 Du contexte pour vos équipes et outils d’IA · Capturez une image ou extrayez le texte visible avec l’OCR
04 Enregistrez ce qui compte · Conservez vos repères visuels dans l’enregistrement d’écran
05 Partagez clairement, sans risque · Floutez ou masquez les détails sensibles avant la capture
06 Travaillez dans votre langue · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Résultat de la validation des caractères

Vérifié avec le validateur du projet. Les valeurs mesurées figurent dans le rapport d’implémentation.

## 5. Modifications techniques

| Fichier | Modification |
|---|---|
| `Sources/ZoomItMacCore/Resources/fr.lproj/InfoPlist.strings` | Motifs localisés d’accès au micro et à la caméra |
| `docs/app-store/metadata/fr-FR-app-store-metadata.md` | Métadonnées Store et six textes de captures d’écran |

## 6. Vérifications d’exécution et de publication

- L’app suit la langue de l’app ou du système dans macOS ; elle n’ajoute pas de sélecteur de langue intégré.
- Les demandes d’autorisation suivent la langue de macOS et utilisent le fichier `InfoPlist.strings` localisé.
- Vérifier le nom, le menu d’état, les réglages, la capture/OCR, l’enregistrement, le panorama et DemoType après un démarrage propre en français.
- **Blocage de publication :** remplacer les deux liens juridiques `TBD` par des URL publiques approuvées avant l’envoi sur l’App Store.
