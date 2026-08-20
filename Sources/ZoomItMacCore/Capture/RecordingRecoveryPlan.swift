import Foundation

protocol RecordingRecoveryStoring: AnyObject {
    func save(_ manifest: RecordingRecoveryManifest) throws
    func remove(id: String) throws
    func loadAll() throws -> [RecordingRecoveryManifest]
    func fileState(for manifest: RecordingRecoveryManifest) -> RecordingRecoveryFileState
    func deleteMovie(for manifest: RecordingRecoveryManifest) throws
}

enum RecordingFragmentPolicy {
    static let movieFragmentIntervalSeconds: TimeInterval = 2
}

enum RecordingRecoveryPhase: String, Codable, Equatable, Sendable {
    case recording
    case paused
    case finalizing
    case finalized
}

struct RecordingRecoveryManifest: Codable, Equatable, Sendable {
    var id: String
    var temporaryPath: String
    var createdAt: Date
    var phase: RecordingRecoveryPhase
    var fragmentIntervalSeconds: TimeInterval

    var isPermanentHistory: Bool { false }

    static func start(
        id: String,
        temporaryPath: String,
        createdAt: Date
    ) -> RecordingRecoveryManifest {
        RecordingRecoveryManifest(
            id: id,
            temporaryPath: temporaryPath,
            createdAt: createdAt,
            phase: .recording,
            fragmentIntervalSeconds: RecordingFragmentPolicy.movieFragmentIntervalSeconds
        )
    }
}

final class RecordingRecoverySession {
    private let store: RecordingRecoveryStoring
    private let now: () -> Date
    private let makeID: () -> String

    private(set) var activeManifest: RecordingRecoveryManifest?

    init(
        store: RecordingRecoveryStoring,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.store = store
        self.now = now
        self.makeID = makeID
    }

    func start(temporaryURL: URL) throws {
        let manifest = RecordingRecoveryManifest.start(
            id: makeID(),
            temporaryPath: temporaryURL.path,
            createdAt: now()
        )
        try persist(manifest)
    }

    func setPhase(_ phase: RecordingRecoveryPhase) throws {
        guard var manifest = activeManifest else { return }
        manifest.phase = phase
        try persist(manifest)
    }

    func replaceTemporaryURL(_ url: URL) throws {
        guard var manifest = activeManifest else { return }
        manifest.temporaryPath = url.path
        try persist(manifest)
    }

    func clearAfterSuccessfulDisposition() throws {
        guard let manifest = activeManifest else { return }
        try store.remove(id: manifest.id)
        activeManifest = nil
    }

    private func persist(_ manifest: RecordingRecoveryManifest) throws {
        try store.save(manifest)
        activeManifest = manifest
    }
}

enum RecordingRecoveryFileState: Equatable, Sendable {
    case missing
    case fragmentedMovie(byteCount: Int64)
    case finalizedMovie(byteCount: Int64)
}

enum RecordingRecoveryDiscardReason: Equatable, Sendable {
    case movieMissing
    case movieEmpty
}

enum RecordingRecoveryActionPlan: Equatable, Sendable {
    case recoverMovie(path: String, isFinalized: Bool)
    case discardManifest(reason: RecordingRecoveryDiscardReason)
}

enum RecordingRecoveryPlanner {
    static func plan(
        manifest: RecordingRecoveryManifest,
        file: RecordingRecoveryFileState
    ) -> RecordingRecoveryActionPlan {
        switch file {
        case .missing:
            return .discardManifest(reason: .movieMissing)
        case .fragmentedMovie(let byteCount) where byteCount <= 0:
            return .discardManifest(reason: .movieEmpty)
        case .finalizedMovie(let byteCount) where byteCount <= 0:
            return .discardManifest(reason: .movieEmpty)
        case .fragmentedMovie:
            return .recoverMovie(path: manifest.temporaryPath, isFinalized: false)
        case .finalizedMovie:
            return .recoverMovie(path: manifest.temporaryPath, isFinalized: manifest.phase == .finalized)
        }
    }
}

enum RecordingRecoverySimulationOperation: Equatable, Sendable {
    case save(String)
    case remove(String)
}

struct RecordingRecoverySimulationStore: Equatable, Sendable {
    private var manifestsByID: [String: RecordingRecoveryManifest] = [:]
    private(set) var operations: [RecordingRecoverySimulationOperation] = []
    let platformBoundary = AutomationPlatformBoundary.simulatedOnly

    mutating func save(_ manifest: RecordingRecoveryManifest) throws {
        manifestsByID[manifest.id] = manifest
        operations.append(.save(manifest.id))
    }

    mutating func remove(id: String) throws {
        manifestsByID[id] = nil
        operations.append(.remove(id))
    }

    func loadAll() throws -> [RecordingRecoveryManifest] {
        manifestsByID.values.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
    }
}
