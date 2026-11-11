import Foundation

/// A lock the plan will not act on, with the reason.
public struct SkippedLock: Equatable, Sendable {
    public let lock: LockRecord
    public let denial: SafetyDenial

    public init(lock: LockRecord, denial: SafetyDenial) {
        self.lock = lock
        self.denial = denial
    }
}
