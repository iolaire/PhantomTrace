import Darwin
import Foundation

/// Live `SignalSending` built on `kill(2)` (Requirements 5.4, 6.8).
///
/// The syscall is injected as `killCall` so tests can exercise the errno mapping without ever signaling a
/// real process. Production code uses the default, which is plain `kill`.
public struct LiveSignalSender: SignalSending {
    /// Takes a pid and a raw signal number and returns `0` on success, otherwise the errno value.
    public typealias KillCall = @Sendable (Int32, Int32) -> Int32

    private let killCall: KillCall

    public init(killCall: @escaping KillCall = LiveSignalSender.systemKill) {
        self.killCall = killCall
    }

    /// - `EPERM` throws `permissionDenied(pid:)` and the pipeline continues with the next action.
    /// - `ESRCH` means the process already exited, which is the outcome the caller wanted, so it returns.
    /// - Anything else throws `commandLaunchFailed(command: "kill")`.
    public func send(_ signal: ProcessSignal, to pid: Int32) throws {
        // kill(2) with pid <= 0 targets process groups or every process. Never allow it, whatever the caller says.
        guard pid > 1 else {
            throw PhantomTraceError.permissionDenied(pid: UInt32(clamping: max(pid, 0)))
        }
        let code = killCall(pid, Self.rawValue(of: signal))
        switch code {
        case 0, ESRCH:
            return
        case EPERM:
            throw PhantomTraceError.permissionDenied(pid: UInt32(pid))
        default:
            throw PhantomTraceError.commandLaunchFailed(command: "kill")
        }
    }

    static func rawValue(of signal: ProcessSignal) -> Int32 {
        switch signal {
        case .terminate: return SIGTERM
        case .kill: return SIGKILL
        }
    }

    /// The real syscall. Only reachable from the app and CLI composition roots.
    public static let systemKill: KillCall = { pid, signal in
        kill(pid, signal) == 0 ? 0 : errno
    }
}
