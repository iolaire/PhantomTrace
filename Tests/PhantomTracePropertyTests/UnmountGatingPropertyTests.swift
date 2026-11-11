import Foundation
import PhantomTraceTestSupport
import PropertyBased
import Synchronization
import Testing
@testable import PhantomTraceCore

/// Property 15: Unmount gating.
///
/// Drives `ResolutionPipeline.cleanHandoff` (which delegates to `CleanHandoffPerformer`) with scripted
/// discovery and a recording unmounter. No real volume, process, or clock is involved.
struct UnmountGatingPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 10.1, 10.2, 10.3**
    @Test func unmountIsAttemptedOnlyAfterAFreshCleanScan() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator()) { scenario in
            let rig = Rig(scenario)
            let result = await rig.pipeline.cleanHandoff(on: gatingMount, force: scenario.force)
            #expect(rig.events.calls == scenario.expectedEvents, "\(scenario)")
            #expect(result == scenario.expectedResult, "\(scenario)")
        }
    }

    /// **Validates: Requirements 10.1, 10.2**
    @Test func everyHandoffScansAfreshAndNeverReusesAnEarlierScan() async {
        // Timeouts need the clock to fire, which would race every other scan, so they are covered above.
        let noTimeout = scanKindGenerator().map { $0 == .timeout ? ScanKind.failure : $0 }
        let input = zip(noTimeout, noTimeout)
        await propertyCheck(count: Self.iterations, input: input) { first, second in
            let rig = Rig(Scenario(scan: first, unmount: .succeeds, rescan: .clean, force: false), extraScans: [second])
            _ = await rig.pipeline.cleanHandoff(on: gatingMount, force: false)
            _ = await rig.pipeline.cleanHandoff(on: gatingMount, force: false)
            let unmounts = rig.events.calls.filter { $0.hasPrefix("unmount") }.count
            let expected = [first, second].filter { $0 == .clean }.count
            #expect(unmounts == expected, "first=\(first) second=\(second) events=\(rig.events.calls)")
            #expect(rig.events.calls.filter { $0 == "scan" }.count == 2)
        }
    }
}

// MARK: - Scenario model

private enum ScanKind: Equatable, Sendable {
    case clean
    case locks(Int)
    case partialClean
    case partialLocks(Int)
    case failure
    case timeout
}

private enum UnmountKind: Equatable, Sendable {
    case succeeds
    case busy
    case fails
}

private enum RescanKind: Equatable, Sendable {
    case clean
    case locks(Int)
    case failure
}

private struct Scenario: CustomStringConvertible, Sendable {
    let scan: ScanKind
    let unmount: UnmountKind
    let rescan: RescanKind
    let force: Bool

    var description: String { "scan=\(scan) unmount=\(unmount) rescan=\(rescan) force=\(force)" }

    private var unmountEvent: String { "unmount(force: \(force))" }

    var expectedEvents: [String] {
        guard scan == .clean else { return ["scan"] }
        return unmount == .busy ? ["scan", unmountEvent, "scan"] : ["scan", unmountEvent]
    }

    var expectedResult: CleanHandoffResult {
        switch scan {
        case .locks(let count):
            return .blocked(makeLocks(count))
        case .partialClean, .partialLocks, .failure:
            return .failed(.lsofUnavailable)
        case .timeout:
            return .failed(.lsofTimedOut(seconds: CleanHandoffPerformer.scanTimeoutSeconds))
        case .clean:
            return unmountResult
        }
    }

    private var unmountResult: CleanHandoffResult {
        switch unmount {
        case .succeeds: return .unmounted
        case .fails: return .failed(.unmountFailed(code: 5))
        case .busy:
            switch rescan {
            case .clean: return .blocked([])
            case .locks(let count): return .blocked(makeLocks(count))
            case .failure: return .failed(.lsofUnavailable)
            }
        }
    }
}

// MARK: - Generators

private func scanKindGenerator() -> Generator<ScanKind, some SendableSequenceType> {
    zip(Gen.int(in: 0...5), Gen.int(in: 1...4)).map { kind, count in
        switch kind {
        case 0: return .clean
        case 1: return .locks(count)
        case 2: return .partialClean
        case 3: return .partialLocks(count)
        case 4: return .failure
        default: return .timeout
        }
    }
}

private func scenarioGenerator() -> Generator<Scenario, some SendableSequenceType> {
    let tail = zip(Gen.int(in: 0...2), Gen.int(in: 0...2), Gen.int(in: 1...4), Gen.int(in: 0...1))
    return zip(scanKindGenerator(), tail).map { scan, tail in
        let (unmountIndex, rescanIndex, count, forceIndex) = tail
        let unmount: [UnmountKind] = [.succeeds, .busy, .fails]
        let rescan: [RescanKind] = [.clean, .locks(count), .failure]
        return Scenario(
            scan: scan,
            unmount: unmount[unmountIndex],
            rescan: rescan[rescanIndex],
            force: forceIndex == 1
        )
    }
}

