import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct DiagnosticCoordinatorScenarioTests: CoordinatorScenario {

    /// Runs the stage flow to completion and returns the resulting model.
    private func runGracefulStage(
        _ rig: CoordinatorRig,
        locked: LockRecord,
        outcome: StageOutcome
    ) async -> WindowModel {
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        let action = ProposedAction(kind: .sendSIGTERM, target: locked.identity, reason: "test")
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .gracefulRequest, actions: [action], skipped: [])))
        rig.stages.outcomes.enqueue(.success(outcome))
        await rig.coordinator.select(.letPhantomTraceAct(.gracefulRequest))
        await rig.coordinator.proceed()
        return await rig.coordinator.current
    }

    private func failedActions(_ count: Int, locked: LockRecord) -> [FailedAction] {
        (0..<count).map { index in
            FailedAction(
                action: ProposedAction(kind: .sendSIGTERM, target: locked.identity, reason: "r"),
                error: .permissionDenied(pid: UInt32(index + 1))
            )
        }
    }

    // MARK: - Scanning overlay (Requirement 18.7)

    @Test func firstScanOverlayAppearsOnlyAfterHalfASecondDelay() async {
        #expect(DiagnosticCoordinator.firstScanOverlayDelaySeconds == 0.5)
        let sleeper = MockSleeper()
        let discovery = GatedDiscovery(result: .success(DiscoveryResult(locks: [lock(10)])), gated: true)
        let rig = rig(discovery: discovery, sleeper: sleeper)
        let scan = Task { await rig.coordinator.inspect(input) }
        let shown = await waitUntil { await rig.coordinator.current.isScanning }
        #expect(shown)
        #expect(sleeper.calls == [0.5])
        discovery.open()
        await scan.value
        let model = await rig.coordinator.current
        #expect(!model.isScanning)
        #expect(model.window == .cannotPutAway)
    }

    @Test func fastFirstScanNeverShowsTheOverlay() async {
        let sleeper = HeldSleeper()
        let discovery = MockLockDiscovery(fallback: .success(DiscoveryResult(locks: [lock(10)])))
        let rig = rig(discovery: discovery, sleeper: sleeper)
        await rig.coordinator.inspect(input)
        sleeper.open()  // the delay ends after the scan: it must not bring the overlay back
        for _ in 0..<200 { await Task.yield() }
        let model = await rig.coordinator.current
        #expect(sleeper.log.calls == [0.5])
        #expect(!model.isScanning)
        #expect(model.window == .cannotPutAway)
    }

    @Test func rescanShowsOverlayAtOnceAndKeepsTheWindow() async {
        let discovery = GatedDiscovery(result: .success(DiscoveryResult(locks: [lock(10)])), gated: false)
        let sleeper = HeldSleeper()
        let rig = rig(discovery: discovery, sleeper: sleeper)
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        discovery.setGated(true)
        await rig.coordinator.select(.handleMyself)
        let scan = Task { await rig.coordinator.proceed() }
        let shown = await waitUntil { await rig.coordinator.current.isScanning }
        #expect(shown)
        let during = await rig.coordinator.current
        #expect(during.window == .phantomTrace)
        #expect(during.ghost == .red)
        #expect(!during.controls.proceedEnabled)
        #expect(sleeper.log.calls == [0.5])  // only the first scan used the delay
        discovery.open()
        await scan.value
        #expect(await !rig.coordinator.current.isScanning)
    }

    // MARK: - Failed scans and partial results (Requirements 14.1, 18.26)

    @Test func failedFirstScanShowsBannerAndDisablesEveryControlButRescan() async {
        let (rig, _) = rig(.failure(.lsofTimedOut(seconds: 15)))
        await rig.coordinator.inspect(input)
        let model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.banner?.message.contains("15 seconds") == true)
        #expect(model.controls.rescanEnabled)
        #expect(!model.controls.proceedEnabled)
        #expect(!model.controls.handleMyselfEnabled)
        #expect(model.controls.enabledStages.isEmpty)
        await rig.coordinator.select(.handleMyself)
        #expect(await rig.coordinator.current.choice == nil)
        #expect(rig.stages.log.calls.isEmpty)
    }

    @Test func partialResultShowsOneHundredWarningsAndCountsTheOmittedOnes() async {
        let warnings = (0..<130).map { ParseWarning.invalidPid(offset: $0) }
        let (rig, _) = rig(.success(DiscoveryResult(locks: [lock(10)], partial: true, warnings: warnings)))
        await rig.coordinator.inspect(input)
        let model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.banner?.warnings == Array(warnings.prefix(100)))
        #expect(model.banner?.omittedWarningCount == 30)
        #expect(model.controls.rescanEnabled)
        #expect(!model.controls.proceedEnabled)
    }

    @Test func rescanClearsTheBannerAndItsWarnings() async {
        let warnings = (0..<5).map { ParseWarning.invalidPid(offset: $0) }
        let (rig, discovery) = rig(.success(DiscoveryResult(locks: [lock(10)], partial: true, warnings: warnings)))
        await rig.coordinator.inspect(input)
        discovery.script.enqueue(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.rescan()
        let model = await rig.coordinator.current
        #expect(model.banner == nil)
        #expect(model.window == .phantomTrace)
        #expect(model.controls.handleMyselfEnabled)
    }

    // MARK: - Failed actions (Requirement 14.5)

    @Test func failedActionsAreCappedAtFiveHundredWithAnOmittedCount() async {
        let locked = lock(10)
        let failed = failedActions(530, locked: locked)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runGracefulStage(rig, locked: locked, outcome: StageOutcome(
            stage: .gracefulRequest, succeeded: [], failed: failed, remainingLocks: [locked]
        ))
        #expect(model.failedActions.entries.count == 500)
        #expect(model.failedActions.entries == Array(failed.prefix(500)))
        #expect(model.failedActions.omittedCount == 30)
        #expect(model.window == .phantomTrace)
    }

    @Test func exactlyFiveHundredFailedActionsOmitNothing() async {
        let locked = lock(10)
        let failed = failedActions(500, locked: locked)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runGracefulStage(rig, locked: locked, outcome: StageOutcome(
            stage: .gracefulRequest, succeeded: [], failed: failed, remainingLocks: [locked]
        ))
        #expect(model.failedActions.entries.count == 500)
        #expect(model.failedActions.omittedCount == 0)
    }

    @Test func newRunClearsTheFailedActionsOfTheLastStage() async {
        let locked = lock(10)
        let (rig, discovery) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runGracefulStage(rig, locked: locked, outcome: StageOutcome(
            stage: .gracefulRequest, succeeded: [], failed: failedActions(3, locked: locked),
            remainingLocks: [locked]
        ))
        #expect(model.failedActions.entries.count == 3)
        discovery.script.enqueue(.failure(.lsofUnavailable))
        await rig.coordinator.rescan()
        #expect(await rig.coordinator.current.failedActions == FailedActionList())
    }

    // MARK: - Stage failures and refusals

    @Test func planFailureShowsBannerAndExecutesNothing() async {
        let locked = lock(10)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        rig.stages.plans.enqueue(.failure(.lsofTimedOut(seconds: 30)))
        await rig.coordinator.select(.letPhantomTraceAct(.gracefulRequest))
        await rig.coordinator.proceed()
        let model = await rig.coordinator.current
        #expect(rig.stages.log.calls == [.plan(.gracefulRequest)])
        #expect(model.window == .phantomTrace)
        #expect(model.banner != nil)
        #expect(!model.isStageRunning)
        #expect(!model.controls.proceedEnabled)
    }

    @Test func rescanTimeoutAfterAStageIsReportedAsFailureNotVerified() async {
        let locked = lock(10)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runGracefulStage(rig, locked: locked, outcome: StageOutcome(
            stage: .gracefulRequest, succeeded: [], failed: [], remainingLocks: [], rescanTimedOut: true
        ))
        #expect(model.window == .phantomTrace)
        #expect(model.banner != nil)
        #expect(model.locks.isEmpty)
        #expect(model.controls.rescanEnabled)
    }

    @Test func refusedReviewRescansWithoutExecutingOrSignalling() async {
        let locked = lock(10)
        let (rig, discovery) = rig(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        let action = ProposedAction(kind: .sendSIGKILL, target: locked.identity, reason: "test")
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .banishLocks, actions: [action], skipped: [])))
        rig.stages.setApproval(false)
        await rig.coordinator.select(.letPhantomTraceAct(.banishLocks))
        await rig.coordinator.proceed()
        let model = await rig.coordinator.current
        #expect(rig.stages.log.calls == [.plan(.banishLocks), .review(.banishLocks)])
        #expect(discovery.log.calls.count == 2)
        #expect(model.window == .phantomTrace)
        #expect(!model.isStageRunning)
    }

    @Test func emptyPlanIsNeverReviewedOrExecuted() async {
        let locked = lock(10)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .gracefulRequest, actions: [], skipped: [])))
        await rig.coordinator.select(.letPhantomTraceAct(.gracefulRequest))
        await rig.coordinator.proceed()
        #expect(rig.stages.log.calls == [.plan(.gracefulRequest)])
    }
}
