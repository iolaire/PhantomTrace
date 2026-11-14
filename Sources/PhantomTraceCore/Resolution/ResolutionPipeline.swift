import Foundation

/// Runs the resolution stages (Requirements 6, 7, 8, 9, 10, 11, 14.3).
///
/// This is the only place that reaches the signal, quit, shell-egress and unmount adapters, and only for
/// actions it approved itself in `plan(_:on:)` (Requirement 6.7). `execute` runs nothing that was not in
/// the last plan it built for that stage, and each approval is used once.
public actor ResolutionPipeline: StageRunning {
    /// Requirement 8.5: default grace wait, configurable from 1 to 60 seconds.
    public static let defaultGraceSeconds: TimeInterval = 5
    public static let graceRange: ClosedRange<TimeInterval> = 1...60
    /// Requirement 11.3: pause before the post-stage rescan.
    public static let settleSeconds: TimeInterval = 0.5
    static let gracePollSeconds: TimeInterval = 0.25

    private struct Approval {
        let volume: MountInfo
        let actions: [ProposedAction]
        let names: [ProcessIdentity: String]
        /// The facts each action was approved with, so `execute` can ask the policy again.
        let contexts: [ProcessIdentity: SafetyContext]
    }

    /// What the actions of one stage did, carried to the post-stage rescan.
    private struct StageResults {
        var succeeded: [ProposedAction] = []
        var failed: [FailedAction] = []
        var manual: [ManualAction] = []
    }

    private let scanner: TimedScanner
    private let builder: StagePlanBuilder
    private let policy: any SafetyPolicying
    private let history: AttemptHistory
    private let inspector: any ProcessInspecting
    private let signals: any SignalSending
    private let quitter: any AppQuitting
    private let egress: EgressShellPerformer
    private let handoff: CleanHandoffPerformer
    private let clock: any Sleeping
    private let graceSeconds: TimeInterval
    private var approvals: [ResolutionStage: Approval] = [:]

    /// `policy` and `history` must be wired together by the caller (`SafetyPolicy(history:)`), so the
    /// attempts this pipeline records are the ones the policy checks before a `SIGKILL`.
    public init(
        discovery: any LockDiscovering,
        policy: any SafetyPolicying,
        history: AttemptHistory,
        inspector: any ProcessInspecting,
        signals: any SignalSending,
        quitter: any AppQuitting,
        terminal: any TerminalScripting,
        unmounter: any Unmounting,
        clock: any Sleeping,
        graceSeconds: TimeInterval = ResolutionPipeline.defaultGraceSeconds
    ) {
        scanner = TimedScanner(discovery: discovery, clock: clock)
        builder = StagePlanBuilder(policy: policy)
        self.policy = policy
        self.history = history
        self.inspector = inspector
        self.signals = signals
        self.quitter = quitter
        egress = EgressShellPerformer(inspector: inspector, terminal: terminal, clock: clock)
        handoff = CleanHandoffPerformer(discovery: discovery, policy: policy, unmounter: unmounter, clock: clock)
        self.clock = clock
        self.graceSeconds = min(max(graceSeconds, Self.graceRange.lowerBound), Self.graceRange.upperBound)
    }

    // MARK: - StageRunning

    public func plan(
        _ stage: ResolutionStage,
        on volume: MountInfo,
        confirmedDaemons: Set<ProcessIdentity>
    ) async throws -> ResolutionPlan {
        approvals[stage] = nil
        guard stage != .cleanHandoff else {
            return ResolutionPlan(stage: stage, actions: [], skipped: [])
        }
        // Requirement 11.1: a failed or timed-out scan means no plan.
        let scan = try await scanner.scan(volume).get()
        let completedAt = clock.now()
        let owners = ownerIDs(for: scan.locks)
        let guiPIDs = Set(scan.locks.map(\.pid).filter { quitter.isGUIApplication(pid: Int32(truncatingIfNeeded: $0)) })
        let now = clock.now()
        let input = StagePlanInput(
            locks: scan.locks,
            scanCompletedAt: completedAt,
            now: now,
            ownerUserIDs: owners,
            guiPIDs: guiPIDs,
            confirmedDaemons: confirmedDaemons,
            // Requirement 6.6: time spent gathering the owner and GUI facts.
            determinationMilliseconds: Int((now.timeIntervalSince(completedAt) * 1000).rounded(.up))
        )
        let plan = await builder.plan(stage, input: input)
        var names: [ProcessIdentity: String] = [:]
        var contexts: [ProcessIdentity: SafetyContext] = [:]
        for lock in scan.locks {
            guard let identity = lock.identity else { continue }
            names[identity] = lock.processName
            contexts[identity] = StagePlanBuilder.safetyContext(for: lock, input: input)
        }
        approvals[stage] = Approval(volume: volume, actions: plan.actions, names: names, contexts: contexts)
        return plan
    }

    public func execute(_ plan: ResolutionPlan, on volume: MountInfo) async throws -> StageOutcome {
        let approval = approvals.removeValue(forKey: plan.stage)
        // An approval is for the volume it was planned on; executing against another mount sends nothing.
        let runnable = plan.actions.filter { approval?.volume == volume && approval?.actions.contains($0) == true }
        var results = StageResults()
        for action in runnable {
            // Requirement 6: a cancelled stage must not send another signal.
            try Task.checkCancellation()
            let result = await run(
                action, stage: plan.stage, volume: volume,
                names: approval?.names ?? [:], contexts: approval?.contexts ?? [:]
            )
            switch result {
            case .success: results.succeeded.append(action)
            case .failure(let error): results.failed.append(FailedAction(action: action, error: error))
            case .manual(let reason, let instruction):
                results.manual.append(ManualAction(action: action, reason: reason, instruction: instruction))
            case .skipped: break
            }
        }
        if plan.stage == .gracefulRequest {
            try await waitForGrace(results.succeeded.compactMap(\.target))
        }
        return try await rescan(plan.stage, volume: volume, results: results)
    }

    public func cleanHandoff(on volume: MountInfo, force: Bool) async -> CleanHandoffResult {
        await handoff.perform(on: volume, force: force)
    }

    // MARK: - Running one action

    private enum ActionResult {
        case success
        case failure(PhantomTraceError)
        /// Nothing was sent and the user must act by hand, such as a shell that needs a manual `cd ~`.
        case manual(EgressManualReason, instruction: String)
        /// Not delivered and not a failure the user must see, such as an unmount action in a signal stage.
        case skipped
    }

    private func run(
        _ action: ProposedAction,
        stage: ResolutionStage,
        volume: MountInfo,
        names: [ProcessIdentity: String],
        contexts: [ProcessIdentity: SafetyContext]
    ) async -> ActionResult {
        guard let target = action.target else { return .skipped }
        // Requirements 8.7, 9.6: identity is checked right before anything is sent.
        guard identityHolds(target, expectedName: stage == .banishLocks ? names[target] : nil) else {
            return .failure(.processIdentityChanged(pid: target.pid))
        }
        // Requirement 6.7: ask the policy again right before sending, so the attempt history it checks
        // for a SIGKILL is the one at send time and not only the one at plan time.
        guard let context = contexts[target] else { return .failure(.safetyDenied(.undeterminableState)) }
        if case .deny(let denial) = await policy.evaluate(action, context: context) {
            return .failure(.safetyDenied(denial))
        }
        switch action.kind {
        case .resetShellCwd:
            return await runEgress(action, volume: volume)
        case .quitApplication:
            await history.recordGracefulAttempt(for: target)  // recorded even if delivery fails
            let delivered = await quitter.requestQuit(pid: Int32(truncatingIfNeeded: target.pid))
            return delivered ? .success : .failure(.commandLaunchFailed(command: "quitApplication"))
        case .sendSIGTERM:
            await history.recordGracefulAttempt(for: target)
            return send(.terminate, to: target)
        case .sendSIGKILL:
            return send(.kill, to: target)
        case .unmount:
            return .skipped  // only Clean Handoff unmounts
        }
    }

    private func runEgress(_ action: ProposedAction, volume: MountInfo) async -> ActionResult {
        switch await egress.perform(action, volumeMountPoint: volume.mountPoint) {
        case .succeeded:
            return .success
        case .manual(let reason, let instruction):
            return .manual(reason, instruction: instruction)
        case .failed(.processIdentityChanged(let pid)):
            return .failure(.processIdentityChanged(pid: pid))
        case .failed(.cancelled):
            return .failure(.cancelled)
        case .failed(.invalidAction), .failed(.stillOnVolume):
            return .failure(.commandLaunchFailed(command: "resetShellCwd"))
        }
    }

    private func send(_ signal: ProcessSignal, to target: ProcessIdentity) -> ActionResult {
        do {
            try signals.send(signal, to: Int32(truncatingIfNeeded: target.pid))
            return .success
        } catch let error as PhantomTraceError {
            // Requirement 14.3: EPERM arrives as permissionDenied(pid:); record it and carry on.
            return .failure(error)
        } catch {
            return .failure(.commandLaunchFailed(command: "kill"))
        }
    }

    private func identityHolds(_ target: ProcessIdentity, expectedName: String?) -> Bool {
        guard let details = inspector.inspect(pid: Int32(truncatingIfNeeded: target.pid)),
              details.identity == target else { return false }
        guard let expectedName, let path = details.executablePath else { return true }
        let actual = path.lastPathComponent
        // lsof truncates command names, so either side may be a prefix of the other.
        return actual.hasPrefix(expectedName) || expectedName.hasPrefix(actual)
    }

    private func ownerIDs(for locks: [LockRecord]) -> [UInt32: UInt32] {
        var owners: [UInt32: UInt32] = [:]
        for lock in locks where owners[lock.pid] == nil {
            if let details = inspector.inspect(pid: Int32(truncatingIfNeeded: lock.pid)) {
                owners[lock.pid] = details.ownerUserID
            }
        }
        return owners
    }

    // MARK: - Grace wait and rescan

    /// Waits up to the grace period, ending early once every target has exited (Requirement 8.5).
    /// Zero targets means no wait (Requirement 8.4).
    private func waitForGrace(_ targets: [ProcessIdentity]) async throws {
        guard !targets.isEmpty else { return }
        var waited: TimeInterval = 0
        while waited < graceSeconds {
            let alive = targets.contains { target in
                inspector.inspect(pid: Int32(truncatingIfNeeded: target.pid))?.identity == target
            }
            guard alive else { return }
            try await clock.sleep(seconds: Self.gracePollSeconds)
            waited += Self.gracePollSeconds
        }
    }

    private func rescan(
        _ stage: ResolutionStage,
        volume: MountInfo,
        results: StageResults
    ) async throws -> StageOutcome {
        try await clock.sleep(seconds: Self.settleSeconds)
        let scan = await scanner.scan(volume)
        if case .failure(.cancelled) = scan { throw CancellationError() }
        // A partial or failed rescan verifies nothing, so it is reported as timed out with no locks.
        if case .success(let result) = scan, !result.partial {
            return StageOutcome(
                stage: stage, succeeded: results.succeeded, failed: results.failed, manual: results.manual,
                remainingLocks: result.locks
            )
        }
        return StageOutcome(
            stage: stage, succeeded: results.succeeded, failed: results.failed, manual: results.manual,
            remainingLocks: [], rescanTimedOut: true
        )
    }
}
