import Foundation

/// Delivers a signal to a process. Reachable only through `ResolutionPipeline` after `SafetyPolicy` approval.
///
/// Takes a pid and a signal value, never a command string (Requirement 15.1, 15.6).
public protocol SignalSending: Sendable {
    /// Throws `PhantomTraceError.permissionDenied(pid:)` on `EPERM`.
    func send(_ signal: ProcessSignal, to pid: Int32) throws
}
