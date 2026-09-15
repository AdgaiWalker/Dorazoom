import Foundation

/// Whether this build ships DemoType.
///
/// The App Store target compiles `DemoTypeController` out (see that file) so the
/// store binary carries no synthetic-input path and never asks for Input
/// Monitoring. Shared, testable UI models — the status menu plan, the settings
/// navigation plan, the shortcut-binding plan — read this flag instead of each
/// growing their own `#if`, which keeps both shapes of every plan unit-testable
/// from the one test target the package builds.
enum DemoTypeBuildAvailability {
#if DORAZOOM_APP_STORE
    static let isIncludedInBuild = false
#else
    static let isIncludedInBuild = true
#endif
}
