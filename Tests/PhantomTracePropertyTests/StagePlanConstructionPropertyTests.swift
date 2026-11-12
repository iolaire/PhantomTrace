import Foundation
import PhantomTraceCore
import PropertyBased
import Testing

/// Property 14: Stage plan construction.
/// **Validates: Requirements 7.1, 8.1, 8.2, 8.3, 11.7**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct StagePlanConstructionPropertyTests {
    private static let iterations = 500

    @Test func egressPlansExactlyOneResetPerAllowedIdleShellCwdLock() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator) { scenario in
            let plan = await scenario.plan(.egressShells)
            let candidates = scenario.locks.filter { $0.category == .cwd && $0.role == .idleShell }
            let allowed = candidates.filter(scenario.isAllowed)
            #expect(plan.stage == .egressShells)
            #expect(plan.actions.map(\.kind).allSatisfy { $0 == .resetShellCwd })
            #expect(plan.actions.map(\.target) == allowed.map(\.identity))
            #expect(plan.skipped.map(\.lock) == candidates.filter { !scenario.isAllowed($0) })
        }
    }

    @Test func egressNeverPlansLocksThatAreNotIdleShellCwd() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator) { scenario in
            let plan = await scenario.plan(.egressShells)
            let others = scenario.locks.filter { !($0.category == .cwd && $0.role == .idleShell) }
            let touched = Set(plan.skipped.map(\.lock.id))
            #expect(others.allSatisfy { !touched.contains($0.id) })
            #expect(plan.actions.count + plan.skipped.count
                == scenario.locks.count - others.count)
        }
    }

    @Test func gracefulPlansQuitForGUIAndSigtermForOtherAllowedDistinctPids() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator) { scenario in
            let plan = await scenario.plan(.gracefulRequest)
            let firsts = scenario.firstLockPerPID()
            let allowed = firsts.filter(scenario.isAllowed)
            let expectedKinds: [ProposedActionKind] = allowed.map {
                scenario.guiPIDs.contains($0.pid) ? .quitApplication : .sendSIGTERM
            }
            #expect(plan.stage == .gracefulRequest)
            #expect(plan.actions.map(\.kind) == expectedKinds)
            #expect(plan.actions.compactMap { $0.target?.pid } == allowed.map(\.pid))
            #expect(Set(plan.actions.compactMap { $0.target?.pid }).count == plan.actions.count)
        }
    }

    @Test func deniedLocksAreSkippedAndNeverPlannedInAnyStage() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator) { scenario in
            for stage in [ResolutionStage.egressShells, .gracefulRequest] {
                let plan = await scenario.plan(stage)
                #expect(plan.actions.allSatisfy { action in
                    action.target.map { target in
                        scenario.locks.contains { $0.pid == target.pid && scenario.isAllowed($0) }
                    } ?? false
                })
                #expect(plan.skipped.allSatisfy { !scenario.isAllowed($0.lock) })
            }
        }
    }

    @Test func everyDistinctPidIsPlannedOrSkippedExactlyOnceInGracefulStage() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator) { scenario in
            let plan = await scenario.plan(.gracefulRequest)
            let handled = plan.actions.compactMap { $0.target?.pid } + plan.skipped.map(\.lock.pid)
            let distinct = Set(scenario.locks.map(\.pid))
            #expect(handled.count == distinct.count)
            #expect(Set(handled) == distinct)
        }
    }
}

// MARK: - Scenario

private let ownPID: UInt32 = 7
private let currentUser: UInt32 = 501
private let otherUser: UInt32 = 0
private let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
private let pidPool: [UInt32] = [0, 1, 7, 2, 3, 4, 5, 6, 8, 9]
private let namePool = ["Preview", "zsh", "cat", "Finder", "launchd", "Notes"]

private struct Scenario: Sendable {
    let locks: [LockRecord]
    /// Per pid index in `pidPool`: 0 unknown, 1 other user, 2 current user.
    let owners: [Int]
    let guiPIDs: Set<UInt32>

    func plan(_ stage: ResolutionStage) async -> ResolutionPlan {
        let policy = SafetyPolicy(ownPID: ownPID, currentUserID: currentUser, history: AttemptHistory())
        var ownerIDs: [UInt32: UInt32] = [:]
        for (index, pid) in pidPool.enumerated() {
            switch owners[index] {
            case 1: ownerIDs[pid] = otherUser
            case 2: ownerIDs[pid] = currentUser
            default: break
            }
        }
        let input = StagePlanInput(
            locks: locks,
            scanCompletedAt: baseTime,
            now: baseTime,
            ownerUserIDs: ownerIDs,
            guiPIDs: guiPIDs
        )
        return await StagePlanBuilder(policy: policy).plan(stage, input: input)
    }

    /// Independent restatement of Requirements 6.1, 6.2, 6.5 and 6.6 for these generated locks.
    func isAllowed(_ lock: LockRecord) -> Bool {
        guard lock.pid > 1, lock.pid != ownPID else { return false }
        guard !SafetyPolicy.protectedProcessNames.contains(lock.processName) else { return false }
        guard let index = pidPool.firstIndex(of: lock.pid) else { return false }
        return owners[index] == 2
    }

    func firstLockPerPID() -> [LockRecord] {
        var seen = Set<UInt32>()
        return locks.filter { seen.insert($0.pid).inserted }
    }
}

// MARK: - Generators

private var scenarioGenerator: Generator<Scenario, some SendableSequenceType> {
    let locks = Gen.int(in: 0...999_999).array(of: 0...14)
    let owners = Gen.int(in: 0...2).array(of: pidPool.count...pidPool.count)
    let gui = Gen.bool().array(of: pidPool.count...pidPool.count)
    return zip(locks, owners, gui).map { selectors, owners, gui in
        Scenario(
            locks: selectors.map(makeLock),
            owners: owners,
            guiPIDs: Set(pidPool.enumerated().filter { gui[$0.offset] }.map(\.element))
        )
    }
}

private func makeLock(_ selector: Int) -> LockRecord {
    let pid = pidPool[selector % pidPool.count]
    let roles = ProcessRole.allCases
    let path = "/Volumes/A/file\(selector % 17)"
    return LockRecord(
        pid: pid,
        processName: namePool[(selector / 10) % namePool.count],
        user: "tester",
        category: (selector / 1000).isMultiple(of: 2) ? .cwd : .openFileHandle,
        role: roles[(selector / 60) % roles.count],
        path: path,
        pathBytes: Data(path.utf8),
        processStart: baseTime.addingTimeInterval(TimeInterval(pid))
    )
}
