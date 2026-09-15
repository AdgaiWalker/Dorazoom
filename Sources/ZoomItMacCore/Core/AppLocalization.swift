import Foundation

/// Project-wide localization access for the AppKit app and its SwiftPM tests.
///
/// DoraZoom's development language is English. The packaged app flattens the
/// SwiftPM resource bundle into `Bundle.main`, while `swift test` keeps the
/// generated resource bundle intact. Look in the main app first, and only
/// evaluate `Bundle.module` outside a packaged `.app` to avoid a fatal missing
/// bundle lookup in manually assembled releases.
enum AppLocalization {
    static let supportedLocaleIdentifiers = [
        "en",
        "zh-Hans",
        "zh-Hant",
        "ja",
        "ko",
        "de",
        "fr",
        "es-ES",
        "es-419",
        "pt-BR"
    ]

    static func string(
        _ key: String,
        defaultValue: String,
        localeIdentifier: String? = nil
    ) -> String {
        // Negotiate once for the app, then explicitly look up that language in
        // every resource bundle. A nested SwiftPM bundle otherwise falls back
        // to English before the app's preferred language is considered.
        let localeIdentifier = localeIdentifier ?? resolvedLocaleIdentifier
        for bundle in resourceBundles {
            if let localized = localizedString(
                key,
                defaultValue: defaultValue,
                localeIdentifier: localeIdentifier,
                in: bundle
            ) {
                return localized
            }
        }

        if let catalogValue = rawCatalogString(
            key,
            localeIdentifier: localeIdentifier
        ) {
            return catalogValue
        }

        if localeIdentifier != "en" {
            for bundle in resourceBundles {
                if let english = localizedString(
                    key,
                    defaultValue: defaultValue,
                    localeIdentifier: "en",
                    in: bundle
                ) {
                    return english
                }
            }
            if let english = rawCatalogString(key, localeIdentifier: "en") {
                return english
            }
        }
        return defaultValue
    }

    static func format(
        _ key: String,
        defaultValue: String,
        localeIdentifier: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let template = string(
            key,
            defaultValue: defaultValue,
            localeIdentifier: localeIdentifier
        )
        let locale = localeIdentifier.map(Locale.init(identifier:)) ?? resolvedLocale
        return String(format: template, locale: locale, arguments: arguments)
    }

    private static let missingValue = "\u{F8FF}DoraZoom.Missing.Localization\u{F8FF}"

    private static var resolvedLocale: Locale {
        Locale(identifier: resolvedLocaleIdentifier)
    }

    private static var resolvedLocaleIdentifier: String {
        // Existing unit tests assert the English development-language UI
        // contract. SwiftPM's xctest runner does not honor an AppleLanguages
        // environment override, so keep implicit lookups deterministic there;
        // explicit locale and language-negotiation tests still exercise every
        // supported localization.
        if NSClassFromString("XCTestCase") != nil {
            return "en"
        }
        return preferredSupportedLocale(for: Locale.preferredLanguages)
    }

    /// Uses Foundation's language negotiation so script and regional variants
    /// resolve the same way as a localized macOS app bundle. Keeping this
    /// internal makes the system-only policy testable without adding an
    /// application-specific language preference.
    static func preferredSupportedLocale(for preferences: [String]) -> String {
        if let preferred = Bundle.preferredLocalizations(
            from: supportedLocaleIdentifiers,
            forPreferences: preferences
        ).first {
            return preferred
        }
        for bundle in resourceBundles {
            if let identifier = bundle.preferredLocalizations.first,
               bestSupportedLocale(for: identifier) != nil {
                return identifier
            }
        }
        for identifier in preferences {
            if let supported = bestSupportedLocale(for: identifier) {
                return supported
            }
        }
        return "en"
    }

    private static var resourceBundles: [Bundle] {
        var bundles = [Bundle.main]
#if SWIFT_PACKAGE
        // Packaged DoraZoom apps flatten resources into Bundle.main. SwiftPM
        // tests and bare executables retain Bundle.module.
        if Bundle.main.bundleURL.pathExtension != "app" {
            bundles.append(Bundle.module)
        } else if let resourceURL = Bundle.main.resourceURL,
                  let resourceURLs = try? FileManager.default.contentsOfDirectory(
                      at: resourceURL,
                      includingPropertiesForKeys: nil,
                      options: [.skipsHiddenFiles]
                  ) {
            // A future Xcode App target may embed SwiftPM resources as a
            // nested bundle instead of flattening them like build-app.sh.
            // Discover it without touching Bundle.module, whose generated
            // accessor fatal-errors when the expected bundle is absent.
            bundles.append(contentsOf: resourceURLs.compactMap { url in
                guard url.pathExtension == "bundle" else { return nil }
                return Bundle(url: url)
            })
        }
#endif
        return bundles
    }

    private static func localizedString(
        _ key: String,
        defaultValue: String,
        localeIdentifier: String,
        in bundle: Bundle
    ) -> String? {
        for candidate in localeCandidates(for: localeIdentifier) {
            guard let path = bundle.path(forResource: candidate, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                continue
            }
            let value = localizedBundle.localizedString(
                forKey: key,
                value: missingValue,
                table: nil
            )
            if value != missingValue {
                return value
            }
        }
        return nil
    }

    private static func localeCandidates(for identifier: String) -> [String] {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        var candidates = [normalized]
        let language = Locale(identifier: normalized).language.languageCode?.identifier
        if let language, !candidates.contains(language) {
            candidates.append(language)
        }
        return candidates
    }

    /// `swift build` currently copies String Catalogs as resources instead of
    /// compiling them, while an Xcode Archive emits localized `.strings` files.
    /// The normal bundle lookup above remains authoritative. This read-only
    /// catalog fallback keeps SwiftPM tests and the manually assembled direct
    /// build localized without creating a second translation source.
    private static func rawCatalogString(
        _ key: String,
        localeIdentifier: String
    ) -> String? {
        guard let values = rawCatalog[key] else { return nil }
        for candidate in localeCandidates(for: localeIdentifier) {
            if let value = values[candidate] {
                return value
            }
        }
        return nil
    }

    private static let rawCatalog: [String: [String: String]] = {
        var merged: [String: [String: String]] = [:]
        for bundle in resourceBundles {
            guard let url = bundle.url(
                forResource: "Localizable",
                withExtension: "xcstrings"
            ),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let strings = root["strings"] as? [String: Any] else {
                continue
            }

            for (key, rawItem) in strings {
                guard let item = rawItem as? [String: Any],
                      let localizations = item["localizations"] as? [String: Any] else {
                    continue
                }
                for (locale, rawLocalization) in localizations {
                    guard let localization = rawLocalization as? [String: Any],
                          let unit = localization["stringUnit"] as? [String: Any],
                          let value = unit["value"] as? String else {
                        continue
                    }
                    merged[key, default: [:]][locale] = value
                }
            }
        }
        return merged
    }()

    private static func bestSupportedLocale(for identifier: String) -> String? {
        for candidate in localeCandidates(for: identifier) {
            if supportedLocaleIdentifiers.contains(candidate) {
                return candidate
            }
        }
        return nil
    }
}
