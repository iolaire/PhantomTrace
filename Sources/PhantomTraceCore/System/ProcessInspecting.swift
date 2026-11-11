import Foundation

/// Looks up process facts: owner, start time, terminal and foreground group, and working directory.
///
/// Also supplies our own pid and uid so tests stay deterministic (Requirement 15.5).
public protocol ProcessInspecting: Sendable {
    /// PhantomTrace's own pid; never a valid signal target.
    var currentProcessID: Int32 { get }

    /// The uid PhantomTrace runs as.
    var currentUserID: UInt32 { get }

    /// Returns `nil` when the process is gone or cannot be inspected; callers treat that as deny.
    func inspect(pid: Int32) -> ProcessDetails?
}
