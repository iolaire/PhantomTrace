import Foundation

/// The outcome of one discovery run.
public struct DiscoveryResult: Equatable, Sendable {
    public let locks: [LockRecord]
    /// True when the result came from the fallback cross-check and may be incomplete.
    public let partial: Bool
    public let warnings: [ParseWarning]

    public init(locks: [LockRecord], partial: Bool = false, warnings: [ParseWarning] = []) {
        self.locks = locks
        self.partial = partial
        self.warnings = warnings
    }
}
