import Foundation
import PhantomTraceCore
import Testing

/// Table-driven unit tests for `SafetyPolicy`.
/// Requirements 6.1, 6.2, 6.3, 6.4, 6.6.
struct SafetyPolicyTests {
    private static let ownPID: UInt32 = 4242
    private static let currentUser: UInt32 = 501
    private static let startTime = Date(timeIntervalSince1970: 1_700_000_000)

    private static func identity(_ pid: UInt32, startOffset: TimeInterval = 0) -> ProcessIdentity {
        ProcessIdentity(pid: pid, startTime: startTime.addingTimeInterval(startOffset))
    }

    private static func policy(_ history: AttemptHistory = AttemptHistory()) -> SafetyPolicy {
        SafetyPolicy(ownPID: ownPID, currentUserID: currentUser, history: history)
    }

    private static func context(
        name: String? = "Preview",
        role: ProcessRole? = .userApplication,
        owner: UInt32? = currentUser,
        authorized: Set<ProcessIdentity> = [],
        confirmedDaemons: Set<ProcessIdentity> = [],
        milliseconds: Int = 0
    ) -> SafetyContext {
        SafetyContext(
            processName: name,
            role: role,
            ownerUserID: owner,
            authorizedIdentities: authorized,
            confirmedDaemons: confirmedDaemons,
            determinationMilliseconds: milliseconds
        )
    }

    private static func action(_ kind: ProposedActionKind, _ target: ProcessIdentity?) -> ProposedAction {
        ProposedAction(kind: kind, target: target, reason: "unit test")
    }

    private static let processKinds: [ProposedActionKind] = [
        .resetShellCwd, .quitApplication, .sendSIGTERM, .sendSIGKILL
    ]

    // MARK: - Requirement 6.1: protected processes

    @Test(arguments: ["launchd", "kernel_task", "WindowServer", "loginwindow", "Finder"])
    func protectedNameIsDeniedForEveryProcessKind(name: String) async {
        let target = Self.identity(900)
        let history = AttemptHistory()
        await history.recordGracefulAttempt(for: target)
        for kind in Self.processKinds {
            let ctx = Self.context(name: name, role: .systemDaemon, authorized: [target], confirmedDaemons: [target])
            let verdict = await Self.policy(history).evaluate(Self.action(kind, target), context: ctx)
            #expect(verdict == .deny(.protectedProcessName), "kind \(kind) name \(name)")
        }
    }

    @Test func protectedNameListMatchesTheSpec() {
        let expected: Set<String> = ["launchd", "kernel_task", "WindowServer", "loginwindow", "Finder"]
        #expect(SafetyPolicy.protectedProcessNames == expected)
    }

    @Test(arguments: [UInt32(0), UInt32(1)])
    func pidZeroAndOneAreDeniedAsProtectedPid(pid: UInt32) async {
        let target = Self.identity(pid)
        for kind in Self.processKinds {
            let ctx = Self.context(authorized: [target], confirmedDaemons: [target])
            let verdict = await Self.policy().evaluate(Self.action(kind, target), context: ctx)
            #expect(verdict == .deny(.protectedPid), "kind \(kind) pid \(pid)")
        }
    }

    @Test func ownPidIsDeniedAsOwnProcess() async {
        let target = Self.identity(Self.ownPID)
        for kind in Self.processKinds {
            let ctx = Self.context(authorized: [target], confirmedDaemons: [target])
            let verdict = await Self.policy().evaluate(Self.action(kind, target), context: ctx)
            #expect(verdict == .deny(.ownProcess), "kind \(kind)")
        }
    }

