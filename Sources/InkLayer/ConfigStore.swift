import Foundation

/// 自用阶段 JSON 配置（PRD 砍单：设置 UI 发布前补做）
/// 路径：~/Library/Application Support/InkLayer/config.json
/// 示例：{ "recordOutputDir": "~/Movies/板书" }
struct InkConfig: Codable {
    var recordOutputDir: String?
}

enum ConfigStore {
    static var configURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("InkLayer", isDirectory: true)
        return dir.appendingPathComponent("config.json")
    }

    /// 录屏输出目录：配置优先，默认 ~/Movies/InkLayer
    static func recordOutputDir() -> URL {
        if let s = load()?.recordOutputDir, !s.isEmpty {
            return URL(fileURLWithPath: (s as NSString).expandingTildeInPath,
                       isDirectory: true)
        }
        return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InkLayer", isDirectory: true)
    }

    private static func load() -> InkConfig? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? JSONDecoder().decode(InkConfig.self, from: data)
    }
}
