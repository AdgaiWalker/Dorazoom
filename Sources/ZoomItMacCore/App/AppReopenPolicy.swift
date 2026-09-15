import Foundation

/// What DoraZoom should present when the user opens the app again.
enum AppReopenIntent: Equatable, Sendable {
    /// The user asked for the app: show the primary entry — the operation panel
    /// once it exists, the status menu until then.
    case showPrimaryEntry
    /// A capture is running. Surface its status instead of starting anything.
    case showRecordingStatus
    /// A login-item launch, or a reopen the user did not initiate: stay in the
    /// menu bar and do not steal focus.
    case stayInMenuBar
}

/// Single decision point for the reopen path.
///
/// `applicationShouldHandleReopen` and the cross-instance notification both
/// route through this policy so that double-clicking the app, picking a menu
/// item and pressing a hotkey cannot end up in three different behaviours.
enum AppReopenPolicy {
    static func intent(isUserInitiated: Bool, isRecording: Bool) -> AppReopenIntent {
        // A login-item launch is not an open request, so it must not raise a
        // window or take focus.
        guard isUserInitiated else { return .stayInMenuBar }

        // Reopening during a capture shows the recording state rather than
        // starting a second capture.
        return isRecording ? .showRecordingStatus : .showPrimaryEntry
    }
}
