import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Testing

/// What happens to a process between planning and execution.
private enum IdentityChange: CaseIterable {
    case none, startTimeChanged, exited

    var holdsIdentity: Bool { self == .none }
}

/// Property 13: Identity guard.
/// **Validates: Requirements 6.8, 6.9**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct PipelineIdentityGuardPropertyTests {
    private static let iterations = 500
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
            if seconds >= 30 { try await Task.sleep(for: .seconds(3600)) }
            try await inner.sleep(seconds: seconds)
        }
    }

    private struct Rig {
        let pipeline: ResolutionPipeline
        let signals: MockSignalSender
        let quitter: MockAppQuitter
        let inspector: MockProcessInspector
        let history: AttemptHistory
    }

    private static func pid(_ index: Int) -> UInt32 { UInt32(100 + index) }

    private static func start(_ pid: UInt32) -> Date { Date(timeIntervalSince1970: Double(pid)) }

    private static func identity(_ pid: UInt32) -> ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: start(pid))
    }

    private static func lock(_ pid: UInt32) -> LockRecord {
        LockRecord(
            pid: pid, processName: "worker", user: "me", category: .openFileHandle, role: .cliTool,
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

    private static func rig(count: Int, guiIndexes: Set<Int>) -> Rig {
        let pids = (0..<count).map(pid)
        let history = AttemptHistory()
        let inspector = MockProcessInspector(
            processes: Dictionary(uniqueKeysWithValues: pids.map { (Int32($0), details($0)) })
        )
        let signals = MockSignalSender()
        let quitter = MockAppQuitter(guiPIDs: Set(guiIndexes.map { Int32(pid($0)) }))
        let pipeline = ResolutionPipeline(
            discovery: MockLockDiscovery(fallback: .success(DiscoveryResult(locks: pids.map(lock)))),
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: inspector,
            signals: signals,
            quitter: quitter,
            terminal: MockTerminalScripter(),
            unmounter: MockUnmounter(),
            clock: TestClock()
        )
        return Rig(pipeline: pipeline, signals: signals, quitter: quitter, inspector: inspector, history: history)
    }

    private static func apply(_ changes: [IdentityChange], to inspector: MockProcessInspector) {
        for (index, change) in changes.enumerated() {
            let pid = Self.pid(index)
            switch change {
            case .none:
                break
            case .startTimeChanged:
                inspector.setDetails(details(pid, startOffset: 1 + Double(index)), forPID: Int32(pid))
            case .exited:
                inspector.setDetails(nil, forPID: Int32(pid))
            }
        }
    }

    private static func quitPIDs(_ quitter: MockAppQuitter) -> [UInt32] {
        quitter.calls.compactMap { call in
            if case .requestQuit(let pid) = call { return UInt32(pid) }
            return nil
        }
    }

    @Test func gracefulRequestOnlyReachesProcessesWhoseIdentityStillMatches() async {
        await propertyCheck(
            count: Self.iterations, input: scenarioGenerator
        ) { scenario in
            let rig = Self.rig(count: scenario.changes.count, guiIndexes: scenario.guiIndexes)
            let plan = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
            Self.apply(scenario.changes, to: rig.inspector)
            let outcome = try await rig.pipeline.execute(plan, on: Self.volume)

            let intact = Set(scenario.changes.indices.filter { scenario.changes[$0].holdsIdentity }.map(Self.pid))
            let changed = Set(scenario.changes.indices.filter { !scenario.changes[$0].holdsIdentity }.map(Self.pid))
            let reached = rig.signals.calls.map { UInt32($0.pid) } + Self.quitPIDs(rig.quitter)

            // Nothing is signalled or asked to quit unless the identity matched, and every match is reached once.
            #expect(reached.sorted() == intact.sorted())
            // Each mismatch is skipped with processIdentityChanged and nothing else.
            let identityErrors = outcome.failed.compactMap { failure -> UInt32? in
                if case .processIdentityChanged(let pid) = failure.error { return pid }
                return nil
            }
            #expect(Set(identityErrors) == changed)
            #expect(identityErrors.count == changed.count)
            // A skipped process is not recorded as having had a graceful attempt.
            for pid in changed {
                #expect(await rig.history.hasGracefulAttempt(for: Self.identity(pid)) == false)
            }
        }
    }

    @Test func banishNeverKillsAProcessWhoseIdentityChangedSinceDiscovery() async {
        await propertyCheck(
            count: Self.iterations, input: scenarioGenerator
        ) { scenario in
            let rig = Self.rig(count: scenario.changes.count, guiIndexes: [])
            let graceful = try await rig.pipeline.plan(.gracefulRequest, on: Self.volume)
            _ = try await rig.pipeline.execute(graceful, on: Self.volume)
            let banish = try await rig.pipeline.plan(.banishLocks, on: Self.volume)
            Self.apply(scenario.changes, to: rig.inspector)
            let outcome = try await rig.pipeline.execute(banish, on: Self.volume)

            let intact = scenario.changes.indices.filter { scenario.changes[$0].holdsIdentity }.map(Self.pid)
            let changed = scenario.changes.indices.filter { !scenario.changes[$0].holdsIdentity }.map(Self.pid)
            let killed = rig.signals.calls.filter { $0.signal == .kill }.map { UInt32($0.pid) }

            #expect(killed.sorted() == intact.sorted())
            let skipped = outcome.failed.compactMap { failure -> UInt32? in
                if case .processIdentityChanged(let pid) = failure.error { return pid }
                return nil
            }
            #expect(skipped.sorted() == changed.sorted())
        }
    }
}

// MARK: - Generators

/// One lock per entry; each entry says what happens to its process after planning and whether it is a GUI app.
private struct IdentityScenario: Sendable {
    let changes: [IdentityChange]
    let guiIndexes: Set<Int>
}

private var scenarioGenerator: Generator<IdentityScenario, some SendableSequenceType> {
    zip(Gen.int(in: 0...2), Gen.bool()).array(of: 1...6).map { entries in
        IdentityScenario(
            changes: entries.map { IdentityChange.allCases[$0.0] },
            guiIndexes: Set(entries.indices.filter { entries[$0].1 })
        )
    }
}
