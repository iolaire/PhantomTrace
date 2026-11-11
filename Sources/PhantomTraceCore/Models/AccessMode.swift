import Foundation

/// File descriptor access mode as reported by the `a` field of `lsof -F`.
public enum AccessMode: String, Equatable, Hashable, Sendable, CaseIterable {
    case read = "r"
    case write = "w"
    case readWrite = "u"
}
