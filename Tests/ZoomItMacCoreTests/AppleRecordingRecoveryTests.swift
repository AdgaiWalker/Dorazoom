import XCTest
@testable import ZoomItMacCore

final class AppleRecordingRecoveryTests: XCTestCase {
    func testMovieWriterUsesShortFragmentsAndCreatesRecoverableManifest() {
        XCTAssertEqual(RecordingFragmentPolicy.movieFragmentIntervalSeconds, 2)
        let manifest = RecordingRecoveryManifest.start(
            id: "session-1",
            temporaryPath: "/simulated/DoraZoom-session-1.mov",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(manifest.phase, .recording)
        XCTAssertEqual(manifest.fragmentIntervalSeconds, 2)
        XCTAssertFalse(manifest.isPermanentHistory)
    }

    func testRecordingPausedAndFinalizingFailuresRemainRecoverable() {
        let base = RecordingRecoveryManifest.start(
            id: "session-1",
            temporaryPath: "/simulated/DoraZoom-session-1.mov",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        for phase in [RecordingRecoveryPhase.recording, .paused, .finalizing] {
            var manifest = base
            manifest.phase = phase
            XCTAssertEqual(
                RecordingRecoveryPlanner.plan(manifest: manifest, file: .fragmentedMovie(byteCount: 4_096)),
                .recoverMovie(path: manifest.temporaryPath, isFinalized: false)
            )
        }
    }

    func testFinalizedMovieRecoversAsFinalizedAndMissingFileOnlyDiscardsManifest() {
        var manifest = RecordingRecoveryManifest.start(
            id: "session-1",
            temporaryPath: "/simulated/DoraZoom-session-1.mov",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        manifest.phase = .finalized

        XCTAssertEqual(
            RecordingRecoveryPlanner.plan(manifest: manifest, file: .finalizedMovie(byteCount: 8_192)),
            .recoverMovie(path: manifest.temporaryPath, isFinalized: true)
        )
        XCTAssertEqual(
            RecordingRecoveryPlanner.plan(manifest: manifest, file: .missing),
            .discardManifest(reason: .movieMissing)
        )
    }

    func testSimulationStoreCleansSuccessfulSessionAndKeepsInterruptedSession() throws {
        var store = RecordingRecoverySimulationStore()
        let first = RecordingRecoveryManifest.start(
            id: "first",
            temporaryPath: "/simulated/first.mov",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let second = RecordingRecoveryManifest.start(
            id: "second",
            temporaryPath: "/simulated/second.mov",
            createdAt: Date(timeIntervalSince1970: 2)
        )

        try store.save(first)
        try store.save(second)
        try store.remove(id: "first")

        XCTAssertEqual(try store.loadAll(), [second])
        XCTAssertEqual(store.operations, [.save("first"), .save("second"), .remove("first")])
        XCTAssertEqual(store.platformBoundary, .simulatedOnly)
    }

    func testRecoverySessionPersistsEveryRiskBoundaryAndCleansOnlyAfterSuccess() throws {
        let store = RecordingRecoveryStoreSpy()
        let session = RecordingRecoverySession(
            store: store,
            now: { Date(timeIntervalSince1970: 200) },
            makeID: { "session-lifecycle" }
        )

        try session.start(temporaryURL: URL(fileURLWithPath: "/simulated/original.mov"))
        try session.setPhase(.paused)
        try session.setPhase(.recording)
        try session.setPhase(.finalizing)
        try session.setPhase(.finalized)
        try session.replaceTemporaryURL(URL(fileURLWithPath: "/simulated/edited.mov"))

        XCTAssertEqual(store.saved.map(\.phase), [
            .recording, .paused, .recording, .finalizing, .finalized, .finalized
        ])
        XCTAssertEqual(session.activeManifest?.temporaryPath, "/simulated/edited.mov")
        XCTAssertEqual(store.removedIDs, [])

        try session.clearAfterSuccessfulDisposition()

        XCTAssertNil(session.activeManifest)
        XCTAssertEqual(store.removedIDs, ["session-lifecycle"])
    }

    func testRecoverySessionDoesNotAdvanceInMemoryWhenManifestPersistenceFails() throws {
        let store = RecordingRecoveryStoreSpy()
        let session = RecordingRecoverySession(
            store: store,
            now: { Date(timeIntervalSince1970: 300) },
            makeID: { "session-failure" }
        )
        try session.start(temporaryURL: URL(fileURLWithPath: "/simulated/original.mov"))
        store.shouldFailSave = true

        XCTAssertThrowsError(try session.setPhase(.paused))
        XCTAssertEqual(session.activeManifest?.phase, .recording)
    }
}

private final class RecordingRecoveryStoreSpy: RecordingRecoveryStoring {
    enum Failure: Error { case save }

    var saved: [RecordingRecoveryManifest] = []
    var removedIDs: [String] = []
    var shouldFailSave = false

    func save(_ manifest: RecordingRecoveryManifest) throws {
        if shouldFailSave { throw Failure.save }
        saved.append(manifest)
    }

    func remove(id: String) throws {
        removedIDs.append(id)
    }

    func loadAll() throws -> [RecordingRecoveryManifest] { saved }

    func fileState(for manifest: RecordingRecoveryManifest) -> RecordingRecoveryFileState {
        .fragmentedMovie(byteCount: 1)
    }

    func deleteMovie(for manifest: RecordingRecoveryManifest) throws {}
}
