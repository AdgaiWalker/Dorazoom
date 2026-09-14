# DoraZoom website

A responsive, Chinese-language product website for the DoraZoom macOS screen annotation app.

## Local preview

Run `python3 -m http.server 4277 --bind 127.0.0.1 --directory dist` from this directory and open `http://127.0.0.1:4277/`. The site is plain HTML, CSS, and JavaScript and needs no installation or build step.

## Interactions

- The canvas supports ellipse, freehand, and arrow tools, three colors, undo, clear, mouse, pen, and touch input. Narrow drawing panes show a close-up of the center card; annotations keep full-scene coordinates and PNG exports always contain the full 1440×900 scene.
- Narrow toolbars use two rows with 44×44px targets. The explicit example notice sits outside the canvas.
- The release section clearly states that the Mac download is not open yet. “保存官网地址” downloads an Internet Shortcut pointing to the verified production domain.
- Focus the canvas and use 1/2/3 to select tools, Enter to mark the example button, and Command/Control + Z to undo.
- Generate a PNG, copy the image or accompanying text, or save the image. Exports always include current committed annotations; when image clipboard access is unavailable, saving remains available.
- Scene tabs support mouse, touch, and arrow-key navigation. Video dialogs start at the corresponding scene and support Escape to close.
- FAQ answers use native disclosure elements. Motion respects reduced-motion preferences.
- Supported browsers can access two optional WebMCP tools: `get_annotation_state` and `select_product_scene`.

## Assets and product boundaries

Product images and the 33-second video were copied from the existing local DoraZoom promo project. The interactive pricing page is an illustrative drawing surface, not DoraZoom pricing. All annotations and text stay in the browser. The page does not call an AI service or automatically change code.

The repository does not establish a public, signed release URL, so the page explicitly states that the official download is forthcoming. Replace that message and its corresponding FAQ when an approved distribution link becomes available. No development app bundles are distributed here.

## Hosting

`dist` is the complete static deployment. `vercel.json` configures the local CLI to deploy that directory without an install or build step. The Vercel project is `dorazoom` in team `praxiswalker-6245s-projects`. After authenticating the local CLI, link and deploy from this directory:

```sh
vercel link --yes --team team_4TWl9oeULP0tbi7F7rtjk20t --project prj_DvSyETTsU2FaA7l4Hmhe1qrObEB4
vercel deploy --prod --yes
```

The production website is https://dorazoom.iwalk.pro/ (also available at https://dorazoom.vercel.app/). The custom domain is assigned to the Vercel project and verified through Spaceship DNS.

Public legal and support pages are available at `/privacy/`, `/terms/`, and `/support/`. They identify 未然界域科技工作室 as the DoraZoom operator and use `praxiswalker@Outlook.com` for support requests.

The web video is optimized to 1280×720 H.264/AAC with fast-start metadata. The original 1920×1080 video remains in the parent project's `promo/out/promo.mp4`.

`.openai/hosting.json` preserves the identity of the earlier Sites preview. Vercel is the requested deployment destination going forward. Keep this project's source repository separate from the parent macOS app.

## Verification performed

- Browser checks at desktop width and at 390px and 320px; no horizontal overflow.
- Mouse arrow drawing, touch ellipse drawing, tool and color selection, undo, clear, example insertion, PNG generation, and actual PNG download.
- Product scene switching and native video playback; recording scene opens at 22.5 seconds.
- WebMCP registration, valid tool execution, invalid scene rejection, and state preservation.
- JavaScript syntax, unique HTML IDs, all local media references, and all fragment links.
