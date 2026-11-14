import Foundation
import PhantomTraceCore

/// Plain-language text for the Failure_Banner and the stage failure list. No AppKit, so it is
/// easy to check. Requirements 9.2, 9.3, 14.1, 14.5.
enum StageMessages {
    static let noEligibleBanishProcesses = "No processes are eligible to banish. Nothing was changed."
    static let scanFailedHint = "The scan did not finish. Press Rescan to try again."

    /// One line per Parse_Warning, naming the kind and the byte offset.
    static func describe(_ warning: ParseWarning) -> String {
        switch warning {
        case .invalidPid(let offset):
            return "Invalid process ID at byte \(offset)"
        case .truncatedTail(let offset):
            return "Output ended early at byte \(offset); the last record was dropped"
        case .malformedEscape(let offset):
            return "Unreadable escape sequence at byte \(offset); kept as written"
        }
    }

    /// The count line for warnings left out of the banner, nil when none were.
    static func omittedWarnings(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "and \(count) more warning\(count == 1 ? "" : "s") not shown"
    }

    static func omittedActions(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "and \(count) more failed action\(count == 1 ? "" : "s") not shown"
    }

    /// The error kind for a failed action, without paths.
    static func describe(_ error: PhantomTraceError) -> String {
        switch error {
        case .notAMountPoint: return "not a mount point"
        case .protectedVolume: return "protected volume"
        case .lsofUnavailable: return "lsof is unavailable"
        case .lsofTimedOut(let seconds): return "lsof timed out after \(Int(seconds)) s"
        case .commandTimedOut(let command, let seconds):
            return "\(URL(fileURLWithPath: command).lastPathComponent) timed out after \(Int(seconds)) s"
        case .commandLaunchFailed(let command):
            return "\(URL(fileURLWithPath: command).lastPathComponent) could not be started"
        case .permissionDenied, .processIdentityChanged, .unmountBusy, .unmountFailed, .cancelled:
            return describeOperation(error)
        }
    }

    /// The errors of stages and unmounts. Split from `describe` to keep each switch small.
    private static func describeOperation(_ error: PhantomTraceError) -> String {
        switch error {
        case .permissionDenied: return "permission denied"
        case .processIdentityChanged: return "process changed since the scan"
        case .unmountBusy: return "volume is busy"
        case .unmountFailed(let code): return "unmount failed (code \(code))"
        case .cancelled: return "cancelled before it finished"
        case .notAMountPoint, .protectedVolume, .lsofUnavailable, .lsofTimedOut, .commandTimedOut,
             .commandLaunchFailed:
            return ""  // handled by `describe`, which never forwards these
        }
    }

    static func describe(_ kind: ProposedActionKind) -> String {
        switch kind {
        case .resetShellCwd: return "Move shell to home"
        case .quitApplication: return "Quit application"
        case .sendSIGTERM: return "Send SIGTERM"
        case .sendSIGKILL: return "Send SIGKILL"
        case .unmount: return "Unmount"
        }
    }

    /// "Quit application, pid 123: permission denied".
    static func describe(_ failure: FailedAction) -> String {
        let action = describe(failure.action.kind)
        let reason = describe(failure.error)
        guard let pid = failure.action.target?.pid else { return "\(action): \(reason)" }
        return "\(action), pid \(pid): \(reason)"
    }

    /// Why PhantomTrace sent nothing to a shell (Requirement 7.5).
    static func describe(_ reason: EgressManualReason) -> String {
        switch reason {
        case .noTerminal: return "the shell has no terminal"
        case .foregroundJob: return "a program is running in its terminal"
        case .notScriptable: return "PhantomTrace could not type into its terminal"
        }
    }

    /// "Do it yourself (PhantomTrace could not type into its terminal): In the terminal running the shell
    /// with pid 5883, type: cd ~". The instruction is Core's fixed text with the pid, nothing else.
    static func describe(_ manual: ManualAction) -> String {
        "Do it yourself (\(describe(manual.reason))): \(manual.instruction)"
    }

    static func omittedManualActions(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "and \(count) more shell\(count == 1 ? "" : "s") to move by hand not shown"
    }
}
