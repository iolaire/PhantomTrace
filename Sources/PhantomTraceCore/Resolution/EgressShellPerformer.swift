import Foundation

/// Why an Egress Shells action needs the user to act by hand.
public enum EgressManualReason: Equatable, Sendable {
    /// The shell has no controlling terminal.
    case noTerminal
    /// A job other than the shell owns the terminal, or the foreground group is unknown.
    case foregroundJob
    /// The terminal is not scriptable: unsupported application or Automation permission denied.
    case notScriptable
}

/// Why an Egress Shells action failed. The caller maps these onto its own error reporting.
public enum EgressFailure: Equatable, Sendable {
    /// The action is not a process-targeting `resetShellCwd`.
    case invalidAction
    /// The pid is gone or now belongs to a different process.
    case processIdentityChanged(pid: UInt32)
    /// The text was sent but the shell never left the volume within the verification window.
    case stillOnVolume(pid: UInt32)
}

/// Result of one Egress Shells action.
public enum EgressShellResult: Equatable, Sendable {
    case succeeded
    /// Nothing was sent. `instruction` is what the user can run by hand.
    case manual(reason: EgressManualReason, instruction: String)
    case failed(EgressFailure)
}

/// Performs one already-approved `resetShellCwd` action (Requirements 7.2 to 7.7).
///
/// Internal on purpose: only `ResolutionPipeline` may reach it, and only after `SafetyPolicy` allowed the
/// action (Requirement 6.7). The injected text is a constant inside `TerminalScripting`; nothing here can
/// influence it. A send is never retried.
struct EgressShellPerformer: Sendable {
    /// Requirement 7.4: the shell is re-inspected for this long after a send.
    static let verificationSeconds: TimeInterval = 5
    static let pollIntervalSeconds: TimeInterval = 0.25

    private let inspector: any ProcessInspecting
    private let terminal: any TerminalScripting
    private let clock: any Sleeping

    init(inspector: any ProcessInspecting, terminal: any TerminalScripting, clock: any Sleeping) {
        self.inspector = inspector
        self.terminal = terminal
        self.clock = clock
    }

    /// The only text shown to the user for a manual fallback: it carries the pid and nothing else.
    static func manualInstruction(pid: UInt32) -> String {
        "In the terminal running the shell with pid \(pid), type: cd ~"
    }

    func perform(_ action: ProposedAction, volumeMountPoint: URL) async -> EgressShellResult {
        guard action.kind == .resetShellCwd, let target = action.target else {
            return .failed(.invalidAction)
        }
        guard let details = inspector.inspect(pid: Int32(truncatingIfNeeded: target.pid)),
              details.identity == target else {
            return .failed(.processIdentityChanged(pid: target.pid))
        }
        let instruction = Self.manualInstruction(pid: target.pid)
        guard let device = details.terminalDevice else {
            return .manual(reason: .noTerminal, instruction: instruction)
        }
        // An unknown foreground group cannot be shown to be the shell, so it is treated as busy.
        guard details.foregroundProcessGroupID == details.processGroupID else {
            return .manual(reason: .foregroundJob, instruction: instruction)
        }
        switch await terminal.sendChangeDirectoryHome(toTerminalDevice: device) {
        case .sent:
            return await verify(target: target, volumeMountPoint: volumeMountPoint)
        case .automationDenied, .unsupportedTerminal:
            return .manual(reason: .notScriptable, instruction: instruction)
        }
    }

    private func verify(target: ProcessIdentity, volumeMountPoint: URL) async -> EgressShellResult {
        var waited: TimeInterval = 0
        while true {
            guard let current = inspector.inspect(pid: Int32(truncatingIfNeeded: target.pid)),
                  current.identity == target else {
                return .failed(.processIdentityChanged(pid: target.pid))
            }
            if let directory = current.currentDirectory,
               !Self.isWithin(directory, mountPoint: volumeMountPoint) {
                return .succeeded
            }
            guard waited < Self.verificationSeconds else {
                return .failed(.stillOnVolume(pid: target.pid))
            }
            do {
                try await clock.sleep(seconds: Self.pollIntervalSeconds)
            } catch {
                return .failed(.stillOnVolume(pid: target.pid))
            }
            waited += Self.pollIntervalSeconds
        }
    }

    /// Whole-component prefix test, so `/Volumes/A` never matches `/Volumes/AB/x`.
    static func isWithin(_ directory: URL, mountPoint: URL) -> Bool {
        let path = directory.standardizedFileURL.pathComponents
        let mount = mountPoint.standardizedFileURL.pathComponents
        return path.count >= mount.count && Array(path.prefix(mount.count)) == mount
    }
}
