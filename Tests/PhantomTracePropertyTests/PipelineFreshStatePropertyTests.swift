import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Synchronization
import Testing

/// Property 16: Fresh state per stage.
/// **Validates: Requirements 11.1, 11.2**
struct PipelineFreshStatePropertyTests {
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

    @Test func everyStagePlansFromAFreshScanAndReportsLocksFromARescanAfterSettling() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 1...3), Gen.int(in: 0...15_624)
        ) { roundCount, countCode in
            let rounds = Self.rounds(roundCount: roundCount, countCode: countCode)
            let events = EventLog()
            let signals = MockSignalSender()
            let pipeline = Self.pipeline(rounds: rounds, events: events, signals: signals)
            var signalsSeen = 0
            for (index, round) in rounds.enumerated() {
                let plan = try await pipeline.plan(.gracefulRequest, on: Self.volume)
                // The plan is built from this round's start scan, never from an earlier scan or rescan.
                #expect(plan.actions.compactMap(\.target?.pid) == round.planLocks.map(\.pid))
                let outcome = try await pipeline.execute(plan, on: Self.volume)
                // Remaining locks are exactly what the post-stage rescan reported.
                #expect(outcome.remainingLocks == round.rescanLocks)
                #expect(!outcome.rescanTimedOut)
                // Start scan, then settle, then rescan: two scans per stage, rescan after the settle.
                let ordered = events.entries.filter { $0 == "scan" || $0 == "settle" }
                #expect(ordered.count == 3 * (index + 1))
                #expect(Array(ordered.suffix(3)) == ["scan", "settle", "scan"])
                // Only this round's plan targets were signaled.
                let sent = signals.calls.dropFirst(signalsSeen).map(\.pid)
                #expect(sent == round.planLocks.map { Int32($0.pid) })
                signalsSeen = signals.calls.count
            }
        }
    }

    // MARK: - Scenario

    private struct Round {
        let planLocks: [LockRecord]
        let rescanLocks: [LockRecord]
    }

    /// Pids are unique across every scan, so a lock that leaks from another scan is detectable.
    private static func rounds(roundCount: Int, countCode: Int) -> [Round] {
        var nextPID: UInt32 = 100
        var code = countCode
        func locks() -> [LockRecord] {
            let count = code % 5
            code /= 5
            return (0..<count).map { _ in
                defer { nextPID += 1 }
                return lock(nextPID)
            }
        }
        return (0..<roundCount).map { _ in Round(planLocks: locks(), rescanLocks: locks()) }
    }

    private static func start(_ pid: UInt32) -> Date { Date(timeIntervalSince1970: Double(pid)) }

    private static func lock(_ pid: UInt32) -> LockRecord {
        LockRecord(
            pid: pid, processName: "worker", user: "me", category: .openFileHandle, role: .cliTool,
            path: "/Volumes/Throwaway/f\(pid)", pathBytes: Data("/Volumes/Throwaway/f\(pid)".utf8),
            processStart: start(pid)
        )
    }

    private static func details(_ pid: UInt32) -> ProcessDetails {
        ProcessDetails(
            identity: ProcessIdentity(pid: pid, startTime: start(pid)),
            ownerUserID: 501, terminalDevice: nil, processGroupID: 1, foregroundProcessGroupID: nil,
            currentDirectory: nil
        )
    }

    private static func pipeline(rounds: [Round], events: EventLog, signals: MockSignalSender) -> ResolutionPipeline {
        let every = rounds.flatMap { $0.planLocks + $0.rescanLocks }
        let inspector = MockProcessInspector(
            processes: Dictionary(uniqueKeysWithValues: every.map { (Int32($0.pid), details($0.pid)) })
        )
        let history = AttemptHistory()
        let scans = rounds.flatMap { [$0.planLocks, $0.rescanLocks] }
        return ResolutionPipeline(
            discovery: ScriptedDiscovery(scans: scans, events: events),
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: inspector,
            signals: signals,
            quitter: MockAppQuitter(),
            terminal: MockTerminalScripter(),
            unmounter: MockUnmounter(),
            clock: EventClock(events: events)
        )
    }
}

// MARK: - Test doubles (private to this file)

private final class EventLog: Sendable {
    private let storage = Mutex<[String]>([])
    var entries: [String] { storage.withLock { $0 } }
    func record(_ entry: String) { storage.withLock { $0.append(entry) } }
}

/// Returns the next scripted lock list per call, so a stale result can never match by accident.
private final class ScriptedDiscovery: LockDiscovering {
    private let scans: [[LockRecord]]
    private let index = Mutex(0)
    private let events: EventLog

    init(scans: [[LockRecord]], events: EventLog) {
        self.scans = scans
        self.events = events
    }

    func discover(in volume: MountInfo) async throws -> DiscoveryResult {
        events.record("scan")
        let position = index.withLock { value -> Int in
            defer { value += 1 }
            return value
        }
        return DiscoveryResult(locks: position < scans.count ? scans[position] : [])
    }
}

/// Instant clock that logs the post-stage settle. The 30 s scan limit never fires, so scans always win.
private final class EventClock: Sleeping {
    private let inner = MockSleeper()
    private let events: EventLog

    init(events: EventLog) { self.events = events }

    func now() -> Date { inner.now() }

    func sleep(seconds: TimeInterval) async throws {
        if seconds >= 30 {
            try await Task.sleep(for: .seconds(3600))
        }
        if seconds == ResolutionPipeline.settleSeconds { events.record("settle") }
        try await inner.sleep(seconds: seconds)
    }
}
