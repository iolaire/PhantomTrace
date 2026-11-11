import Foundation
import Testing
@testable import PhantomTraceCore

struct StagePlanBuilderTests {
    private static let now = Date(timeIntervalSince1970: 1_000)
    private static let owner: UInt32 = 501

    private func lock(
        pid: UInt32,
        name: String = "tool",
        category: LockCategory = .openFileHandle,
        role: ProcessRole = .cliTool
    ) -> LockRecord {
        LockRecord(
            pid: pid, processName: name, user: "me", category: category, role: role,
            path: "/Volumes/A/f", pathBytes: Data("/Volumes/A/f".utf8),
            processStart: Date(timeIntervalSince1970: Double(pid))
        )
    }

    private func input(
        _ locks: [LockRecord],
        scanAge: TimeInterval = 1,
        gui: Set<UInt32> = [],
        owners: [UInt32: UInt32]? = nil
    ) -> StagePlanInput {
        StagePlanInput(
            locks: locks,
            scanCompletedAt: Self.now.addingTimeInterval(-scanAge),
            now: Self.now,
            ownerUserIDs: owners ?? Dictionary(
                locks.map { ($0.pid, Self.owner) },
                uniquingKeysWith: { first, _ in first }
            ),
            guiPIDs: gui
        )
    }

    private func builder(history: AttemptHistory = AttemptHistory()) -> StagePlanBuilder {
        StagePlanBuilder(policy: SafetyPolicy(ownPID: 99, currentUserID: Self.owner, history: history))
    }

    @Test func egressProposesOneResetPerIdleShellCwdLock() async {
        let shell = lock(pid: 10, name: "zsh", category: .cwd, role: .idleShell)
        let others = [
            lock(pid: 11, name: "zsh", category: .openFileHandle, role: .idleShell),
            lock(pid: 12, category: .cwd, role: .cliTool)
        ]
        let plan = await builder().plan(.egressShells, input: input([shell] + others))
        #expect(plan.actions.map(\.kind) == [.resetShellCwd])
        #expect(plan.actions.first?.target?.pid == 10)
        #expect(plan.skipped.isEmpty)
    }

    @Test func gracefulSplitsGuiAndCliAndDedupesPids() async {
        let locks = [lock(pid: 20, name: "Preview"), lock(pid: 20, name: "Preview"), lock(pid: 21)]
        let plan = await builder().plan(.gracefulRequest, input: input(locks, gui: [20]))
        #expect(plan.actions.map(\.kind) == [.quitApplication, .sendSIGTERM])
    }

    @Test func gracefulSkipsProtectedAndOtherUserProcesses() async {
        let locks = [lock(pid: 1, name: "launchd"), lock(pid: 30, name: "Finder"), lock(pid: 31)]
        let owners: [UInt32: UInt32] = [1: 0, 30: Self.owner, 31: 0]
        let plan = await builder().plan(.gracefulRequest, input: input(locks, owners: owners))
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.map(\.denial) == [.protectedPid, .protectedProcessName, .ownedByOtherUser])
    }

    @Test func banishRequiresRecordedGracefulAttempt() async throws {
        let target = lock(pid: 40)
        let history = AttemptHistory()
        let none = await builder(history: history).plan(.banishLocks, input: input([target]))
        #expect(none.actions.isEmpty)
        #expect(none.skipped.map(\.denial) == [.noPriorGracefulAttempt])

        await history.recordGracefulAttempt(for: try #require(target.identity))
        let some = await builder(history: history).plan(.banishLocks, input: input([target]))
        #expect(some.actions.map(\.kind) == [.sendSIGKILL])
    }

    @Test func banishProposesNothingFromStaleScan() async throws {
        let target = lock(pid: 41)
        let history = AttemptHistory()
        await history.recordGracefulAttempt(for: try #require(target.identity))
        let plan = await builder(history: history).plan(.banishLocks, input: input([target], scanAge: 6))
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.count == 1)
    }

    @Test func lockWithoutStartTimeIsSkippedAsUndeterminable() async {
        let noStart = LockRecord(
            pid: 50, processName: "tool", user: "me", category: .openFileHandle, role: .cliTool,
            path: "/Volumes/A/f", pathBytes: Data("/Volumes/A/f".utf8)
        )
        let plan = await builder().plan(.gracefulRequest, input: input([noStart]))
        #expect(plan.actions.isEmpty)
        #expect(plan.skipped.map(\.denial) == [.undeterminableState])
    }
}
