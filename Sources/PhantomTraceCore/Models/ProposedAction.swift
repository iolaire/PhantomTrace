import Foundation

/// An action the pipeline wants to take, subject to `SafetyPolicy` approval.
public struct ProposedAction: Equatable, Sendable {
    public let kind: ProposedActionKind
    /// The target process identity. `nil` for actions without a process target, such as `unmount`.
    public let target: ProcessIdentity?
    public let reason: String

    public init(kind: ProposedActionKind, target: ProcessIdentity?, reason: String) {
        self.kind = kind
        self.target = target
        self.reason = reason
    }
}
