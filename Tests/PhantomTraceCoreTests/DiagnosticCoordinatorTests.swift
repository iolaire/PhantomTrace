import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing
struct DiagnosticCoordinatorTests {
    private let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )
    private func lock(_ pid: UInt32, user: String = "me", role: ProcessRole = .userApplication) -> LockRecord {
        LockRecord(
            pid: pid, processName: "app", user: user, category: .openFileHandle, role: role,
            path: "/Volumes/Test/f", pathBytes: Data("/Volumes/Test/f".utf8),
            processStart: Date(timeIntervalSince1970: 1)
        )
    }
    private struct Rig {
        let coordinator: DiagnosticCoordinator
        let discovery: MockLockDiscovery
        let stages: MockStageRunner
        let resolver: MockMountResolver
    }
    private func rig(
        _ first: Result<DiscoveryResult, PhantomTraceError>,
        resolveFailure: PhantomTraceError? = nil
    ) -> Rig {
        let resolver = MockMountResolver(mounts: [volume], failure: resolveFailure)
        let discovery = MockLockDiscovery(fallback: first)
        let stages = MockStageRunner()
        let coordinator = DiagnosticCoordinator(
            resolver: resolver, discovery: discovery, stages: stages, reviewer: stages,
            sleeper: MockSleeper(), currentUser: "me"
        )
        return Rig(coordinator: coordinator, discovery: discovery, stages: stages, resolver: resolver)
    }
    private let input = URL(fileURLWithPath: "/Volumes/Test")
    @Test func firstScanWithLocksShowsCannotPutAwayThenProceedShowsPhantomTrace() async {
        let rig = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        var model = await rig.coordinator.current
        #expect(model.window == .cannotPutAway)
        #expect(model.controls.proceedEnabled)
        await rig.coordinator.proceed()
        model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.ghost == .red)
        #expect(!model.controls.proceedEnabled)  // no choice selected yet
    }
    @Test func rescanThatFindsLocksNeverReturnsToCannotPutAway() async {
        // First scan fails (phantomTrace + banner); the Rescan then finds locks: still phantomTrace.
        let rig = rig(.failure(.lsofTimedOut(seconds: 15)))
        await rig.coordinator.inspect(input)
        var model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.banner != nil)
        #expect(model.controls.rescanEnabled)
        #expect(!model.controls.proceedEnabled)
        #expect(model.controls.enabledStages.isEmpty)
        rig.discovery.script.enqueue(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.rescan()
        model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.banner == nil)
        #expect(model.locks.count == 1)
    }
    @Test func handleMyselfRescansOnlyAndZeroLocksReleasesVolume() async {
        let rig = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        await rig.coordinator.select(.handleMyself)
        rig.discovery.script.enqueue(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.proceed()
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(rig.stages.log.calls.isEmpty)
        #expect(rig.discovery.log.calls.count == 2)
    }
    @Test func disabledStageSelectionIsIgnoredAndOtherUserLocksAreReadOnly() async {
        let other = lock(20, user: "someone")
        let rig = rig(.success(DiscoveryResult(locks: [other])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        await rig.coordinator.select(.letPhantomTraceAct(.gracefulRequest))
        let model = await rig.coordinator.current
        #expect(model.choice == nil)
        #expect(model.controls.enabledStages.isEmpty)
        #expect(model.readOnlyLockIDs == [other.id])
    }
    @Test func busyUnmountReturnsToPhantomTraceWithNewLocks() async {
        let rig = rig(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.inspect(input)
        var model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(model.controls.ejectVisible)
        let fresh = lock(30)
        rig.stages.handoffs.enqueue(.blocked([fresh]))
        await rig.coordinator.eject()
        model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.ghost == .red)
        #expect(model.locks == [fresh])
    }
    @Test func ejectSuccessAndVanishedVolumeHideEject() async {
        let rig = rig(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.inspect(input)
        rig.resolver.setMounts([])
        await rig.coordinator.mountTableChanged()
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(!model.volumeStillMounted)
        #expect(!model.controls.ejectVisible)
    }
    @Test func approvedStageExecutesAndUsesPipelineRescan() async {
        let locked = lock(10, role: .userApplication)
        let rig = rig(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        let action = ProposedAction(kind: .sendSIGTERM, target: locked.identity, reason: "test")
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .gracefulRequest, actions: [action], skipped: [])))
        rig.stages.outcomes.enqueue(.success(StageOutcome(
            stage: .gracefulRequest, succeeded: [action], failed: [], remainingLocks: []
        )))
        await rig.coordinator.select(.letPhantomTraceAct(.gracefulRequest))
        await rig.coordinator.proceed()
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        let stage = ResolutionStage.gracefulRequest
        #expect(rig.stages.log.calls == [.plan(stage), .review(stage), .execute(stage)])
    }
    @Test func refusedReviewExecutesNothingAndResolveFailureShowsNoWindow() async {
        let locked = lock(10)
        let rig = rig(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        let action = ProposedAction(kind: .sendSIGKILL, target: locked.identity, reason: "test")
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .banishLocks, actions: [action], skipped: [])))
        rig.stages.setApproval(false)
        await rig.coordinator.select(.letPhantomTraceAct(.banishLocks))
        await rig.coordinator.proceed()
        #expect(!rig.stages.log.calls.contains(.execute(.banishLocks)))
        let failing = self.rig(.success(DiscoveryResult(locks: [])), resolveFailure: .protectedVolume(input))
        await failing.coordinator.inspect(input)
        let model = await failing.coordinator.current
        #expect(model.window == nil)
        #expect(model.resolveError == .protectedVolume(input))
    }
    @Test func bannerCapsWarningsAtOneHundredAndCountsTheRest() {
        let warnings = (0..<130).map { ParseWarning.invalidPid(offset: $0) }
        let banner = Banner.capped(message: "m", warnings: warnings)
        #expect(banner.warnings.count == 100)
        #expect(banner.omittedWarningCount == 30)
    }
}
