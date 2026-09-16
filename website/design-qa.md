# Minimal homepage update — 2026-09-16

Final result: passed for the scoped homepage update.

## Accepted target

Retain the original Chinese page (commit 86df8b3), adding only a quiet Chinese/English switch, simplifying the existing download section, and moving the GitHub source link to the footer. No new sections or artwork.

## Visual review

Original and updated Chinese desktop screenshots were reviewed together at the default browser viewport. Browser screenshot output scales to the panel, so this is a visual fidelity review rather than a pixel-difference assertion.

- Source: `/tmp/dorazoom-minimal-qa-20260916/09-baseline-zh.png`
- Updated: `/tmp/dorazoom-minimal-qa-20260916/08-final-zh.png`
- Download section: `/tmp/dorazoom-minimal-qa-20260916/02-get-app.png`
- English mobile: `/tmp/dorazoom-minimal-qa-20260916/07-mobile-en-visible.png`

Typography retains the original family and hierarchy; English headline sizing is adjusted for fit. Spacing, colors, original assets, and Chinese hero copy are retained. Navigation changes and the shorter download section are intentional. An initial P2 English sentence-spacing issue was corrected with explicit text spaces and headline margin, then rechecked in the browser. Original animated circle artwork is unchanged; captures can show intermediate animation frames.

## Checks

- Chinese/English language links and translated static/dynamic labels.
- English scene switching, annotation insertion, screenshot preview generation, undo and stale-export labels.
- 390px and 320px mobile widths: no horizontal document overflow in either language.
- JavaScript syntax checks and whitespace diff check.
- Browser error log: empty at final local check.

## Boundaries

This is homepage localization, not translation of the legal pages or video. Their Chinese language is disclosed. Browser annotation experience remains illustrative. This update does not verify macOS app behavior or App Store review status. Clipboard, file-save and video playback paths were preserved, not independently revalidated in this pass. Temporary screenshot paths are local evidence, not deployed assets.
