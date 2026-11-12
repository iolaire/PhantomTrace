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

/// Describes the modal dialogs. Callers present them with `PhantomDialog`; nothing here acts on a
/// process or volume.
@MainActor
public enum StageDialogs {
    /// The confirm button names what the stage does, not just "Run" (Requirement 9.5).
    public static func confirmTitle(for stage: ResolutionStage) -> String {
        switch stage {
        case .egressShells: return "Send Shells Home"
        case .gracefulRequest: return "Ask to Quit"
        // A second confirmation listing every target follows (Requirement 11.5).
        case .banishLocks: return "Continue\u{2026}"
        case .cleanHandoff: return "Eject"
        }
    }
    /// Plan preview shown before a stage runs. Button 0 confirms and is the default (Requirement 9.5).
    public static func planPreview(_ plan: ResolutionPlan, locks: [LockRecord]) -> PhantomDialogSpec {
        let stage = PhantomChoiceControl.title(for: plan.stage)
        return PhantomDialogSpec(
            plaque: stage.uppercased(),
            message: "\(stage): review the plan",
            detail: StageDialogText.planPreview(plan, locks: locks),
            buttons: [confirmTitle(for: plan.stage), "Cancel"],
            defaultButton: 0,
            cancelButton: 1
        )
    }
    /// Banish Locks confirmation listing each target by name and pid. Cancel is the default
    /// button so Return never confirms a forced stop (Requirement 11.5).
    public static func banishConfirmation(_ plan: ResolutionPlan, locks: [LockRecord]) -> PhantomDialogSpec {
        PhantomDialogSpec(
            plaque: "BANISH LOCKS",
            message: "Force these processes to stop?",
            detail: """
                Unsaved work in these processes may be lost, including changes to files open on this volume.
                \(StageDialogText.banishTargets(plan, locks: locks))
                """,
            buttons: ["Cancel", "Banish Locks"],
            defaultButton: 0,
            cancelButton: 0,
            severity: .critical
        )
    }
    /// Advanced force-unmount confirmation (Requirement 10.8). Cancel is the default button.
    public static func forceUnmountConfirmation(volumeName: String) -> PhantomDialogSpec {
        PhantomDialogSpec(
            plaque: "FORCE UNMOUNT",
            message: "Force unmount \(volumeName)?",
            detail: "Forcing can lose data that is still being written. Use it only if a normal eject keeps failing.",
            buttons: ["Cancel", "Force Unmount"],
            defaultButton: 0,
            cancelButton: 0,
            severity: .critical
        )
    }
    /// A dismiss-only notice, for example why an item cannot be inspected (Requirements 2.4, 2.5, 12.4).
    public static func notice(message: String, detail: String) -> PhantomDialogSpec {
        PhantomDialogSpec(
            plaque: "PHANTOMTRACE",
            message: message,
            detail: detail,
            buttons: ["Dismiss"],
            defaultButton: 0,
            cancelButton: 0
        )
    }
}
