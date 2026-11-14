import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// The pipeline asks `SafetyPolicy` again right before sending (Requirement 6.7), and measures how long
/// it took to gather the facts it gives the policy (Requirement 6.6).
@Suite(.timeLimit(.minutes(1)))
struct ResolutionPipelineSafetyRecheckTests {
    private typealias Fixtures = PipelineFixtures

    @Test func killIsRefusedWhenTheGracefulAttemptIsGoneAtSendTime() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(100)])
        await rig.history.recordGracefulAttempt(for: Fixtures.identity(100))
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume, confirmedDaemons: [])
        #expect(plan.actions.map(\.kind) == [.sendSIGKILL])

        await rig.history.reset()
        let outcome = try await rig.pipeline.execute(plan, on: Fixtures.volume)

        #expect(rig.signals.calls.isEmpty)
        #expect(outcome.succeeded.isEmpty)
        #expect(outcome.failed.map(\.error) == [.safetyDenied(.noPriorGracefulAttempt)])
    }

    @Test func approvedActionStillRunsWhenTheRecheckAllowsIt() async throws {
        let rig = Fixtures.rig(locks: [Fixtures.lock(100)])
        await rig.history.recordGracefulAttempt(for: Fixtures.identity(100))
        let plan = try await rig.pipeline.plan(.banishLocks, on: Fixtures.volume, confirmedDaemons: [])
        let outcome = try await rig.pipeline.execute(plan, on: Fixtures.volume)

        #expect(rig.signals.calls.map(\.pid) == [100])
        #expect(outcome.failed.isEmpty)
    }

    /// Wraps the mock inspector and moves the injected clock forward on every lookup.
    private final class SlowInspector: ProcessInspecting {
        let inner: MockProcessInspector
        let clock: PipelineTestClock
        let seconds: TimeInterval
        init(inner: MockProcessInspector, clock: PipelineTestClock, seconds: TimeInterval) {
            self.inner = inner
            self.clock = clock
            self.seconds = seconds
        }
        var currentProcessID: Int32 { inner.currentProcessID }
        var currentUserID: UInt32 { inner.currentUserID }
        func inspect(pid: Int32) -> ProcessDetails? {
            clock.inner.advance(by: seconds)
            return inner.inspect(pid: pid)
        }
    }

    private func slowPipeline(lookupSeconds: TimeInterval) -> (ResolutionPipeline, MockSignalSender) {
        let history = AttemptHistory()
        let clock = PipelineTestClock()
        let signals = MockSignalSender()
        let inner = MockProcessInspector(processes: [100: Fixtures.details(100)])
        let pipeline = ResolutionPipeline(
            discovery: MockLockDiscovery(fallback: .success(DiscoveryResult(locks: [Fixtures.lock(100)]))),
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: SlowInspector(inner: inner, clock: clock, seconds: lookupSeconds),
            signals: signals,
            quitter: MockAppQuitter(),
            terminal: MockTerminalScripter(),
            unmounter: MockUnmounter(),
            clock: clock
        )
        return (pipeline, signals)
    }

    @Test func slowFactGatheringDeniesTheActionAsUndeterminable() async throws {
        let (pipeline, _) = slowPipeline(lookupSeconds: 1.5)
        let plan = try await pipeline.plan(.gracefulRequest, on: Fixtures.volume, confirmedDaemons: [])
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.map(\.denial) == [.undeterminableState])
    }

    @Test func fastFactGatheringKeepsTheAction() async throws {
        let (pipeline, _) = slowPipeline(lookupSeconds: 0.1)
        let plan = try await pipeline.plan(.gracefulRequest, on: Fixtures.volume, confirmedDaemons: [])
        #expect(plan.actions.map(\.kind) == [.sendSIGTERM])
    }
}
