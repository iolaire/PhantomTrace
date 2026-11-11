import Foundation

/// Records which process identities already received a graceful attempt
/// (`quitApplication` or `sendSIGTERM`). Requirement 6.3.
///
/// An actor because the pipeline records attempts while the policy reads them concurrently.
public actor AttemptHistory {
    private var gracefulAttempts: Set<ProcessIdentity> = []

    public init() {}

    /// Records a graceful attempt, including attempts whose delivery failed.
    public func recordGracefulAttempt(for identity: ProcessIdentity) {
        gracefulAttempts.insert(identity)
    }

    public func hasGracefulAttempt(for identity: ProcessIdentity) -> Bool {
        gracefulAttempts.contains(identity)
    }

    /// Forgets all attempts; a new resolution run starts with a clean history.
    public func reset() {
        gracefulAttempts.removeAll()
    }
}