// MARK: - Fixtures

private let gatingMount = MountInfo(
    mountPoint: URL(fileURLWithPath: "/Volumes/Gating"),
    volumeName: "Gating",
    deviceNode: "/dev/disk9s1",
    fileSystemType: "apfs",
    isInternal: false,
    isRemovable: true,
    isDiskImage: true
)

/// Deterministic locks so equal counts compare equal across the scripted discovery and the expectation.
private func makeLocks(_ count: Int) -> [LockRecord] {
    (0..<count).map { index in
        let path = "/Volumes/Gating/file\(index)"
        return LockRecord(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index))),
            pid: UInt32(500 + index),
            processName: "helper",
            user: "tester",
            category: .openFileHandle,
            role: .cliTool,
            path: path,
            pathBytes: Data(path.utf8)
        )
    }
}

private enum Step: Sendable {
    case result(Result<DiscoveryResult, PhantomTraceError>)
    case hang
}

private func step(for kind: ScanKind) -> Step {
    switch kind {
    case .clean: return .result(.success(DiscoveryResult(locks: [])))
    case .locks(let count): return .result(.success(DiscoveryResult(locks: makeLocks(count))))
    case .partialClean: return .result(.success(DiscoveryResult(locks: [], partial: true)))
    case .partialLocks(let count): return .result(.success(DiscoveryResult(locks: makeLocks(count), partial: true)))
    case .failure: return .result(.failure(.lsofUnavailable))
    case .timeout: return .hang
    }
}

private func step(for kind: RescanKind) -> Step {
    switch kind {
    case .clean: return .result(.success(DiscoveryResult(locks: [])))
    case .locks(let count): return .result(.success(DiscoveryResult(locks: makeLocks(count))))
    case .failure: return .result(.failure(.lsofUnavailable))
    }
}

/// Plays queued steps in order, then repeats the last one. Logs one "scan" event per call.
private final class ScriptedDiscovery: LockDiscovering {
    private let steps: Mutex<[Step]>
    private let events: CallLog<String>

    init(steps: [Step], events: CallLog<String>) {
        self.steps = Mutex(steps)
        self.events = events
    }

    func discover(in volume: MountInfo) async throws -> DiscoveryResult {
        events.record("scan")
        let next = steps.withLock { steps in steps.count > 1 ? steps.removeFirst() : steps[0] }
        switch next {
        case .result(let result):
            return try result.get()
        case .hang:
            try await Task.sleep(for: .seconds(3600))  // ended by the performer's cancellation
            throw CancellationError()
        }
    }
}

/// Records unmount calls into the shared event log so ordering against scans is checked.
private final class OrderedUnmounter: Unmounting {
    private let outcome: UnmountKind
    private let events: CallLog<String>

    init(outcome: UnmountKind, events: CallLog<String>) {
        self.outcome = outcome
        self.events = events
    }

    func unmount(_ volume: MountInfo, force: Bool) async throws {
        events.record("unmount(force: \(force))")
        switch outcome {
        case .succeeds: return
        case .busy: throw PhantomTraceError.unmountBusy
        case .fails: throw PhantomTraceError.unmountFailed(code: 5)
        }
    }
}

/// Fires immediately (a timeout) when `expiresImmediately`, otherwise never fires before cancellation.
private struct GatingClock: Sleeping {
    let expiresImmediately: Bool

    func now() -> Date { Date(timeIntervalSince1970: 1_000_000) }

    func sleep(seconds: TimeInterval) async throws {
        if expiresImmediately { return }
        try await Task.sleep(for: .seconds(3600))
    }
}

private struct Rig {
    let pipeline: ResolutionPipeline
    let events = CallLog<String>()

    init(_ scenario: Scenario, extraScans: [ScanKind] = []) {
        let kinds = [scenario.scan] + extraScans
        var steps = kinds.map { step(for: $0) }
        // After a busy unmount the next scan is the rescan; place it right after the first scan.
        if extraScans.isEmpty { steps.append(step(for: scenario.rescan)) }
        let log = events
        let history = AttemptHistory()
        pipeline = ResolutionPipeline(
            discovery: ScriptedDiscovery(steps: steps, events: log),
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: MockProcessInspector(),
            signals: MockSignalSender(),
            quitter: MockAppQuitter(),
            terminal: MockTerminalScripter(),
            unmounter: OrderedUnmounter(outcome: scenario.unmount, events: log),
            clock: GatingClock(expiresImmediately: scenario.scan == .timeout)
        )
    }
}
