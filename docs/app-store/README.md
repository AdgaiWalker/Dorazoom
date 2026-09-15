# DoraZoom Mac App Store handoff

The files in `metadata/` are localized drafts for App Store Connect. They are
not an assertion that the current SwiftPM app is ready to upload.

## Blocking gates before submission

1. Create and archive a real Xcode macOS App target with App Sandbox, signing,
   and an App Store provisioning profile.
2. Freeze the store-edition capability matrix after sandbox and App Review
   testing. Remove any metadata claim for a feature that is not shipped in the
   store binary; this is especially important for synthetic input, DemoType,
   global shortcuts, ScreenCaptureKit, OCR, and recording combinations.
   DemoType has already been resolved for the first release: the `DORAZOOM_APP_STORE`
   target compiles it out, and all ten locale drafts had their DemoType claims
   removed. The remaining items on this list still need the same treatment or a
   decision to ship them.
3. Replace every `TBD` privacy-policy and terms URL with an approved public
   HTTPS page.
4. Complete native-speaker review and localized UI clipping tests for all ten
   launch locales.
5. Produce localized screenshots from the final store binary. The metadata
   files contain approved draft captions, not screenshot image assets.
   Two of the six `zh-Hans/` captures are already stale because of the DemoType
   removal and **must be re-shot**: `02-shortcuts.png` still shows the
   `DemoType:` shortcut row, and `06-advanced.png` still shows the whole
   DemoType block (help text, shortcut, input file, typing speed, drive-input
   checkbox). Re-capture from the signed Archive/TestFlight build, then mirror
   them across the other nine locales.

The `## 4. Character-limit results` tables were written against an earlier
revision of the descriptions and are stale by roughly 62 characters in the
CJK and English drafts; the counts should be recalculated with a single stated
convention before the metadata is pasted into App Store Connect. Every field is
comfortably inside its limit, so this does not block submission.
6. Verify storefront and regulatory requirements separately for Mainland
   China before enabling that territory.

The direct-download build and the App Store build must use the same
`Localizable.xcstrings`, glossary, and metadata vocabulary. Their entitlements
and capability sets may differ.
