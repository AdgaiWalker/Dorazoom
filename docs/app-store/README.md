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
3. Replace every `TBD` privacy-policy and terms URL with an approved public
   HTTPS page.
4. Complete native-speaker review and localized UI clipping tests for all ten
   launch locales.
5. Produce localized screenshots from the final store binary. The metadata
   files contain approved draft captions, not screenshot image assets.
6. Verify storefront and regulatory requirements separately for Mainland
   China before enabling that territory.

The direct-download build and the App Store build must use the same
`Localizable.xcstrings`, glossary, and metadata vocabulary. Their entitlements
and capability sets may differ.
