import Foundation

/// The result of `SafetyPolicy.evaluate`.
public enum SafetyVerdict: Equatable, Sendable {
    case allow
    case deny(SafetyDenial)

    public var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }
}
