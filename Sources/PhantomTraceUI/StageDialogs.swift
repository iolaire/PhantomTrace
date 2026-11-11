import AppKit
import PhantomTraceCore

/// Text for the plan preview and confirmation dialogs. Pure, so it can be checked without a UI.
/// Requirements 9.5, 11.5, 10.8.
public enum StageDialogText {
    /// Maximum entries listed before the rest are summarized.
    public static let maximumListed = 50

    public static func denialText(_ denial: SafetyDenial) -> String {
        switch denial {
        case .protectedPid: return "protected system process"
        case .protectedProcessName: return "protected system process"
        case .ownProcess: return "PhantomTrace itself"
        case .ownedByOtherUser: return "owned by another user (read-only)"
        case .noPriorGracefulAttempt: return "no graceful attempt recorded yet"
        case .protectedVolume: return "protected or unverifiable volume"
        case .undeterminableState: return "state could not be determined in time"
        case .stageNotSelected: return "not part of the selected stage"
        }
    }

    public static func actionText(_ kind: ProposedActionKind) -> String {
        switch kind {
        case .resetShellCwd: return "move shell to home folder (cd ~)"
        case .quitApplication: return "ask to quit"
        case .sendSIGTERM: return "send SIGTERM"
        case .sendSIGKILL: return "send SIGKILL"
        case .unmount: return "unmount"
        }
    }

    /// One line per approved action, then one per skipped lock with its denial reason.
    public static func planPreview(_ plan: ResolutionPlan, locks: [LockRecord]) -> String {
        var names: [UInt32: String] = [:]
        for lock in locks { names[lock.pid] = lock.processName }
        var lines: [String] = []
        if plan.actions.isEmpty {
            lines.append("No actions will be taken.")
        } else {
            lines.append("Will do:")
            lines += capped(plan.actions.map { action in
                let pid = action.target?.pid
                let who = pid.map { "\(names[$0] ?? "process") (pid \($0))" } ?? "volume"
                return "  \(who): \(actionText(action.kind))"
            })
        }
        if !plan.skipped.isEmpty {
            lines.append("Will skip:")
            lines += capped(plan.skipped.map { skipped in
                "  \(skipped.lock.processName) (pid \(skipped.lock.pid)): \(denialText(skipped.denial))"
            })
        }
        return lines.joined(separator: "\n")
    }

    /// Process names and pids that Banish Locks would force-stop (Requirement 11.5).
    public static func banishTargets(_ plan: ResolutionPlan, locks: [LockRecord]) -> String {
        var names: [UInt32: String] = [:]
        for lock in locks { names[lock.pid] = lock.processName }
        let pids = plan.actions.compactMap { $0.target?.pid }
        let unique = pids.reduce(into: [UInt32]()) { if !$0.contains($1) { $0.append($1) } }
        return capped(unique.map { "  \(names[$0] ?? "process") (pid \($0))" }).joined(separator: "\n")
    }

    private static func capped(_ lines: [String]) -> [String] {
        guard lines.count > maximumListed else { return lines }
        return Array(lines.prefix(maximumListed)) + ["  ...and \(lines.count - maximumListed) more"]
    }
}

/// Builds the modal dialogs. Callers run them; nothing here acts on a process or volume.
@MainActor
public enum StageDialogs {
    /// Plan preview shown before a stage runs. The first button confirms (Requirement 9.5).
    public static func planPreview(_ plan: ResolutionPlan, locks: [LockRecord]) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "\(PhantomChoiceControl.title(for: plan.stage)): review the plan"
        alert.informativeText = StageDialogText.planPreview(plan, locks: locks)
        alert.addButton(withTitle: "Run Stage")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    /// Banish Locks confirmation listing each target by name and pid. Cancel is the default
    /// button so Return never confirms a forced stop (Requirement 11.5).
    public static func banishConfirmation(_ plan: ResolutionPlan, locks: [LockRecord]) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Force these processes to stop?"
        alert.informativeText = """
            Unsaved work in these processes may be lost.

            \(StageDialogText.banishTargets(plan, locks: locks))
            """
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Banish Locks")
        return alert
    }

    /// Advanced force-unmount confirmation (Requirement 10.8). Cancel is the default button.
    public static func forceUnmountConfirmation(volumeName: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Force unmount \(volumeName)?"
        alert.informativeText = "Forcing can lose data that is still being written. Use it only if a normal "
            + "eject keeps failing."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Force Unmount")
        return alert
    }
}
