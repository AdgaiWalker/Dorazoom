# Español (España) (`es-ES`) · Metadatos de App Store Connect

> Borrador para la primera versión del App Store · 2026-08-20
> Idioma de App Store Connect: **Español (España)**
> Configuración regional de la app: `es-ES`

## 0. Resumen de localización

| Elemento | Valor |
|---|---|
| Configuración regional | `es-ES` |
| String Catalog | Se gestiona en el flujo compartido del catálogo; este documento no afirma que el catálogo esté completo |
| InfoPlist.strings | `Sources/ZoomItMacCore/Resources/es-ES.lproj/InfoPlist.strings` |
| Comportamiento del idioma | `system_only`; sigue el idioma de la app o del sistema en macOS |
| Datos localizados persistentes | Este trabajo de metadatos no añade textos de presentación localizados a los datos persistentes |
| Límite de IA | Comparte contexto visual con herramientas de IA que ya utiliza el usuario; no afirma tener IA integrada |

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
Guía la atención en tu Mac
```

### 2.3 Promotional Text

```text
Amplía, dibuja, anota, extrae texto con OCR y graba sin perder el ritmo. Explica claramente a tus colaboradores, a tu público y a las herramientas de IA que ya usas.
```

### 2.4 Description

```text
Haz que lo importante no pase desapercibido.

DoraZoom es una herramienta nativa para macOS dirigida a creadores que explican ideas, muestran su trabajo y colaboran visualmente. Amplía cualquier pantalla, dibuja directamente sobre ella y captura el contexto que otros necesitan sin interrumpir tu ritmo.

HERRAMIENTAS PRINCIPALES
• Dirige la atención con zoom estático o en directo.
• Dibuja con lápices, formas, flechas, texto, resaltadores, marcadores numerados, desenfoque y ocultación.
• Captura una zona o ventana en el portapapeles o en un archivo y extrae texto visible mediante OCR.
• Graba una pantalla, zona o ventana con micrófono, audio del sistema, cámara en imagen dentro de imagen y pausa/reanudación opcionales.
• Crea panorámicas con desplazamiento para páginas y conversaciones que no caben en una pantalla.
• Utiliza DemoType, lienzos blancos y negros y un temporizador de descanso para estructurar explicaciones en directo.

CREADO PARA
• Creadores de tutoriales, docentes, presentadores y streamers.
• Diseñadores, desarrolladores y equipos de producto que revisan el trabajo juntos.
• Creadores que comparten contexto visual claro con otras personas o con las herramientas de IA que ya utilizan.

DoraZoom no incluye IA integrada ni inferencia en la nube. Tú decides qué capturas y qué compartes.

Política de privacidad: https://dorazoom.iwalk.pro/privacy/
Condiciones de uso: https://dorazoom.iwalk.pro/terms/
```

### 2.5 Keywords

```text
dibujar,captura,grabación,presentación,pizarra,ocr,panorama,tutorial,creador,colaboración
```

### 2.6 What's New

```text
Te damos la bienvenida a DoraZoom. Esta primera versión para el App Store ofrece a los creadores de Mac zoom y dibujo para guiar la atención, capturas y OCR, grabación de pantalla, panorámicas, DemoType y herramientas de desenfoque y ocultación.
```

## 3. Textos para capturas promocionales

| # | Headline | Subheadline |
|---:|---|---|
| 01 | **Ve directo a lo importante** | Amplía y dibuja sobre cualquier pantalla |
| 02 | **Explica sin cambiar de app** | Usa lápices, formas, flechas, texto y resaltadores |
| 03 | **Contexto para personas y herramientas de IA** | Captura imágenes o extrae texto visible mediante OCR |
| 04 | **Graba dónde está la atención** | Mantén el énfasis visual en la grabación de pantalla |
| 05 | **Comparte con claridad y control** | Desenfoca u oculta detalles sensibles antes de capturar |
| 06 | **Trabaja en tu idioma** | English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil) |

Lista para copiar:

```text
01 Ve directo a lo importante · Amplía y dibuja sobre cualquier pantalla
02 Explica sin cambiar de app · Usa lápices, formas, flechas, texto y resaltadores
03 Contexto para personas y herramientas de IA · Captura imágenes o extrae texto visible mediante OCR
04 Graba dónde está la atención · Mantén el énfasis visual en la grabación de pantalla
05 Comparte con claridad y control · Desenfoca u oculta detalles sensibles antes de capturar
06 Trabaja en tu idioma · English · 简体中文 · 繁體中文 · 日本語 · 한국어 · Deutsch · Français · Español (España/Latinoamérica) · Português (Brasil)
```

## 4. Resultado de la validación de caracteres

Comprobado con el validador del proyecto. Los valores medidos figuran en el informe de implementación.

## 5. Cambios técnicos

| Archivo | Cambio |
|---|---|
| `Sources/ZoomItMacCore/Resources/es-ES.lproj/InfoPlist.strings` | Motivos de acceso al micrófono y la cámara localizados |
| `docs/app-store/metadata/es-ES-app-store-metadata.md` | Metadatos de la tienda y seis textos para capturas |

## 6. Comprobaciones de ejecución y publicación

- La app sigue el idioma de la app o del sistema en macOS; no añade un selector de idioma interno.
- Los diálogos de permisos siguen el idioma de macOS y usan el archivo `InfoPlist.strings` localizado.
- Verifica el nombre, el menú de estado, los ajustes, captura/OCR, grabación, panorámicas y DemoType tras un inicio limpio en español de España.
- **Bloqueo de publicación:** sustituye los dos enlaces legales the public legal pages por URL públicas aprobadas antes de enviar la app al App Store.
