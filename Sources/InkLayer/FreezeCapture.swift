import AppKit
import ScreenCaptureKit

/// 冻结态快照：有录屏权限时抓全屏静止画面作 overlay 底图；
/// 无权限或失败返回 nil，调用方静默退化为活屏玻璃（首启零弹窗）
enum FreezeCapture {
    /// 全屏抓拍；可排除指定 NSWindow（避免把自家 overlay 打进底图）
    static func grab(excluding windows: [NSWindow] = []) async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        // windowNumber 需在主线程读取
        let excludeIDs: Set<CGWindowID> = await MainActor.run {
            Set(windows.map { CGWindowID($0.windowNumber) })
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }

            let scExclude: [SCWindow] = content.windows.filter {
                excludeIDs.contains($0.windowID)
            }

            let filter = SCContentFilter(display: display, excludingWindows: scExclude)
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: config)
        } catch {
            Telemetry.shared.log("freeze.capture_failed",
                                 ["error": error.localizedDescription])
            return nil
        }
    }
}
