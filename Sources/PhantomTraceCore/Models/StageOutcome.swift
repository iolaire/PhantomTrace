import Foundation

/// The result of executing one stage, including the post-stage rescan.
public struct StageOutcome: Equatable, Sendable {
    public let stage: ResolutionStage
    public let succeeded: [ProposedAction]
    public let failed: [FailedAction]
    /// Locks left after the post-stage rescan. Empty when `rescanTimedOut` is true: nothing is reported as verified.
    public let remainingLocks: [LockRecord]
    /// True when the post-stage rescan did not finish within its time limit.
    public let rescanTimedOut: Bool

    public init(
        stage: ResolutionStage,
        succeeded: [ProposedAction],
        failed: [FailedAction],
        remainingLocks: [LockRecord],
        rescanTimedOut: Bool = false
    ) {
        self.stage = stage
        self.succeeded = succeeded
        self.failed = failed
        self.remainingLocks = remainingLocks
        self.rescanTimedOut = rescanTimedOut
    }
}
