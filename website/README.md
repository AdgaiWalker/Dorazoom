# DoraZoom website

Bilingual product website. Chinese lives at `/`, English at `/en/`; both have privacy, terms, and support pages. No framework or package installation is required.

## Editing and preview

`build-site.mjs` contains the shared homepage template, bilingual product copy, and English legal/support translations. Chinese legal/support text lives in `dist/{privacy,terms,support}/index.html`; generation preserves it and adds language navigation idempotently.

```sh
node build-site.mjs
python3 -m http.server 4277 --bind 127.0.0.1 --directory dist
```

Open `http://127.0.0.1:4277/?lang=zh` or `http://127.0.0.1:4277/en/`. Generated pages are committed for static deployment. Maintain `dist/site.css`, `dist/site.js`, and `dist/language.js` directly.

## Languages

- Default entry selects Chinese for a Chinese browser preference, otherwise English.
- Manual selection takes priority and is stored locally. The `lang` query parameter also works when storage is unavailable.
- Explicit English URLs remain English. Both languages have static content, canonical URLs, and alternate links. Local file previews work too.
- App language selection is separate from website language selection.

## Product and media

- Primary actions are the walkthrough and playground while the Mac App Store version is under review. Purchase copy explains one-time payment without promising an unverified price or an available installer.
- GitHub lives in the footer. At store launch, update both dictionaries with the verified store link and availability.
- Existing video and hero image are promotional illustrations, labeled in both languages. A verified recording of the final app is still needed to replace them.
- Browser canvas is an illustrative presentation, not app UI or pricing. It supports circle, pen, arrow, red/blue, undo, clear, keyboard insertion, and PNG export, all processed locally.

## Hosting

Deploy from this directory with the existing `.vercel/project.json`. Vercel publishes `dist` without installing dependencies.

```sh
node build-site.mjs
vercel deploy --prod --yes
```

Production: https://dorazoom.iwalk.pro/ (also https://dorazoom.vercel.app/).
Operator: 未然界域科技工作室. Support: praxiswalker@Outlook.com.
