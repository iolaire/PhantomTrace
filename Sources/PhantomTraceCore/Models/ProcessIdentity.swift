import Foundation

/// A process identity that survives PID reuse: `(pid, process start time)`.
public struct ProcessIdentity: Equatable, Hashable, Sendable {
    public let pid: UInt32
    public let startTime: Date

    public init(pid: UInt32, startTime: Date) {
        self.pid = pid
        self.startTime = startTime
    }
}
