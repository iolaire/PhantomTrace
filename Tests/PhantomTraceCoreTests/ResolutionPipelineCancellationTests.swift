import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Cancellation and volume binding in the pipeline. Requirements 6.7, 11.1, 11.3.
@Suite(.timeLimit(.minutes(1)))
struct ResolutionPipelineCancellationTests {
    private typealias Fixtures = PipelineFixtures

    /// A discovery that only ends when its task is cancelled.
    private struct HangingDiscovery: LockDiscovering {
        func discover(in volume: MountInfo) async throws -> DiscoveryResult {
            try await Task.sleep(for: .seconds(3600))
            return DiscoveryResult(locks: [])
        }
    }

    @Test func cancelledStageSendsNoSignal() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        #expect(!plan.actions.isEmpty)
        let pipeline = rig.pipeline
        let volume = Fixtures.volume
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await pipeline.execute(plan, on: volume)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(rig.signals.calls.isEmpty)
        #expect(!rig.quitter.calls.contains(.requestQuit(pid: 10)))
    }

    @Test func cancelledGraceWaitEndsTheStageWithoutRescanning() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        rig.clock.inner.failSleeps(with: CancellationError())
        let scansBefore = rig.discovery.log.calls.count
        await #expect(throws: CancellationError.self) {
            try await rig.pipeline.execute(plan, on: Fixtures.volume)
        }
        #expect(rig.discovery.log.calls.count == scansBefore)
    }

    @Test func approvalDoesNotCarryOverToAnotherVolume() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        let other = MountInfo(
            mountPoint: URL(fileURLWithPath: "/Volumes/Other"),
            volumeName: "Other",
            deviceNode: "/dev/disk8s1",
            fileSystemType: "apfs",
            isInternal: false,
            isRemovable: true,
            isDiskImage: true
        )
        let outcome = try await rig.pipeline.execute(plan, on: other)
        #expect(outcome.succeeded.isEmpty)
        #expect(rig.signals.calls.isEmpty)
    }

    @Test func timedScannerReportsCancellationInsteadOfLsofUnavailable() async {
        let scanner = TimedScanner(discovery: HangingDiscovery(), clock: PipelineTestClock())
        let task = Task { await scanner.scan(Fixtures.volume) }
        task.cancel()
        let result = await task.value
        #expect(result == .failure(.cancelled))
    }
}
