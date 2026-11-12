import Foundation

/// Error mapping and Failure_Banner text, kept apart from the coordinator's state handling.
extension DiagnosticCoordinator {
    static func asPhantomTraceError(_ error: any Error, input: URL) -> PhantomTraceError {
        if let known = error as? PhantomTraceError { return known }
        return .notAMountPoint(input)  // an unknown resolver error is reported as an unresolvable input
    }
    /// Plain text for the Failure_Banner. Names the kind of failure and avoids paths at default detail.
    static func describe(_ error: PhantomTraceError) -> String {
        switch error {
        case .notAMountPoint: return "the path is not on a mounted volume."
        case .protectedVolume: return "this volume is protected and is never scanned."
        case .lsofUnavailable: return "lsof is not available."
        case .lsofTimedOut(let seconds): return "lsof did not finish within \(Int(seconds)) seconds."
        case .commandTimedOut(let command, let seconds):
            return "\(command) did not finish within \(Int(seconds)) seconds."
        case .commandLaunchFailed(let command): return "\(command) could not be started."
        case .permissionDenied(let pid): return "permission denied for pid \(pid)."
        case .processIdentityChanged(let pid): return "pid \(pid) changed, so it was left alone."
        case .unmountBusy: return "the volume is still busy."
        case .unmountFailed(let code): return "the unmount failed (code \(code))."
        }
    }
}
