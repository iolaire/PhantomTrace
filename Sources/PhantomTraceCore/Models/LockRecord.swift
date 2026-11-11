import Foundation

/// A classified lock: one process holding one path on the volume.
public struct LockRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let pid: UInt32
    public let processName: String
    public let user: String
    public let category: LockCategory
    public let role: ProcessRole
    public let path: String
    public let pathBytes: Data
    public let accessMode: AccessMode?
    /// Process start time. `nil` when it could not be determined.
    public let processStart: Date?

    public init(
        id: UUID = UUID(),
        pid: UInt32,
        processName: String,
        user: String,
        category: LockCategory,
        role: ProcessRole,
        path: String,
        pathBytes: Data,
        accessMode: AccessMode? = nil,
        processStart: Date? = nil
    ) {
        self.id = id
        self.pid = pid
        self.processName = processName
        self.user = user
        self.category = category
        self.role = role
        self.path = path
        self.pathBytes = pathBytes
        self.accessMode = accessMode
        self.processStart = processStart
    }

    /// The identity used to guard against PID reuse, or `nil` when the start time is unknown.
    public var identity: ProcessIdentity? {
        processStart.map { ProcessIdentity(pid: pid, startTime: $0) }
    }
}
