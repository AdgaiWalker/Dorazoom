import Foundation

/// A folder the user explicitly granted DoraZoom access to.
struct SaveFolderAuthorization: Equatable {
    var url: URL
    var bookmark: Data
    /// macOS reports the bookmark as stale; it still resolved, but the stored
    /// copy has been refreshed.
    var isStale: Bool

    /// Only used as a hint in Settings. The bookmark, not this path, is what
    /// carries the grant.
    var displayPath: String { url.path }
}

/// Why saving into the authorized folder did not happen. Every case has to end
/// in a user-visible exit; none of them may drop the captured image.
enum FileAccessError: Error, Equatable {
    /// No bookmark was ever stored, or the stored one can no longer be
    /// restored. The user has to pick the folder again.
    case authorizationMissing
    /// The bookmark resolved but the folder is gone or not writable.
    case folderUnavailable(String)
    /// The write itself failed.
    case writeFailed(String)
    /// The image could not be encoded, so there is nothing to write.
    case encodingFailed(String)

    var userFacingReason: String {
        switch self {
        case .authorizationMissing:
            return AppLocalization.string(
                "save_failure.authorization_missing",
                defaultValue: "DoraZoom no longer has permission to write to your chosen folder."
            )
        case .folderUnavailable(let path):
            return AppLocalization.string(
                "save_failure.folder_unavailable",
                defaultValue: "The folder is missing or not writable:"
            ) + " " + path
        case .writeFailed(let reason):
            return AppLocalization.string(
                "save_failure.write_failed",
                defaultValue: "The image could not be written:"
            ) + " " + reason
        case .encodingFailed(let reason):
            return AppLocalization.string(
                "save_failure.encoding_failed",
                defaultValue: "The image could not be encoded:"
            ) + " " + reason
        }
    }
}

/// Where the bookmark lives between launches. Kept separate from
/// `AppSettings` because it is an authorization artifact, not a user-editable
/// setting: the display path stays in Settings, the grant lives here.
@MainActor
protocol SaveFolderBookmarkStoring: AnyObject {
    var storedBookmark: Data? { get set }
}

@MainActor
final class UserDefaultsSaveFolderBookmarkStore: SaveFolderBookmarkStoring {
    static let defaultsKey = "snipSaveDirectoryBookmark"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var storedBookmark: Data? {
        get { defaults.data(forKey: Self.defaultsKey) }
        set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }
}

/// Owns the security-scoped bookmark for the user's chosen save folder.
///
/// The sandbox does not remember a folder across launches from its path alone,
/// which is why storing `snipSaveDirectory` as a string was not enough. The
/// bookmark is what survives a relaunch, and it is resolved (not trusted) on
/// every export.
@MainActor
final class FileAccessService {
    private let store: SaveFolderBookmarkStoring
    private let makeBookmark: @MainActor @Sendable (URL) throws -> Data
    private let resolveBookmark: @MainActor @Sendable (Data) throws -> (url: URL, isStale: Bool)
    private let acquireAccess: @MainActor @Sendable (URL) -> Bool
    private let releaseAccess: @MainActor @Sendable (URL) -> Void

    init(
        store: SaveFolderBookmarkStoring = UserDefaultsSaveFolderBookmarkStore(),
        makeBookmark: @escaping @MainActor @Sendable (URL) throws -> Data = FileAccessService.securityScopedBookmark,
        resolveBookmark: @escaping @MainActor @Sendable (Data) throws -> (url: URL, isStale: Bool) = FileAccessService.resolveSecurityScopedBookmark,
        acquireAccess: @escaping @MainActor @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        releaseAccess: @escaping @MainActor @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.store = store
        self.makeBookmark = makeBookmark
        self.resolveBookmark = resolveBookmark
        self.acquireAccess = acquireAccess
        self.releaseAccess = releaseAccess
    }

    static func securityScopedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolveSecurityScopedBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    /// Whether a grant has been recorded. An old `snipSaveDirectory` string does
    /// not count: a path on its own is not an authorization.
    var hasStoredAuthorization: Bool {
        store.storedBookmark != nil
    }

    /// Records the folder the user just picked in the open panel.
    func grantAccess(to url: URL) throws -> SaveFolderAuthorization {
        do {
            let bookmark = try makeBookmark(url)
            store.storedBookmark = bookmark
            return SaveFolderAuthorization(url: url, bookmark: bookmark, isStale: false)
        } catch {
            throw FileAccessError.authorizationMissing
        }
    }

    /// Resolves the stored grant. Throws `.authorizationMissing` when there is
    /// none, or when the bookmark can no longer be restored — in that case the
    /// stored data is discarded so the caller is forced to ask the user again
    /// instead of retrying a dead bookmark forever.
    func resolveAuthorization() throws -> SaveFolderAuthorization {
        guard let data = store.storedBookmark else {
            throw FileAccessError.authorizationMissing
        }

        let resolved: (url: URL, isStale: Bool)
        do {
            resolved = try resolveBookmark(data)
        } catch {
            store.storedBookmark = nil
            throw FileAccessError.authorizationMissing
        }

        // A stale bookmark still resolves; refresh it so the next launch does
        // not have to fall back to the same repair.
        if resolved.isStale {
            let refreshed = try? makeBookmark(resolved.url)
            if let refreshed {
                store.storedBookmark = refreshed
            }
        }

        return SaveFolderAuthorization(
            url: resolved.url,
            bookmark: store.storedBookmark ?? data,
            isStale: resolved.isStale
        )
    }

    func clearAuthorization() {
        store.storedBookmark = nil
    }

    /// Brackets `body` with scoped access to the authorized folder and always
    /// releases it, including when `body` throws.
    func withAuthorizedFolder<T>(_ body: (URL) throws -> T) throws -> T {
        let authorization = try resolveAuthorization()
        let url = authorization.url

        // `startAccessingSecurityScopedResource` returns false when access was
        // already available (for example a non-sandboxed build); access must
        // only be released when it was actually acquired.
        let acquired = acquireAccess(url)
        defer {
            if acquired {
                releaseAccess(url)
            }
        }

        return try body(url)
    }
}
