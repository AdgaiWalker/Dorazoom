import XCTest
@testable import ZoomItMacCore

@MainActor
private final class BookmarkStoreFake: SaveFolderBookmarkStoring {
    var storedBookmark: Data?
}

@MainActor
private final class CallCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private struct BookmarkError: Error {}

final class AppleFileAccessTests: XCTestCase {
    @MainActor
    private func makeService(
        store: BookmarkStoreFake,
        resolve: (@MainActor @Sendable (Data) throws -> (url: URL, isStale: Bool))? = nil,
        acquire: (@MainActor @Sendable (URL) -> Bool)? = nil,
        release: (@MainActor @Sendable (URL) -> Void)? = nil,
        refreshCount: CallCounter? = nil
    ) -> FileAccessService {
        FileAccessService(
            store: store,
            makeBookmark: { url in
                refreshCount?.increment()
                return Data("bookmark:\(url.path)".utf8)
            },
            resolveBookmark: { data in
                if let resolve { return try resolve(data) }
                let path = String(decoding: data, as: UTF8.self)
                    .replacingOccurrences(of: "bookmark:", with: "")
                return (URL(fileURLWithPath: path, isDirectory: true), false)
            },
            acquireAccess: acquire ?? { _ in true },
            releaseAccess: release ?? { _ in }
        )
    }

    // MARK: - Grant

    @MainActor
    func testGrantingAFolderStoresASecurityScopedBookmark() throws {
        let store = BookmarkStoreFake()
        let service = makeService(store: store)
        let folder = URL(fileURLWithPath: "/Users/example/Pictures", isDirectory: true)

        XCTAssertFalse(service.hasStoredAuthorization)

        let authorization = try service.grantAccess(to: folder)

        XCTAssertTrue(service.hasStoredAuthorization)
        XCTAssertEqual(authorization.url, folder)
        XCTAssertFalse(authorization.isStale)
        XCTAssertNotNil(store.storedBookmark)
    }

    /// The migration rule: an old `snipSaveDirectory` string is a display hint,
    /// not an authorization. Without a bookmark there is no access to resolve.
    @MainActor
    func testAPathWithoutABookmarkIsNotAnAuthorization() {
        let store = BookmarkStoreFake()
        store.storedBookmark = nil
        let service = makeService(store: store)

        XCTAssertFalse(service.hasStoredAuthorization)
        XCTAssertThrowsError(try service.resolveAuthorization()) { error in
            XCTAssertEqual(error as? FileAccessError, .authorizationMissing)
        }
    }

    // MARK: - Resolve

    @MainActor
    func testResolvingReturnsTheRecordedFolder() throws {
        let store = BookmarkStoreFake()
        let service = makeService(store: store)
        let folder = URL(fileURLWithPath: "/Users/example/Screenshots", isDirectory: true)
        _ = try service.grantAccess(to: folder)

        let authorization = try service.resolveAuthorization()

        XCTAssertEqual(authorization.url, folder)
        XCTAssertEqual(authorization.displayPath, folder.path)
    }

    /// A stale bookmark still resolves. It has to be refreshed in place so the
    /// next launch does not repeat the same repair, and the caller has to know.
    @MainActor
    func testStaleBookmarkIsReportedAndRefreshed() throws {
        let store = BookmarkStoreFake()
        let folder = URL(fileURLWithPath: "/Users/example/Moved", isDirectory: true)
        let refreshes = CallCounter()
        let service = FileAccessService(
            store: store,
            makeBookmark: { url in
                refreshes.increment()
                return Data("refreshed:\(url.path)".utf8)
            },
            resolveBookmark: { _ in (folder, true) },
            acquireAccess: { _ in true },
            releaseAccess: { _ in }
        )
        store.storedBookmark = Data("stale".utf8)

        let authorization = try service.resolveAuthorization()

        XCTAssertTrue(authorization.isStale)
        XCTAssertEqual(authorization.url, folder)
        XCTAssertEqual(refreshes.value, 1, "A stale bookmark must be refreshed")
        XCTAssertEqual(store.storedBookmark, Data("refreshed:/Users/example/Moved".utf8))
    }

