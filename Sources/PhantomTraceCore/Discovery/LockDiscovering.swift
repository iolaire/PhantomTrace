import Foundation

/// Finds the locks on one volume (Requirement 3).
public protocol LockDiscovering: Sendable {
    /// Scans `volume` and returns its classified, merged locks.
    ///
    /// Throws `PhantomTraceError.protectedVolume` without scanning, `lsofUnavailable`, or `lsofTimedOut`.
    func discover(in volume: MountInfo) async throws -> DiscoveryResult
}
