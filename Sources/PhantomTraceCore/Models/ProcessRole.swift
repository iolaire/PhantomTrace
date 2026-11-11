import Foundation

/// What kind of process holds a lock.
public enum ProcessRole: String, Equatable, Hashable, Sendable, CaseIterable {
    case systemDaemon
    case idleShell
    case userApplication
    case cliTool
    case unknown
}
