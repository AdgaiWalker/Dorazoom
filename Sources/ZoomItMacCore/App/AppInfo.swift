import Foundation

/// Product identity used across the UI (settings footer, about text).
public enum AppInfo {
    public static let productName = "DoraZoom"
    public static var version: String {
        resolveVersion(from: Bundle.main.infoDictionary)
    }
    public static let copyright = "Copyright © 2026 哆啦"

    static func resolveVersion(from infoDictionary: [String: Any]?) -> String {
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            if let value = infoDictionary?[key] as? String, !value.isEmpty {
                return value
            }
        }
        return "Development"
    }
}
