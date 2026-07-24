import Foundation

/// 事件流遥测：本地 JSONL 追加日志，零网络请求（数据资产地基）
final class Telemetry {
    static let shared = Telemetry()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "inklayer.telemetry")
    private let iso = ISO8601DateFormatter()

    private init() {
        if let override = ProcessInfo.processInfo.environment["INKLAYER_TELEMETRY_PATH"] {
            fileURL = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("InkLayer", isDirectory: true)
            fileURL = dir.appendingPathComponent("telemetry.jsonl")
        }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
    }

    func log(_ event: String, _ props: [String: String] = [:]) {
        var dict: [String: Any] = [
            "ts": iso.string(from: Date()),
            "event": event
        ]
        if !props.isEmpty { dict["props"] = props }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              var line = String(data: data, encoding: .utf8) else { return }
        line.append("\n")

        queue.sync {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
            } else {
                try? line.write(to: fileURL, atomically: false, encoding: .utf8)
            }
        }
    }
}
