import Foundation

/// The graduated resolution stages, in escalation order.
public enum ResolutionStage: Int, Comparable, Hashable, Sendable, CaseIterable {
    case egressShells = 1
    case gracefulRequest
    case banishLocks
    case cleanHandoff

    public static func < (lhs: ResolutionStage, rhs: ResolutionStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
