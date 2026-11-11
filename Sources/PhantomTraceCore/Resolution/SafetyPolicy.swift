import Foundation

/// Approves or denies actions on behalf of the pipeline.
public protocol SafetyPolicying: Sendable {
    func evaluate(_ action: ProposedAction, context: SafetyContext) async -> SafetyVerdict
}

/// The single approval path for every `ProposedAction` (Requirement 6.7).
public struct SafetyPolicy: SafetyPolicying {
    /// Requirement 6.6: facts older than this are treated as undetermined.
    public static let determinationLimitMilliseconds = 1000

    /// Requirement 6.1 names.
    public static let protectedProcessNames: Set<String> = [
        "launchd", "kernel_task", "WindowServer", "loginwindow", "Finder"
    ]

    private let ownPID: UInt32
    private let currentUserID: UInt32
    private let history: AttemptHistory

    public init(ownPID: UInt32, currentUserID: UInt32, history: AttemptHistory) {
        self.ownPID = ownPID
        self.currentUserID = currentUserID
        self.history = history
    }

    public func evaluate(_ action: ProposedAction, context: SafetyContext) async -> SafetyVerdict {
        guard let target = action.target else {
            // Unmount has no process target; volume protection is enforced by MountResolver.
            return action.kind == .unmount ? .allow : .deny(.undeterminableState)
        }
        if let denial = protectedDenial(pid: target.pid, name: context.processName) {
            return .deny(denial)
        }
        guard let owner = context.ownerUserID,
              context.determinationMilliseconds <= Self.determinationLimitMilliseconds else {
            return .deny(.undeterminableState)
        }
        if owner != currentUserID, !context.authorizedIdentities.contains(target) {
            return .deny(.ownedByOtherUser)
        }
        if action.kind == .sendSIGKILL {
            return await killVerdict(target: target, context: context)
        }
        return .allow
    }

    private func protectedDenial(pid: UInt32, name: String?) -> SafetyDenial? {
        if pid == 0 || pid == 1 { return .protectedPid }
        if pid == ownPID { return .ownProcess }
        if let name, Self.protectedProcessNames.contains(name) { return .protectedProcessName }
        // An unknown name cannot be shown to be unprotected.
        return name == nil ? .undeterminableState : nil
    }

    private func killVerdict(target: ProcessIdentity, context: SafetyContext) async -> SafetyVerdict {
        if await history.hasGracefulAttempt(for: target) { return .allow }
        if context.role == .systemDaemon, context.confirmedDaemons.contains(target) { return .allow }
        return .deny(.noPriorGracefulAttempt)
    }
}
