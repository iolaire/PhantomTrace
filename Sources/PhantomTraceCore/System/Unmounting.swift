import Foundation

/// Unmounts a volume. Reachable only through `ResolutionPipeline` after a clean scan and user confirmation.
///
/// Takes a `MountInfo` value, never a command string (Requirement 15.1, 15.6).
public protocol Unmounting: Sendable {
    /// Throws `PhantomTraceError.unmountBusy` when the volume is busy and
    /// `PhantomTraceError.unmountFailed(code:)` for other failures.
    func unmount(_ volume: MountInfo, force: Bool) async throws
}
