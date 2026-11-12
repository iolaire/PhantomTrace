import Foundation
import PhantomTraceCore
import PropertyBased
import Testing

/// Property 11: Safety deny-list.
/// **Validates: Requirements 6.1, 6.2, 6.5**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct SafetyPolicyDenyListPropertyTests {
    private static let iterations = 500
    private static let ownPID: UInt32 = 1_000_000
    private static let currentUser: UInt32 = 501

    @Test func protectedPidsAreDeniedForEveryKindOwnerAndAuthorization() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator, selectorGenerator
        ) { pidSelector, kindSelector, ownerSelector, nameSelector in
            let pids: [UInt32] = [0, 1, Self.ownPID]
            let pid = pids[pidSelector % pids.count]
            let identity = Self.identity(pid: pid)
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .userApplication,
                ownerUserID: Self.owner(ownerSelector),
                authorizedIdentities: [identity],
                confirmedDaemons: [identity]
            )
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: identity)
            let verdict = await Self.policy(history).evaluate(Self.action(kindSelector, identity), context: context)
            let expected: SafetyDenial = pid == Self.ownPID ? .ownProcess : .protectedPid
            #expect(verdict == .deny(expected))
        }
    }

    @Test func protectedProcessNamesAreDeniedForEveryKindOwnerAndAuthorization() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator, selectorGenerator
        ) { nameSelector, kindSelector, ownerSelector, pidSelector in
            let names = SafetyPolicy.protectedProcessNames.sorted()
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let context = SafetyContext(
                processName: names[nameSelector % names.count],
                role: .systemDaemon,
                ownerUserID: Self.owner(ownerSelector),
                authorizedIdentities: [identity],
                confirmedDaemons: [identity]
            )
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: identity)
            let verdict = await Self.policy(history).evaluate(Self.action(kindSelector, identity), context: context)
            #expect(verdict == .deny(.protectedProcessName))
        }
    }

    @Test func otherUsersProcessesWithoutAuthorizationAreDenied() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator, selectorGenerator
        ) { kindSelector, ownerSelector, nameSelector, pidSelector in
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let otherOwner = Self.currentUser + 1 + UInt32(ownerSelector)
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .userApplication,
                ownerUserID: otherOwner
            )
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: identity)
            let verdict = await Self.policy(history).evaluate(Self.action(kindSelector, identity), context: context)
            #expect(verdict == .deny(.ownedByOtherUser))
        }
    }

    @Test func currentUserNonProtectedProcessWithStageOrderingSatisfiedIsAllowed() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { kindSelector, nameSelector, pidSelector in
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .userApplication,
                ownerUserID: Self.currentUser
            )
            // A recorded graceful attempt satisfies the SIGKILL ordering rule; other kinds need none.
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: identity)
            let verdict = await Self.policy(history).evaluate(Self.action(kindSelector, identity), context: context)
            #expect(verdict == .allow)
        }
    }

    // MARK: - Helpers

    private static func policy(_ history: AttemptHistory) -> SafetyPolicy {
        SafetyPolicy(ownPID: ownPID, currentUserID: currentUser, history: history)
    }

    private static func identity(pid: UInt32) -> ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: Date(timeIntervalSince1970: 1_700_000_000))
    }

    /// Process-targeting kinds only; `unmount` has no process target.
    private static func action(_ selector: Int, _ identity: ProcessIdentity) -> ProposedAction {
        let kinds = ProposedActionKind.allCases.filter { $0 != .unmount }
        return ProposedAction(kind: kinds[selector % kinds.count], target: identity, reason: "property test")
    }

    /// Mix of the current user, another user, and root.
    private static func owner(_ selector: Int) -> UInt32 {
        let owners: [UInt32] = [currentUser, 0, 502, 12_345]
        return owners[selector % owners.count]
    }

    private static func ordinaryName(_ selector: Int) -> String {
        let names = ["Preview", "zsh", "cat", "vim", "Notes", "Finder2", "launchd-helper", "loginwindow "]
        return names[selector % names.count]
    }
}

// MARK: - Generators

private var selectorGenerator: Generator<Int, some SendableSequenceType> {
    Gen.int(in: 0...100_000)
}
