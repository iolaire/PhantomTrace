import Foundation
import PhantomTraceTestSupport
import Synchronization
import Testing
@testable import PhantomTraceCore

/// Stage execution against mock systems. Requirements 8.5, 8.7, 9.3 to 9.6, 11.1 to 11.4, 14.3.
@Suite(.timeLimit(.minutes(1)))struct ResolutionPipelineTests {
    private static let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Throwaway"),
        volumeName: "Throwaway",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    /// Instant sleeps, except the 30 s scan limit, which never fires so the scan always wins.
    private final class TestClock: Sleeping {
        let inner = MockSleeper()
        func now() -> Date { inner.now() }
        func sleep(seconds: TimeInterval) async throws {
            if seconds >= TimedScanner.timeoutSeconds {
                try await Task.sleep(for: .seconds(3600))
            }
            try await inner.sleep(seconds: seconds)
        }
        var sleeps: [TimeInterval] { inner.calls }
    }

    private static func start(_ pid: UInt32) -> Date { Date(timeIntervalSince1970: Double(pid)) }

    private static func lock(_ pid: UInt32, name: String = "worker") -> LockRecord {
        LockRecord(
            pid: pid, processName: name, user: "me", category: .openFileHandle, role: .cliTool,
            path: "/Volumes/Throwaway/f\(pid)", pathBytes: Data("/Volumes/Throwaway/f\(pid)".utf8),
            processStart: start(pid)
        )
    }

    private static func details(_ pid: UInt32, startOffset: Double = 0) -> ProcessDetails {
        ProcessDetails(
            identity: ProcessIdentity(pid: pid, startTime: start(pid).addingTimeInterval(startOffset)),
            ownerUserID: 501, terminalDevice: nil, processGroupID: 1, foregroundProcessGroupID: nil,
            currentDirectory: nil
        )
    }

    private struct Rig {
        let pipeline: ResolutionPipeline
        let discovery: MockLockDiscovery
        let signals: MockSignalSender
        let quitter: MockAppQuitter
        let inspector: MockProcessInspector
        let clock: TestClock
        let history: AttemptHistory
    }

    private func rig(
        locks: [LockRecord],
        gui: Set<Int32> = [],
        quitResult: Bool = true,
        signalError: PhantomTraceError? = nil
    ) -> Rig {
        let history = AttemptHistory()
        let inspector = MockProcessInspector(
            processes: Dictionary(uniqueKeysWithValues: locks.map { (Int32($0.pid), Self.details($0.pid)) })
        )
        let discovery = MockLockDiscovery(fallback: .success(DiscoveryResult(locks: locks)))
        let signals = MockSignalSender(fallback: signalError)
        let quitter = MockAppQuitter(guiPIDs: gui, quitFallback: quitResult)
        let clock = TestClock()
        let pipeline = ResolutionPipeline(
            discovery: discovery,
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: inspector,
            signals: signals,
            quitter: quitter,
            terminal: MockTerminalScripter(),
            unmounter: MockUnmounter(),
            clock: clock
        )
        return Rig(
            pipeline: pipeline, discovery: discovery, signals: signals, quitter: quitter,
            inspector: inspector, clock: clock, history: history
        )
    }

    @Test func sigtermIsRecordedAsGracefulAttemptEvenWhenDeliveryFails() async throws {
        let rig = rig(locks: [Self.lock(10)], signalError: .permissionDenied(pid: 10))
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(outcome.succeeded.isEmpty)
        #expect(outcome.failed.map(\.error) == [.permissionDenied(pid: 10)])
        let identity = ProcessIdentity(pid: 10, startTime: Self.start(10))
        #expect(await rig.history.hasGracefulAttempt(for: identity))
    }

    @Test func permissionDeniedOnOnePidDoesNotStopTheNext() async throws {
        let rig = rig(locks: [Self.lock(10), Self.lock(11)])
        rig.signals.script.enqueue(.permissionDenied(pid: 10))
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(rig.signals.calls.map(\.pid) == [10, 11])
        #expect(outcome.succeeded.compactMap(\.target?.pid) == [11])
    }

    @Test func guiApplicationsAreAskedToQuitAndRecorded() async throws {
        let rig = rig(locks: [Self.lock(20)], gui: [20], quitResult: false)
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(rig.quitter.calls.contains(.requestQuit(pid: 20)))
        #expect(rig.signals.calls.isEmpty)
        #expect(outcome.failed.count == 1)
        #expect(await rig.history.hasGracefulAttempt(for: ProcessIdentity(pid: 20, startTime: Self.start(20))))
    }

    @Test func changedIdentityIsSkippedWithoutSignalAndRunContinues() async throws {
        let rig = rig(locks: [Self.lock(10), Self.lock(11)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        rig.inspector.setDetails(Self.details(10, startOffset: 99), forPID: 10)
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(outcome.failed.map(\.error) == [.processIdentityChanged(pid: 10)])
        #expect(rig.signals.calls.map(\.pid) == [11])
    }

    @Test func banishKillsOnlyAfterGracefulAttempt() async throws {
        let rig = rig(locks: [Self.lock(10)])
        let refused = try await rig.pipeline.plan(.banishLocks, on: Self.volume)
        #expect(refused.actions.isEmpty)
        let graceful = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        _ = try await rig.pipeline.execute(graceful, on: Self.volume)
        let banish = try await rig.pipeline.plan(.banishLocks, on: Self.volume)
        #expect(banish.actions.map(\.kind) == [.sendSIGKILL])
        _ = try await rig.pipeline.execute(banish, on: Self.volume)
        #expect(rig.signals.calls.map(\.signal) == [.terminate, .kill])
    }

    @Test func banishSkipsTargetWhoseNameChangedBeforeConfirmation() async throws {
        let rig = rig(locks: [Self.lock(10, name: "worker")])
        let graceful = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        _ = try await rig.pipeline.execute(graceful, on: Self.volume)
        let banish = try await rig.pipeline.plan(.banishLocks, on: Self.volume)
        let renamed = ProcessDetails(
            identity: Self.details(10).identity, ownerUserID: 501, terminalDevice: nil, processGroupID: 1,
            foregroundProcessGroupID: nil, currentDirectory: nil,
            executablePath: URL(fileURLWithPath: "/usr/bin/other")
        )
        rig.inspector.setDetails(renamed, forPID: 10)
        let outcome = try await rig.pipeline.execute(banish, on: Self.volume)
        #expect(outcome.failed.map(\.error) == [.processIdentityChanged(pid: 10)])
        #expect(rig.signals.calls.map(\.signal) == [.terminate])
    }

    @Test func actionsNotInTheLastPlanAreNeverRun() async throws {
        let rig = rig(locks: [Self.lock(10)])
        let forged = ResolutionPlan(
            stage: .banishLocks,
            actions: [ProposedAction(
                kind: .sendSIGKILL, target: ProcessIdentity(pid: 10, startTime: Self.start(10)), reason: "x"
            )],
            skipped: []
        )
        _ = try await rig.pipeline.execute(forged, on: Self.volume)
        #expect(rig.signals.calls.isEmpty)
    }

    @Test func settlesThenRescansAndReportsRemainingLocks() async throws {
        let rig = rig(locks: [Self.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(rig.clock.sleeps.contains(ResolutionPipeline.settleSeconds))
        #expect(rig.discovery.log.calls.count == 2)
        #expect(outcome.remainingLocks.map(\.pid) == [10])
        #expect(!outcome.rescanTimedOut)
    }

    @Test func rescanTimeoutIsReportedWithoutVerifiedLocks() async throws {
        let rig = rig(locks: [Self.lock(10)])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        rig.discovery.script.setFallback(.failure(.lsofTimedOut(seconds: 30)))
        let outcome = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(outcome.rescanTimedOut)
        #expect(outcome.remainingLocks.isEmpty)
    }

    @Test func failedStartScanThrowsAndYieldsNoPlan() async {
        let rig = rig(locks: [Self.lock(10)])
        rig.discovery.script.setFallback(.failure(.lsofUnavailable))
        await #expect(throws: PhantomTraceError.lsofUnavailable) {
            try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        }
        #expect(rig.signals.calls.isEmpty)
    }

    @Test func graceWaitIsSkippedWhenThereAreNoActions() async throws {
        let rig = rig(locks: [])
        let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
        _ = try await rig.pipeline.execute(plan, on: Self.volume)
        #expect(rig.clock.sleeps == [ResolutionPipeline.settleSeconds])
    }
}
