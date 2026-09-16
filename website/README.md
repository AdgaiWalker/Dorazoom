# DoraZoom website

A responsive Chinese/English product homepage for the DoraZoom macOS screen annotation app, preserving the original concise design.

Language selection: `?lang=zh` or `?lang=en`, then the saved selection, then the browser's preferred language (Chinese for `zh`, English otherwise). The navigation switch remembers the choice. Legal/support pages and the existing video remain Chinese; English labels disclose this.

## Local preview

Run `python3 -m http.server 4277 --bind 127.0.0.1 --directory dist` from this directory and open `http://127.0.0.1:4277/`. The site is plain HTML, CSS, and JavaScript and needs no installation or build step.

## Interactions

- The canvas supports ellipse, freehand, and arrow tools, three colors, undo, clear, mouse, pen, and touch input. Narrow drawing panes show a close-up of the center card; annotations keep full-scene coordinates and PNG exports always contain the full 1440×900 scene.
- Narrow toolbars use two rows with 44×44px targets. The explicit example notice sits outside the canvas.
- The release section says “Coming soon to the Mac App Store”, with a one-time-purchase note and one drawing-demo button. GitHub source is linked in the footer. No download availability is promised before release.
- Focus the canvas and use 1/2/3 to select tools, Enter to mark the example button, and Command/Control + Z to undo.
- Generate a PNG, copy the image or accompanying text, or save the image. Exports always include current committed annotations; when image clipboard access is unavailable, saving remains available.
- Scene tabs support mouse, touch, and arrow-key navigation. Video dialogs start at the corresponding scene and support Escape to close.
- FAQ answers use native disclosure elements. Motion respects reduced-motion preferences.
- Supported browsers can access two optional WebMCP tools: `get_annotation_state` and `select_product_scene`.

## Assets and product boundaries

Product images and the 33-second video were copied from the existing local DoraZoom promo project. The interactive pricing page is an illustrative drawing surface, not DoraZoom pricing. All annotations and text stay in the browser. The page does not call an AI service or automatically change code.

The page links to the public GitHub `v1.0.0` release and states that the Mac App Store build is under review. Replace the review-state copy and add the approved Mac App Store link after Apple approves and the account holder manually publishes the version. No development app bundles are distributed here.

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
