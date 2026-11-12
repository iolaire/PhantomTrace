import Foundation
import PhantomTraceCore
import PropertyBased
import Testing

/// Property 12: Escalation order.
/// **Validates: Requirements 6.3, 6.4, 8.6, 9.1**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct SafetyPolicyEscalationOrderPropertyTests {
    private static let iterations = 500
    private static let ownPID: UInt32 = 1_000_000
    private static let currentUser: UInt32 = 501
    private static let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func sigkillWithoutGracefulAttemptOrDaemonConfirmationIsDenied() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { pidSelector, roleSelector, nameSelector in
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            // A confirmation only counts for a systemDaemon, and a daemon needs a confirmation.
            let roles = ProcessRole.allCases
            let role = roles[roleSelector % roles.count]
            let confirmed: Set<ProcessIdentity> = role == .systemDaemon ? [] : [identity]
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: role,
                ownerUserID: Self.currentUser,
                confirmedDaemons: confirmed
            )
            let verdict = await Self.policy(AttemptHistory())
                .evaluate(Self.kill(identity), context: context)
            #expect(verdict == .deny(.noPriorGracefulAttempt))
        }
    }

    @Test func sigkillAfterGracefulAttemptOnSameIdentityIsAllowed() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { pidSelector, roleSelector, nameSelector in
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let roles = ProcessRole.allCases
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: roles[roleSelector % roles.count],
                ownerUserID: Self.currentUser
            )
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: identity)
            let verdict = await Self.policy(history).evaluate(Self.kill(identity), context: context)
            #expect(verdict == .allow)
        }
    }

    @Test func gracefulAttemptOnAnotherIdentityDoesNotApproveSigkill() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { pidSelector, variantSelector, nameSelector in
            let pid = UInt32(2 + pidSelector)
            let target = Self.identity(pid: pid)
            // Either a different pid, or the same pid reused with a different start time.
            let other: ProcessIdentity = variantSelector.isMultiple(of: 2)
                ? Self.identity(pid: pid + 1)
                : Self.identity(pid: pid, offset: 1 + TimeInterval(variantSelector))
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .userApplication,
                ownerUserID: Self.currentUser
            )
            let history = AttemptHistory()
            await history.recordGracefulAttempt(for: other)
            let verdict = await Self.policy(history).evaluate(Self.kill(target), context: context)
            #expect(verdict == .deny(.noPriorGracefulAttempt))
        }
    }

    @Test func confirmedSystemDaemonMaySigkillWithoutPriorAttempt() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator
        ) { pidSelector, nameSelector in
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .systemDaemon,
                ownerUserID: Self.currentUser,
                confirmedDaemons: [identity]
            )
            let verdict = await Self.policy(AttemptHistory())
                .evaluate(Self.kill(identity), context: context)
            #expect(verdict == .allow)
        }
    }

    @Test func daemonConfirmationForAnotherIdentityDoesNotApproveSigkill() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator
        ) { pidSelector, nameSelector in
            let pid = UInt32(2 + pidSelector)
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .systemDaemon,
                ownerUserID: Self.currentUser,
                confirmedDaemons: [Self.identity(pid: pid + 1)]
            )
            let verdict = await Self.policy(AttemptHistory())
                .evaluate(Self.kill(Self.identity(pid: pid)), context: context)
            #expect(verdict == .deny(.noPriorGracefulAttempt))
        }
    }

    @Test func gentlerKindsNeverRequireAPriorAttempt() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { pidSelector, kindSelector, nameSelector in
            let kinds = ProposedActionKind.allCases.filter { $0 != .unmount && $0 != .sendSIGKILL }
            let identity = Self.identity(pid: UInt32(2 + pidSelector))
            let context = SafetyContext(
                processName: Self.ordinaryName(nameSelector),
                role: .userApplication,
                ownerUserID: Self.currentUser
            )
            let action = ProposedAction(kind: kinds[kindSelector % kinds.count], target: identity, reason: "test")
            let verdict = await Self.policy(AttemptHistory()).evaluate(action, context: context)
            #expect(verdict == .allow)
        }
    }

    // MARK: - Helpers

    private static func policy(_ history: AttemptHistory) -> SafetyPolicy {
        SafetyPolicy(ownPID: ownPID, currentUserID: currentUser, history: history)
    }

    private static func identity(pid: UInt32, offset: TimeInterval = 0) -> ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: baseTime.addingTimeInterval(offset))
    }

    private static func kill(_ identity: ProcessIdentity) -> ProposedAction {
        ProposedAction(kind: .sendSIGKILL, target: identity, reason: "property test")
    }

    private static func ordinaryName(_ selector: Int) -> String {
        let names = ["Preview", "zsh", "cat", "vim", "Notes", "mdworker", "backupd"]
        return names[selector % names.count]
    }
}

// MARK: - Generators

private var selectorGenerator: Generator<Int, some SendableSequenceType> {
    Gen.int(in: 0...100_000)
}
