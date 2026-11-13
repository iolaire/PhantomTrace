import Foundation

/// An Egress Shells action that was not delivered because the user must act by hand (Requirement 7).
public struct ManualAction: Equatable, Sendable {
    public let action: ProposedAction
    public let reason: EgressManualReason
    /// What the user can do, for example "In the terminal running the shell with pid 10, type: cd ~".
    public let instruction: String

    public init(action: ProposedAction, reason: EgressManualReason, instruction: String) {
        self.action = action
        self.reason = reason
        self.instruction = instruction
    }
}

/// The result of executing one stage, including the post-stage rescan.
public struct StageOutcome: Equatable, Sendable {
    public let stage: ResolutionStage
    public let succeeded: [ProposedAction]
    public let failed: [FailedAction]
    /// Actions that need the user to act by hand. Neither succeeded nor failed; nothing was sent.
    public let manual: [ManualAction]
    /// Locks left after the post-stage rescan. Empty when `rescanTimedOut` is true: nothing is reported as verified.
    public let remainingLocks: [LockRecord]
    /// True when the post-stage rescan did not finish within its time limit.
    public let rescanTimedOut: Bool

    public init(
        stage: ResolutionStage,
        succeeded: [ProposedAction],
        failed: [FailedAction],
        manual: [ManualAction] = [],
        remainingLocks: [LockRecord],
        rescanTimedOut: Bool = false
    ) {
        self.stage = stage
        self.succeeded = succeeded
        self.failed = failed
        self.manual = manual
        self.remainingLocks = remainingLocks
        self.rescanTimedOut = rescanTimedOut
    }
}
