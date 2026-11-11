import Foundation
import Synchronization
import PhantomTraceCore

/// Table-driven `ProcessInspecting`. `setDetails` simulates a process appearing, changing, or exiting.
public final class MockProcessInspector: ProcessInspecting {
    public let currentProcessID: Int32
    public let currentUserID: UInt32
    private let table: Mutex<[Int32: ProcessDetails]>
    public let log = CallLog<Int32>()

    public init(
        currentProcessID: Int32 = 4242,
        currentUserID: UInt32 = 501,
        processes: [Int32: ProcessDetails] = [:]
    ) {
        self.currentProcessID = currentProcessID
        self.currentUserID = currentUserID
        table = Mutex(processes)
    }

    /// Pids inspected, in call order.
    public var calls: [Int32] { log.calls }

    public func setDetails(_ details: ProcessDetails?, forPID pid: Int32) {
        table.withLock { $0[pid] = details }
    }

    public func inspect(pid: Int32) -> ProcessDetails? {
        log.record(pid)
        return table.withLock { $0[pid] }
    }
}