    /// When the bookmark cannot be restored the stored copy is discarded, so
    /// the app asks the user again instead of retrying a dead bookmark.
    @MainActor
    func testUnrestorableBookmarkIsDiscarded() {
        let store = BookmarkStoreFake()
        let service = makeService(store: store, resolve: { _ in throw BookmarkError() })
        store.storedBookmark = Data("broken".utf8)

        XCTAssertThrowsError(try service.resolveAuthorization()) { error in
            XCTAssertEqual(error as? FileAccessError, .authorizationMissing)
        }
        XCTAssertNil(store.storedBookmark)
        XCTAssertFalse(service.hasStoredAuthorization)
    }

    // MARK: - Scoped access

    @MainActor
    func testScopedAccessIsReleasedAfterASuccessfulWrite() throws {
        let store = BookmarkStoreFake()
        let acquired = CallCounter()
        let released = CallCounter()
        let service = makeService(
            store: store,
            acquire: { _ in acquired.increment(); return true },
            release: { _ in released.increment() }
        )
        _ = try service.grantAccess(to: URL(fileURLWithPath: "/Users/example/Snips", isDirectory: true))

        let result = try service.withAuthorizedFolder { folder in folder.lastPathComponent }

        XCTAssertEqual(result, "Snips")
        XCTAssertEqual(acquired.value, 1)
        XCTAssertEqual(released.value, 1, "Access must be released after the write")
    }

    /// A throw inside the write must not leak the scoped access.
    @MainActor
    func testScopedAccessIsReleasedWhenTheWriteThrows() throws {
        let store = BookmarkStoreFake()
        let released = CallCounter()
        let service = makeService(
            store: store,
            acquire: { _ in true },
            release: { _ in released.increment() }
        )
        _ = try service.grantAccess(to: URL(fileURLWithPath: "/Users/example/Snips", isDirectory: true))

        XCTAssertThrowsError(try service.withAuthorizedFolder { _ -> Void in throw BookmarkError() })

        XCTAssertEqual(released.value, 1, "A failed write must still release access")
    }

    /// A non-sandboxed build already has access, so nothing is acquired and
    /// nothing may be released.
    @MainActor
    func testAccessIsNotReleasedWhenItWasNeverAcquired() throws {
        let store = BookmarkStoreFake()
        let released = CallCounter()
        let service = makeService(
            store: store,
            acquire: { _ in false },
            release: { _ in released.increment() }
        )
        _ = try service.grantAccess(to: URL(fileURLWithPath: "/Users/example/Snips", isDirectory: true))

        _ = try service.withAuthorizedFolder { _ in () }

        XCTAssertEqual(released.value, 0)
    }

    @MainActor
    func testScopedAccessRequiresAGrant() {
        let store = BookmarkStoreFake()
        let service = makeService(store: store)

        XCTAssertThrowsError(try service.withAuthorizedFolder { _ in () }) { error in
            XCTAssertEqual(error as? FileAccessError, .authorizationMissing)
        }
    }

    @MainActor
    func testClearingTheAuthorizationForgetsTheGrant() throws {
        let store = BookmarkStoreFake()
        let service = makeService(store: store)
        _ = try service.grantAccess(to: URL(fileURLWithPath: "/Users/example/Snips", isDirectory: true))
        XCTAssertTrue(service.hasStoredAuthorization)

        service.clearAuthorization()

        XCTAssertFalse(service.hasStoredAuthorization)
    }
}

final class AppleSaveOutcomeTests: XCTestCase {
    /// Every failure carries a reason the user can read.
    func testEveryFileAccessErrorHasAUserFacingReason() {
        let errors: [FileAccessError] = [
            .authorizationMissing,
            .folderUnavailable("/Users/example/Gone"),
            .writeFailed("permission denied"),
            .encodingFailed("no data")
        ]

        for error in errors {
            XCTAssertFalse(error.userFacingReason.isEmpty, "\(error) needs a readable reason")
        }
    }

    func testFailureCarriesTheReason() {
        let outcome = SaveOutcome.failed(.authorizationMissing)
        guard case .failed(let error) = outcome else {
            return XCTFail("Expected a failure outcome")
        }
        XCTAssertEqual(error, .authorizationMissing)
    }
}
