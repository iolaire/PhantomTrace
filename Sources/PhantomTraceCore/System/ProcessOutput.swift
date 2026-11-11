import Foundation

/// Raw result of a finished subprocess. Output stays as bytes; callers decode lazily.
public struct ProcessOutput: Equatable, Sendable {
    public let standardOutput: Data
    public let standardError: Data
    public let exitStatus: Int32

    public init(standardOutput: Data, standardError: Data, exitStatus: Int32) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitStatus = exitStatus
    }
}
