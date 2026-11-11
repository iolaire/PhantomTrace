import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Grace period bounds, zero-action stages and Banish Locks gating. Requirements 8.4, 8.5, 9.2, 9.5, 11.4.
struct ResolutionPipelineGraceTests {
    private typealias Fixtures = PipelineFixtures

    private func gracefulRun(
        graceSeconds: TimeInterval,
        signalError: PhantomTraceError? = nil
    ) async throws -> Fixtures.Rig {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)], signalError: signalError, graceSeconds: graceSeconds)
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        return rig
    }

    // MARK: - Grace period bounds

    @Test(arguments: [
        (0.0, 4), (0.1, 4), (-5.0, 4), (1.0, 4), (5.0, 20), (60.0, 240), (1000.0, 240)
    ])
    func gracePeriodIsClampedToOneThroughSixtySeconds(requested: Double, expectedPolls: Int) async throws {
        let rig = try await gracefulRun(graceSeconds: requested)
        #expect(rig.clock.gracePolls == expectedPolls)
    }

    @Test func defaultGraceIsFiveSeconds() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(Double(rig.clock.gracePolls) * ResolutionPipeline.gracePollSeconds == 5)
    }

    @Test func graceEndsEarlyOnceEveryTargetHasExited() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let inspector = rig.inspector
        let clock = rig.clock
        clock.onSleep { _ in
            if clock.gracePolls >= 2 { inspector.setDetails(nil, forPID: 10) }
        }
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(clock.gracePolls == 2)
    }

    @Test func graceKeepsWaitingWhenPidIsReusedByAnotherProcess() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)], graceSeconds: 1)
        let reused = ProcessDetails(
            identity: ProcessIdentity(pid: 10, startTime: Fixtures.start(10).addingTimeInterval(500)),
            ownerUserID: 501, terminalDevice: nil, processGroupID: 1, foregroundProcessGroupID: nil,
            currentDirectory: nil
        )
        let inspector = rig.inspector
        let clock = rig.clock
        clock.onSleep { _ in
            if clock.gracePolls >= 1 { inspector.setDetails(reused, forPID: 10) }
        }
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        // A different identity under the same pid counts as exited, so the wait stops after one poll.
        #expect(clock.gracePolls == 1)
    }

    @Test func noGraceWaitWhenNothingWasDelivered() async throws {
        let rig = try await gracefulRun(graceSeconds: 60, signalError: .permissionDenied(pid: 10))
        #expect(rig.clock.gracePolls == 0)
        #expect(rig.clock.sleeps == [ResolutionPipeline.settleSeconds])
    }

    // MARK: - Zero-action stages

    @Test(arguments: [ResolutionStage.egressShells, .gracefulRequest, .banishLocks])
    func stageWithNothingToDoSendsNothingAndStillRescans(stage: ResolutionStage) async throws {
        let rig = Fixtures.rig(locks: [])
        let plan = try await rig.pipeline.plan(stage, on: Fixtures.volume)
        #expect(plan.actions.isEmpty)
        let outcome = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(outcome.succeeded.isEmpty && outcome.failed.isEmpty && outcome.remainingLocks.isEmpty)
        #expect(!outcome.rescanTimedOut)
        #expect(rig.signals.calls.isEmpty && rig.quitter.calls.isEmpty && rig.terminal.calls.isEmpty)
        #expect(rig.discovery.log.calls.count == 2)
        #expect(rig.clock.sleeps == [ResolutionPipeline.settleSeconds])
    }

    @Test func cleanHandoffPlanHasNoActionsAndNeedsNoScan() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.cleanHandoff, on: Fixtures.volume)
        #expect(plan.actions.isEmpty && plan.skipped.isEmpty)
        #expect(rig.discovery.log.calls.isEmpty)
    }

    // MARK: - Banish Locks gating

    @Test func banishWithoutPriorGracefulAttemptIsRefusedAndNothingIsKilled() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume)
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.map(\.denial) == [.noPriorGracefulAttempt])
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(rig.signals.calls.isEmpty)
    }

    @Test func banishTargetsOnlyPidsThatWereGivenAGracefulAttempt() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10), Fixtures.lock(11)])
        await rig.history.recordGracefulAttempt(for: Fixtures.identity(10))
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume)
        #expect(plan.actions.compactMap(\.target?.pid) == [10])
        #expect(plan.skipped.map(\.denial) == [.noPriorGracefulAttempt])
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(rig.signals.calls.map(\.signal) == [.kill])
        #expect(rig.signals.calls.map(\.pid) == [10])
    }

    @Test func gracefulAttemptOnAnEarlierIncarnationOfThePidDoesNotCount() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let earlier = ProcessIdentity(pid: 10, startTime: Fixtures.start(10).addingTimeInterval(-60))
        await rig.history.recordGracefulAttempt(for: earlier)
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume)
        #expect(plan.actions.isEmpty)
    }

    @Test func unconfirmedSystemDaemonIsNeverKilledWithoutAGracefulAttempt() async throws {
        let daemon = Fixtures.lock(30, name: "mdworker", role: .systemDaemon)
        let rig = Fixtures.rig(locks: [daemon])
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume)
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.map(\.denial) == [.noPriorGracefulAttempt])
    }

    @Test func approvalIsSingleUseSoReplayingAPlanSendsNothing() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        await rig.history.recordGracefulAttempt(for: Fixtures.identity(10))
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        _ = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(rig.signals.calls.count == 1)
    }

    // MARK: - Rescan

    @Test func partialRescanIsReportedAsTimedOutWithoutLocks() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Fixtures.volume)
        rig.discovery.script.setFallback(.success(DiscoveryResult(locks: [Fixtures.lock(10)], partial: true)))
        let outcome = try await rig.pipeline.execute(plan, on: Fixtures.volume)
        #expect(outcome.rescanTimedOut)
        #expect(outcome.remainingLocks.isEmpty)
    }
}
