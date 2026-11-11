import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Synchronization

final class GatedDiscovery: LockDiscovering {
    private let result: Result<DiscoveryResult, PhantomTraceError>
    private let gated = Mutex(false)
    private let gate: AsyncStream<Void>
    private let release: AsyncStream<Void>.Continuation

    init(result: Result<DiscoveryResult, PhantomTraceError>, gated: Bool) {
        self.result = result
        self.gated.withLock { $0 = gated }
        (gate, release) = AsyncStream<Void>.makeStream()
    }

    func setGated(_ value: Bool) {
        gated.withLock { $0 = value }
    }

    func open() {
        release.yield(())
    }

    func discover(in volume: MountInfo) async throws -> DiscoveryResult {
        if gated.withLock({ $0 }) {
            for await _ in gate { break }
        }
        return try result.get()
    }
}

/// A clock whose sleeps last until the test lets them end. Records requested durations.
final class HeldSleeper: Sleeping {
    let log = CallLog<TimeInterval>()
    private let gate: AsyncStream<Void>
    private let release: AsyncStream<Void>.Continuation

    init() {
        (gate, release) = AsyncStream<Void>.makeStream()
    }

    func open() {
        release.yield(())
    }

    func now() -> Date { Date(timeIntervalSince1970: 0) }

    func sleep(seconds: TimeInterval) async throws {
        log.record(seconds)
        for await _ in gate { break }
    }
}

struct CoordinatorRig {
    let coordinator: DiagnosticCoordinator
    let stages: MockStageRunner
    let resolver: MockMountResolver
}

/// Shared setup for the DiagnosticCoordinator scenario suites.
protocol CoordinatorScenario {}

extension CoordinatorScenario {
    var volume: MountInfo {
        MountInfo(
            mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
            volumeName: "Test",
            deviceNode: "/dev/disk9s1",
            fileSystemType: "apfs",
            isInternal: false,
            isRemovable: true,
            isDiskImage: true
        )
    }

    var input: URL { URL(fileURLWithPath: "/Volumes/Test") }

    func lock(_ pid: UInt32, role: ProcessRole = .userApplication) -> LockRecord {
        LockRecord(
            pid: pid, processName: "app", user: "me", category: .openFileHandle, role: role,
            path: "/Volumes/Test/f", pathBytes: Data("/Volumes/Test/f".utf8),
            processStart: Date(timeIntervalSince1970: 1)
        )
    }

    func rig(discovery: any LockDiscovering, sleeper: any Sleeping = MockSleeper()) -> CoordinatorRig {
        let resolver = MockMountResolver(mounts: [volume])
        let stages = MockStageRunner()
        let coordinator = DiagnosticCoordinator(
            resolver: resolver, discovery: discovery, stages: stages, reviewer: stages,
            sleeper: sleeper, currentUser: "me"
        )
        return CoordinatorRig(coordinator: coordinator, stages: stages, resolver: resolver)
    }

    func rig(_ result: Result<DiscoveryResult, PhantomTraceError>) -> (CoordinatorRig, MockLockDiscovery) {
        let discovery = MockLockDiscovery(fallback: result)
        return (rig(discovery: discovery), discovery)
    }

    /// Yields to other tasks until `condition` holds. Bounded by iterations, not by time.
    func waitUntil(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<100_000 {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }
}
