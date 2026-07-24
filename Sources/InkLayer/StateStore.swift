import Foundation

/// 轻量本地状态（与遥测同目录的 state.json）：用于"提示条用熟后自动消失"等计数
enum StateStore {
    private static var fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InkLayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }()

    private static func read() -> [String: Int] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }

    private static func write(_ dict: [String: Int]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 自增并返回最新计数
    @discardableResult
    static func bump(_ key: String) -> Int {
        var dict = read()
        let next = (dict[key] ?? 0) + 1
        dict[key] = next
        write(dict)
        return next
    }
}
