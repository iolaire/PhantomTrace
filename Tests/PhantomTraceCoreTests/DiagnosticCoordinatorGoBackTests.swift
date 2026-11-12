import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

/// Go Back in `phantomTrace` (owner decision 2026-11-12, replacing the provisional Req 18.15).
struct DiagnosticCoordinatorGoBackTests {
    private let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )
    private let input = URL(fileURLWithPath: "/Volumes/Test")

    private func lock(_ pid: UInt32) -> LockRecord {
        LockRecord(
            pid: pid, processName: "app", user: "me", category: .openFileHandle, role: .userApplication,
            path: "/Volumes/Test/f", pathBytes: Data("/Volumes/Test/f".utf8),
            processStart: Date(timeIntervalSince1970: 1)
        )
    }

    private struct Harness {
        let coordinator: DiagnosticCoordinator
        let discovery: MockLockDiscovery
        let stages: MockStageRunner
    }
    private func make(_ first: Result<DiscoveryResult, PhantomTraceError>) -> Harness {
        let discovery = MockLockDiscovery(fallback: first)
        let stages = MockStageRunner()
        let coordinator = DiagnosticCoordinator(
            resolver: MockMountResolver(mounts: [volume]), discovery: discovery, stages: stages,
            reviewer: stages, sleeper: MockSleeper(), currentUser: "me"
        )
        return Harness(coordinator: coordinator, discovery: discovery, stages: stages)
    }

    @Test func goBackReturnsToCannotPutAwayWithoutScanningOrActing() async {
        let harness = make(.success(DiscoveryResult(locks: [lock(10)])))
        let coordinator = harness.coordinator
        let discovery = harness.discovery
        let stages = harness.stages
        await coordinator.inspect(input)
        await coordinator.proceed()
        await coordinator.select(.handleMyself)
        var model = await coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.controls.goBackEnabled)
        let scansBefore = discovery.log.calls.count
        await coordinator.goBack()
        model = await coordinator.current
        #expect(model.window == .cannotPutAway)
        #expect(model.ghost == .yellow)
        #expect(model.choice == nil)
        #expect(model.locks.map(\.pid) == [10])
        #expect(model.controls.proceedEnabled)
        #expect(!model.controls.goBackEnabled)
        #expect(discovery.log.calls.count == scansBefore)
        #expect(stages.log.calls.isEmpty)
    }

    @Test func proceedAfterGoBackShowsPhantomTraceAgain() async {
        let coordinator = make(.success(DiscoveryResult(locks: [lock(10)]))).coordinator
        await coordinator.inspect(input)
        await coordinator.proceed()
        await coordinator.goBack()
        await coordinator.proceed()
        let model = await coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.ghost == .red)
    }

    @Test func goBackIsUnavailableAfterAFailedScan() async {
        let coordinator = make(.failure(.lsofTimedOut(seconds: 15))).coordinator
        await coordinator.inspect(input)
        #expect(await coordinator.current.window == .phantomTrace)
        #expect(await coordinator.current.controls.goBackEnabled == false)
        await coordinator.goBack()
        #expect(await coordinator.current.window == .phantomTrace)
    }

    @Test func goBackDoesNothingOutsidePhantomTrace() async {
        let coordinator = make(.success(DiscoveryResult(locks: [lock(10)]))).coordinator
        await coordinator.inspect(input)
        await coordinator.goBack()
        #expect(await coordinator.current.window == .cannotPutAway)
        let clean = make(.success(DiscoveryResult(locks: []))).coordinator
        await clean.inspect(input)
        await clean.goBack()
        #expect(await clean.current.window == .volumeReleased)
    }
}
