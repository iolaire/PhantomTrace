import Foundation
import PhantomTraceTestSupport
import Synchronization
@testable import PhantomTraceCore

/// Injected clock for pipeline tests: sleeps return at once and advance `now()`. The 30 s scan limit never
/// fires, so a scan always wins its race. `onSleep` lets a test change the world after a given sleep.
final class PipelineTestClock: Sleeping {
    let inner = MockSleeper()
    private let hook = Mutex<(@Sendable (TimeInterval) -> Void)?>(nil)

    func onSleep(_ body: @escaping @Sendable (TimeInterval) -> Void) {
        hook.withLock { $0 = body }
    }

    func now() -> Date { inner.now() }

    func sleep(seconds: TimeInterval) async throws {
        if seconds >= TimedScanner.timeoutSeconds {
            try await Task.sleep(for: .seconds(3600))
        }
        try await inner.sleep(seconds: seconds)
        hook.withLock { $0 }?(seconds)
    }

    var sleeps: [TimeInterval] { inner.calls }

    /// Number of grace-period polls recorded so far.
    var gracePolls: Int { sleeps.filter { $0 == ResolutionPipeline.gracePollSeconds }.count }
}

/// Builders and a wired pipeline over mock systems for the sibling pipeline test files.
enum PipelineFixtures {
    static let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Throwaway"),
        volumeName: "Throwaway",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    static func start(_ pid: UInt32) -> Date { Date(timeIntervalSince1970: Double(pid)) }

    static func identity(_ pid: UInt32) -> ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: start(pid))
    }

    static func lock(
        _ pid: UInt32,
        name: String = "worker",
        category: LockCategory = .openFileHandle,
        role: ProcessRole = .cliTool
    ) -> LockRecord {
        LockRecord(
            pid: pid, processName: name, user: "me", category: category, role: role,
            path: "/Volumes/Throwaway/f\(pid)", pathBytes: Data("/Volumes/Throwaway/f\(pid)".utf8),
            processStart: start(pid)
        )
    }

    static func details(
        _ pid: UInt32,
        terminal: String? = nil,
        group: Int32 = 1,
        foreground: Int32? = nil,
        directory: URL? = nil
    ) -> ProcessDetails {
        ProcessDetails(
            identity: identity(pid), ownerUserID: 501, terminalDevice: terminal, processGroupID: group,
            foregroundProcessGroupID: foreground, currentDirectory: directory
        )
    }

    struct Rig {
        let pipeline: ResolutionPipeline
        let discovery: MockLockDiscovery
        let signals: MockSignalSender
        let quitter: MockAppQuitter
        let inspector: MockProcessInspector
        let terminal: MockTerminalScripter
        let clock: PipelineTestClock
        let history: AttemptHistory
    }

    static func rig(
        locks: [LockRecord],
        processes: [Int32: ProcessDetails]? = nil,
        signalError: PhantomTraceError? = nil,
        graceSeconds: TimeInterval = ResolutionPipeline.defaultGraceSeconds
    ) -> Rig {
        let history = AttemptHistory()
        let table = processes ?? Dictionary(uniqueKeysWithValues: locks.map { (Int32($0.pid), details($0.pid)) })
        let inspector = MockProcessInspector(processes: table)
        let discovery = MockLockDiscovery(fallback: .success(DiscoveryResult(locks: locks)))
        let signals = MockSignalSender(fallback: signalError)
        let quitter = MockAppQuitter()
        let terminal = MockTerminalScripter()
        let clock = PipelineTestClock()
        let pipeline = ResolutionPipeline(
            discovery: discovery,
            policy: SafetyPolicy(ownPID: 4242, currentUserID: 501, history: history),
            history: history,
            inspector: inspector,
            signals: signals,
            quitter: quitter,
            terminal: terminal,
            unmounter: MockUnmounter(),
            clock: clock,
            graceSeconds: graceSeconds
        )
        return Rig(
            pipeline: pipeline, discovery: discovery, signals: signals, quitter: quitter,
            inspector: inspector, terminal: terminal, clock: clock, history: history
        )
    }
}
