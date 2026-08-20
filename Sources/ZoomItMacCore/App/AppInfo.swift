import Foundation

/// Product identity used across the UI (settings footer, about text).
public enum AppInfo {
    public static let productName = AppLocalization.string(
        "app.product_name",
        defaultValue: "DoraZoom"
    )
    public static var version: String {
        resolveVersion(from: Bundle.main.infoDictionary)
    }
    public static let copyright = AppLocalization.string(
        "app_info.copyright",
        defaultValue: "Copyright © 2026 Dora"
    )

    static func resolveVersion(from infoDictionary: [String: Any]?) -> String {
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            if let value = infoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
        }
        return AppLocalization.string(
            "app_info.version.development",
            defaultValue: "Development"
        )
    }
}
