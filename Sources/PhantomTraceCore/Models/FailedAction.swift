import Foundation

/// An action that did not succeed, with the error recorded for it.
public struct FailedAction: Equatable, Sendable {
    public let action: ProposedAction
    public let error: PhantomTraceError

    public init(action: ProposedAction, error: PhantomTraceError) {
        self.action = action
        self.error = error
    }
}
