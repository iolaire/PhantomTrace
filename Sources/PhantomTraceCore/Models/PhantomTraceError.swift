import Foundation

/// Errors surfaced by PhantomTrace Core.
public enum PhantomTraceError: Error, Equatable, Sendable {
    case notAMountPoint(URL)
    case protectedVolume(URL)
    case lsofUnavailable
    case lsofTimedOut(seconds: Double)
    /// A non-lsof subprocess exceeded its time limit. `command` is the executable path. Requirement 15.7.
    case commandTimedOut(command: String, seconds: Double)
    /// A non-lsof subprocess could not be launched. `command` is the executable path.
    case commandLaunchFailed(command: String)
    case permissionDenied(pid: UInt32)
    case processIdentityChanged(pid: UInt32)
    case unmountBusy
    case unmountFailed(code: Int32)
    /// The task was cancelled before the operation finished. Nothing further was sent or unmounted.
    case cancelled
}