    @Test func protectedPidIsDeniedEvenWhenTheNameIsUnknown() async {
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, Self.identity(1)),
            context: Self.context(name: nil, owner: nil)
        )
        #expect(verdict == .deny(.protectedPid))
    }

    @Test(arguments: ["Finder2", "launchd-helper", "finder", "Finder ", "zsh"])
    func nearMissNamesAreNotTreatedAsProtected(name: String) async {
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, Self.identity(900)),
            context: Self.context(name: name)
        )
        #expect(verdict == .allow)
    }

    // MARK: - Requirement 6.2: other users

    @Test(arguments: [UInt32(0), UInt32(502), UInt32(99_999)])
    func otherUsersProcessIsDeniedWithoutAuthorization(owner: UInt32) async {
        let target = Self.identity(900)
        for kind in Self.processKinds {
            let verdict = await Self.policy().evaluate(
                Self.action(kind, target),
                context: Self.context(owner: owner)
            )
            #expect(verdict == .deny(.ownedByOtherUser), "kind \(kind) owner \(owner)")
        }
    }

    @Test func otherUsersProcessIsAllowedWhenThatIdentityWasAuthorized() async {
        let target = Self.identity(900)
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, target),
            context: Self.context(owner: 502, authorized: [target])
        )
        #expect(verdict == .allow)
    }

    @Test func authorizationForADifferentStartTimeDoesNotApply() async {
        let target = Self.identity(900)
        let reusedPid = Self.identity(900, startOffset: 60)
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, target),
            context: Self.context(owner: 502, authorized: [reusedPid])
        )
        #expect(verdict == .deny(.ownedByOtherUser))
    }

    // MARK: - Requirements 6.3 and 6.4: SIGKILL ordering and daemon confirmation

    @Test func sigkillWithoutPriorGracefulAttemptIsDenied() async {
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGKILL, Self.identity(900)),
            context: Self.context()
        )
        #expect(verdict == .deny(.noPriorGracefulAttempt))
    }

    @Test func sigkillAfterGracefulAttemptOnTheSameIdentityIsAllowed() async {
        let target = Self.identity(900)
        let history = AttemptHistory()
        await history.recordGracefulAttempt(for: target)
        let verdict = await Self.policy(history).evaluate(Self.action(.sendSIGKILL, target), context: Self.context())
        #expect(verdict == .allow)
    }

    @Test func gracefulAttemptOnAnotherIdentityDoesNotCountForSigkill() async {
        let target = Self.identity(900)
        let history = AttemptHistory()
        await history.recordGracefulAttempt(for: Self.identity(901))
        await history.recordGracefulAttempt(for: Self.identity(900, startOffset: 5))
        let verdict = await Self.policy(history).evaluate(Self.action(.sendSIGKILL, target), context: Self.context())
        #expect(verdict == .deny(.noPriorGracefulAttempt))
    }

    @Test func resetHistoryForgetsGracefulAttempts() async {
        let target = Self.identity(900)
        let history = AttemptHistory()
        await history.recordGracefulAttempt(for: target)
        await history.reset()
        let verdict = await Self.policy(history).evaluate(Self.action(.sendSIGKILL, target), context: Self.context())
        #expect(verdict == .deny(.noPriorGracefulAttempt))
    }

    @Test func confirmedSystemDaemonMaySkipTheGracefulAttempt() async {
        let target = Self.identity(900)
        let ctx = Self.context(name: "mdworker", role: .systemDaemon, confirmedDaemons: [target])
        let verdict = await Self.policy().evaluate(Self.action(.sendSIGKILL, target), context: ctx)
        #expect(verdict == .allow)
    }

    @Test(arguments: [ProcessRole.userApplication, .cliTool, .idleShell, .unknown])
    func daemonConfirmationDoesNotApplyToOtherRoles(role: ProcessRole) async {
        let target = Self.identity(900)
        let ctx = Self.context(role: role, confirmedDaemons: [target])
        let verdict = await Self.policy().evaluate(Self.action(.sendSIGKILL, target), context: ctx)
        #expect(verdict == .deny(.noPriorGracefulAttempt))
    }

    @Test func unconfirmedSystemDaemonStillNeedsAGracefulAttempt() async {
        let ctx = Self.context(name: "mdworker", role: .systemDaemon)
        let verdict = await Self.policy().evaluate(Self.action(.sendSIGKILL, Self.identity(900)), context: ctx)
        #expect(verdict == .deny(.noPriorGracefulAttempt))
    }

    @Test(arguments: [ProposedActionKind.resetShellCwd, .quitApplication, .sendSIGTERM])
    func nonKillActionsNeedNoGracefulAttempt(kind: ProposedActionKind) async {
        let verdict = await Self.policy().evaluate(Self.action(kind, Self.identity(900)), context: Self.context())
        #expect(verdict == .allow)
    }

    // MARK: - Requirement 6.6: undetermined state and the 1000 ms limit

    @Test func determinationAtExactlyTheLimitIsAllowed() async {
        let ctx = Self.context(milliseconds: SafetyPolicy.determinationLimitMilliseconds)
        let verdict = await Self.policy().evaluate(Self.action(.sendSIGTERM, Self.identity(900)), context: ctx)
        #expect(verdict == .allow)
    }

    @Test(arguments: [1001, 5000, Int.max])
    func determinationPastTheLimitIsDenied(milliseconds: Int) async {
        let ctx = Self.context(milliseconds: milliseconds)
        for kind in Self.processKinds {
            let verdict = await Self.policy().evaluate(Self.action(kind, Self.identity(900)), context: ctx)
            #expect(verdict == .deny(.undeterminableState), "kind \(kind) ms \(milliseconds)")
        }
    }

    @Test func limitIsOneThousandMilliseconds() {
        #expect(SafetyPolicy.determinationLimitMilliseconds == 1000)
    }

    @Test func unknownOwnerIsDenied() async {
        let target = Self.identity(900)
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, target),
            context: Self.context(owner: nil, authorized: [target])
        )
        #expect(verdict == .deny(.undeterminableState))
    }

    @Test func unknownProcessNameIsDenied() async {
        let verdict = await Self.policy().evaluate(
            Self.action(.sendSIGTERM, Self.identity(900)),
            context: Self.context(name: nil)
        )
        #expect(verdict == .deny(.undeterminableState))
    }

    @Test func processActionWithoutATargetIsDenied() async {
        for kind in Self.processKinds {
            let verdict = await Self.policy().evaluate(Self.action(kind, nil), context: Self.context())
            #expect(verdict == .deny(.undeterminableState), "kind \(kind)")
        }
    }

    @Test func unmountWithoutATargetIsLeftToTheMountResolver() async {
        let verdict = await Self.policy().evaluate(Self.action(.unmount, nil), context: Self.context(name: nil))
        #expect(verdict == .allow)
    }

    // MARK: - Allow path

    @Test func ordinaryCurrentUserProcessIsAllowedForEveryNonKillKind() async {
        for kind in [ProposedActionKind.resetShellCwd, .quitApplication, .sendSIGTERM] {
            let verdict = await Self.policy().evaluate(Self.action(kind, Self.identity(900)), context: Self.context())
            #expect(verdict == .allow, "kind \(kind)")
        }
    }
}
