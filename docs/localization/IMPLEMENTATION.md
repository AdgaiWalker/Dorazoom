# DoraZoom localization implementation

## Product decision

- English (`en`) is the development language and final fallback.
- DoraZoom follows the language selected by macOS, including the per-app
  language control in System Settings.
- The first App Store binary contains `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`,
  `de`, `fr`, `es-ES`, `es-419`, and `pt-BR`.
- There is no in-app language selector in the first release. Adding one would
  require a separate persistence, menu-rebuild, window-rebuild, and state
  restoration design; it is not necessary for a native Mac release.

## Single sources of truth

| Concern | Source |
| --- | --- |
| Runtime UI strings | `Sources/ZoomItMacCore/Resources/Localizable.xcstrings` |
| Reviewed English source values | `.l10n/keysets/*.json` |
| Translator handoff files | `.l10n/translations/{locale}.json` |
| Privacy prompt strings | `Sources/ZoomItMacCore/Resources/{locale}.lproj/InfoPlist.strings` |
| Terminology | `.l10n/glossary.yaml` |
| App Store copy | `docs/app-store/metadata/` |
| Market rationale | `docs/localization/MARKET_PRIORITIES.md` |

`CFBundleDisplayName` and `CFBundleName` deliberately remain in the base
Info.plist because the DoraZoom brand is identical in every language. Putting
them in `InfoPlist.strings` would incorrectly override the distinct
`DoraZoom (Dev)` name used by the local development build.

`Scripts/build-localization-catalog.py` deterministically merges the reviewed
keysets and translator files. It rejects conflicting English values, missing or
extra keys, printf-placeholder or paragraph drift, and changes to protected
brand/technical tokens before replacing the catalog.
`Scripts/verify-localization.sh` rebuilds the catalog and runs catalog coverage,
runtime, metadata, property-list, unit-test, and whitespace checks as one gate.

## Binary locale to App Store metadata mapping

App Store Connect does not expose every runtime locale identifier as a metadata
locale. Use this mapping when entering localized product-page copy:

| Runtime locale | App Store metadata locale |
| --- | --- |
| `en` | English (U.S.), with optional English (U.K./Canada/Australia) variants |
| `zh-Hans` | Simplified Chinese |
| `zh-Hant` | Traditional Chinese |
| `ja` | Japanese |
| `ko` | Korean |
| `de` | German (Germany) |
| `fr` | French (France), with optional French (Canada) variant |
| `es-ES` | Spanish (Spain) |
| `es-419` | Spanish (Mexico) |
| `pt-BR` | Portuguese (Brazil) |

## Release gates

The localized binary is not by itself sufficient for App Store submission.
Before upload:

1. Replace the `TBD` privacy-policy and terms URLs in `.l10n/profile.yaml` and
   every metadata handoff document with real public HTTPS pages.
2. Build the App Store Xcode target with App Sandbox, signing, and the required
   usage descriptions. Add every localized `InfoPlist.strings` file to the
   **main App target's** resources; leaving permission strings only inside the
   SwiftPM module bundle does not localize macOS privacy prompts. The current
   `Scripts/build-app.sh` remains the manually assembled development /
   direct-download path.
3. Run all unit tests plus English and Simplified Chinese launch smoke tests.
4. Confirm every `.lproj` and the compiled `Localizable.strings` files are
   present in the archived app.
5. Review screenshots and metadata in App Store Connect; binary localizations
   and product-page localizations are separate submissions.
6. Have a native reviewer in each launch language review the highest-traffic
   flows and store page. Automated placeholder and coverage checks prevent
   structural defects, but they cannot certify tone or regional idiom.
