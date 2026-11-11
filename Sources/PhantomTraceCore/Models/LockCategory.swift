import Foundation

/// How a process holds the volume.
public enum LockCategory: String, Equatable, Hashable, Sendable, CaseIterable {
    case cwd
    case openFileHandle
}
