import Foundation
import XCTest
@testable import ZoomItMacCore

final class LocalizationTests: XCTestCase {
    private let expectedLocales = [
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

    func testSupportedLocalesKeepEnglishAsTheDevelopmentLanguage() {
        XCTAssertEqual(AppLocalization.supportedLocaleIdentifiers, expectedLocales)
        XCTAssertEqual(
            AppLocalization.string(
                "settings.window.title",
                defaultValue: "Unexpected fallback",
                localeIdentifier: "en"
            ),
            "DoraZoom Settings"
        )
    }

    func testExplicitChineseLocalizationAndUnsupportedLocaleFallback() {
        XCTAssertEqual(
            AppLocalization.string(
                "settings.window.title",
                defaultValue: "Unexpected fallback",
                localeIdentifier: "zh-Hans"
            ),
            "DoraZoom 设置"
        )
        XCTAssertEqual(
            AppLocalization.string(
                "settings.window.title",
                defaultValue: "Unexpected fallback",
                localeIdentifier: "zh-Hant"
            ),
            "DoraZoom 設定"
        )
        XCTAssertEqual(
            AppLocalization.string(
                "settings.window.title",
                defaultValue: "Unexpected fallback",
                localeIdentifier: "xx-ZZ"
            ),
            "DoraZoom Settings"
        )
    }

    func testSystemLanguageNegotiationMapsScriptsAndRegionsToSupportedLocales() {
        let cases: [([String], String)] = [
            (["zh-CN"], "zh-Hans"),
            (["zh-TW"], "zh-Hant"),
            (["zh-HK"], "zh-Hant"),
            (["es-ES"], "es-ES"),
            (["es-MX"], "es-419"),
            (["es-AR"], "es-419"),
            (["pt-BR"], "pt-BR"),
            (["hi-IN", "en-IN"], "en")
        ]

        for (preferences, expected) in cases {
            XCTAssertEqual(
                AppLocalization.preferredSupportedLocale(for: preferences),
                expected,
                preferences.joined(separator: ", ")
            )
        }
    }

    @MainActor
    func testUnknownShortcutKeyFallbackIsFormattedAndLocalized() {
        XCTAssertEqual(
            SettingsWindowController.describe(keyCode: 999, modifiers: []),
            "Key 999"
        )
        XCTAssertEqual(
            AppLocalization.format(
                "settings.shortcuts.unknown_key",
                defaultValue: "Key %d",
                localeIdentifier: "zh-Hans",
                999
            ),
            "按键 999"
        )
    }

    func testEveryNonEnglishLocaleResolvesThroughTheRuntimeLocalizer() {
        for locale in expectedLocales.dropFirst() {
            let value = AppLocalization.string(
                "settings.window.title",
                defaultValue: "Unexpected fallback",
                localeIdentifier: locale
            )
            XCTAssertNotEqual(value, "Unexpected fallback", locale)
            XCTAssertNotEqual(value, "DoraZoom Settings", locale)
            XCTAssertTrue(value.contains("DoraZoom"), "\(locale): \(value)")
        }
    }

    func testCatalogMatchesReviewedKeysetsAndHasCompleteLocaleCoverage() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let catalogURL = root.appendingPathComponent(
            "Sources/ZoomItMacCore/Resources/Localizable.xcstrings"
        )
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        let keysetsDirectory = root.appendingPathComponent(".l10n/keysets")
        let keysetURLs = try FileManager.default.contentsOfDirectory(
            at: keysetsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        var reviewedEnglish: [String: String] = [:]
        for url in keysetURLs {
            let values = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String]
            )
            for (key, value) in values {
                if let existing = reviewedEnglish[key] {
                    XCTAssertEqual(existing, value, "Conflicting English value for \(key)")
                }
                reviewedEnglish[key] = value
            }
        }

        XCTAssertEqual(Set(strings.keys), Set(reviewedEnglish.keys))
        for key in strings.keys.sorted() {
            let item = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(
                item["localizations"] as? [String: Any],
                key
            )
            XCTAssertEqual(Set(localizations.keys), Set(expectedLocales), key)

            for locale in expectedLocales {
                let localization = try XCTUnwrap(
                    localizations[locale] as? [String: Any],
                    "\(key) / \(locale)"
                )
                let unit = try XCTUnwrap(
                    localization["stringUnit"] as? [String: String],
                    "\(key) / \(locale)"
                )
                XCTAssertEqual(unit["state"], "translated", "\(key) / \(locale)")
                XCTAssertFalse(
                    (unit["value"] ?? "").isEmpty,
                    "Empty localization for \(key) / \(locale)"
                )
            }

            let english = try XCTUnwrap(localizations["en"] as? [String: Any])
            let englishUnit = try XCTUnwrap(english["stringUnit"] as? [String: String])
            XCTAssertEqual(englishUnit["value"], reviewedEnglish[key], key)
        }
    }

    func testEveryLocaleHasValidPrivacyPromptStrings() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resources = root.appendingPathComponent("Sources/ZoomItMacCore/Resources")

        for locale in expectedLocales {
            let url = resources
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("InfoPlist.strings")
            let data = try Data(contentsOf: url)
            let values = try XCTUnwrap(
                try PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: String],
                locale
            )
            XCTAssertNil(values["CFBundleDisplayName"], locale)
            XCTAssertNil(values["CFBundleName"], locale)
            for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription"] {
                let value = try XCTUnwrap(values[key], "\(locale) / \(key)")
                XCTAssertTrue(value.contains("DoraZoom"), "\(locale) / \(key)")
                XCTAssertGreaterThan(value.count, "DoraZoom".count, "\(locale) / \(key)")
            }
        }
    }

    func testRootInfoPlistDeclaresEnglishDevelopmentRegion() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let data = try Data(contentsOf: root.appendingPathComponent("ZoomItInfo.plist"))
        let values = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )
        XCTAssertEqual(values["CFBundleDevelopmentRegion"] as? String, "en")
        XCTAssertEqual(values["CFBundleLocalizations"] as? [String], expectedLocales)

        let englishPromptData = try Data(
            contentsOf: root.appendingPathComponent(
                "Sources/ZoomItMacCore/Resources/en.lproj/InfoPlist.strings"
            )
        )
        let englishPrompts = try XCTUnwrap(
            try PropertyListSerialization.propertyList(
                from: englishPromptData,
                format: nil
            ) as? [String: String]
        )
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription"] {
            XCTAssertEqual(values[key] as? String, englishPrompts[key], key)
        }
    }
}
