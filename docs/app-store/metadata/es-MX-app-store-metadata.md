# Español (México) (`es-MX`) · Metadatos de App Store Connect

> Borrador para la primera versión de App Store · 2026-08-20
> Idioma de App Store Connect: **Español (México)**
> Configuración regional binaria: `es-419`

## 0. Resumen de localización

| Elemento | Valor |
|---|---|
| Configuración regional binaria | `es-419` |
| Configuración regional de la tienda | `es-MX` |
| String Catalog | Se administra en el flujo compartido del catálogo; este documento no afirma que el catálogo esté completo |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/es-419.lproj/InfoPlist.strings` |
| Comportamiento del idioma | `system_only`; sigue el idioma de la app o del sistema en macOS |
| Datos localizados persistentes | Este trabajo de metadatos no agrega textos localizados a los datos persistentes |
| Límite de IA | Comparte contexto visual con herramientas de IA que el usuario ya usa; no afirma tener IA integrada |

## 1. Límites de App Store Connect

| Campo | Límite |
|---|---:|
| Nombre de la app | 30 caracteres |
| Subtítulo | 30 caracteres |
| Texto promocional | 170 caracteres |
| Descripción | 4000 caracteres |
| Palabras clave | 100 caracteres |
| Novedades | 4000 caracteres |

## 2. Metadatos

### 2.1 App Name

```text
DoraZoom: anota tu pantalla
```

### 2.2 Subtitle

```text
Dirige la atención en tu Mac
```

### 2.3 Promotional Text

```text
Haz zoom, dibuja, anota, extrae texto con OCR y graba sin perder el ritmo. Explica con claridad a tu equipo, audiencia y las herramientas de IA que ya usas.
```

### 2.4 Description

```text
Haz que lo importante sea imposible de ignorar.

DoraZoom es una herramienta nativa de macOS para creadores que explican ideas, muestran su trabajo y colaboran de forma visual. Haz zoom en cualquier pantalla, dibuja directamente sobre ella y captura el contexto que otros necesitan sin perder el ritmo.

HERRAMIENTAS PRINCIPALES
• Dirige la atención con zoom estático o en vivo.
• Dibuja con plumas, formas, flechas, texto, resaltadores, marcadores numerados, desenfoque y ocultamiento.
• Captura una región o ventana al portapapeles o a un archivo y extrae texto visible con OCR.
• Graba una pantalla, región o ventana con micrófono, audio del sistema, cámara superpuesta y pausa/reanudación opcionales.
• Crea panorámicas con desplazamiento para páginas y conversaciones que no caben en una sola pantalla.
• Usa DemoType, pizarrones blancos y negros y un temporizador de descanso para dar estructura a una explicación en vivo.

HECHO PARA
• Creadores de tutoriales, docentes, presentadores y streamers.
• Diseñadores, desarrolladores y equipos de producto que revisan trabajos en conjunto.
• Creadores que comparten contexto visual claro con personas o con las herramientas de IA que ya usan.

DoraZoom no incluye IA integrada ni inferencia en la nube. Tú controlas qué capturas y qué compartes.

Política de privacidad: TBD
Términos de uso: TBD
```

### 2.5 Keywords

```text
dibujar,captura,grabación,presentación,pizarrón,ocr,panorama,tutorial,creador,colaboración
```

### 2.6 What's New

```text
Te damos la bienvenida a DoraZoom. Esta primera versión para App Store ofrece a creadores de Mac zoom y dibujo para dirigir la atención, capturas y OCR, grabación de pantalla, panorámicas, DemoType y herramientas de desenfoque y ocultamiento.
```

## 3. Textos para capturas promocionales

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Ve directo a lo importante** | Amplía y dibuja sobre cualquier pantalla |
| 02 | **Explica sin cambiar de app** | Usa plumas, formas, flechas, texto y resaltadores |
| 03 | **Contexto para personas y herramientas de IA** | Captura imágenes o extrae texto visible con OCR |
| 04 | **Graba dónde va la atención** | Conserva el énfasis visual en tu grabación de pantalla |
| 05 | **Comparte con claridad y control** | Desenfoca u oculta datos sensibles antes de capturar |
| 06 | **Trabaja en tu idioma** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Lista para copiar:

```text
01 Ve directo a lo importante · Amplía y dibuja sobre cualquier pantalla
02 Explica sin cambiar de app · Usa plumas, formas, flechas, texto y resaltadores
03 Contexto para personas y herramientas de IA · Captura imágenes o extrae texto visible con OCR
04 Graba dónde va la atención · Conserva el énfasis visual en tu grabación de pantalla
05 Comparte con claridad y control · Desenfoca u oculta datos sensibles antes de capturar
06 Trabaja en tu idioma · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Resultado de la validación de caracteres

Comprobado con el validador del proyecto. Los valores medidos figuran en el informe de implementación.

## 5. Cambios técnicos

| Archivo | Cambio |
|---|---|
| `Sources/ZoomItMacCore/Resources/es-419.lproj/InfoPlist.strings` | Motivos de acceso al micrófono y la cámara localizados |
| `docs/app-store/metadata/es-MX-app-store-metadata.md` | Metadatos de la tienda y seis textos para capturas |

## 6. Comprobaciones de ejecución y publicación

- La app sigue el idioma de la app o del sistema en macOS; no incluye un selector de idioma interno.
- Los diálogos de permisos siguen el idioma de macOS y usan el archivo `InfoPlist.strings` localizado.
- Verifica el nombre, menú de estado, ajustes, captura/OCR, grabación, panorámicas y DemoType tras un inicio limpio en español latinoamericano.
- **Bloqueo de publicación:** reemplaza los dos enlaces legales `TBD` por URL públicas aprobadas antes de enviar la app a App Store.
