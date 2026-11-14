import Foundation

/// Facts about a fresh scan that plan building needs. Gathered by the caller so building stays pure.
public struct StagePlanInput: Equatable, Sendable {
    /// Locks from the fresh scan.
    public let locks: [LockRecord]
    /// When the scan completed. Banish Locks requires it to be at most 5 seconds old (Requirement 9.1).
    public let scanCompletedAt: Date
    /// The planning time, injected so plans never read the wall clock.
    public let now: Date
    /// Owner uid per pid. A missing pid is undetermined and denied (Requirement 6.6).
    public let ownerUserIDs: [UInt32: UInt32]
    /// Pids that belong to GUI applications (from `AppQuitting.isGUIApplication`).
    public let guiPIDs: Set<UInt32>
    public let authorizedIdentities: Set<ProcessIdentity>
    public let confirmedDaemons: Set<ProcessIdentity>
    /// Time spent gathering owner and GUI facts, in milliseconds. Over 1000 ms they count as undetermined
    /// (Requirement 6.6).
    public let determinationMilliseconds: Int

    public init(
        locks: [LockRecord],
        scanCompletedAt: Date,
        now: Date,
        ownerUserIDs: [UInt32: UInt32],
        guiPIDs: Set<UInt32> = [],
        authorizedIdentities: Set<ProcessIdentity> = [],
        confirmedDaemons: Set<ProcessIdentity> = [],
        determinationMilliseconds: Int = 0
    ) {
        self.locks = locks
        self.scanCompletedAt = scanCompletedAt
        self.now = now
        self.ownerUserIDs = ownerUserIDs
        self.guiPIDs = guiPIDs
        self.authorizedIdentities = authorizedIdentities
        self.confirmedDaemons = confirmedDaemons
        self.determinationMilliseconds = determinationMilliseconds
    }
}

/// Builds the previewable plan for stages 1 to 3. Every action goes through `SafetyPolicying.evaluate`;
/// denied actions become `skipped` locks with the reason. Performs no I/O.
/// Requirements 7.1, 8.1 to 8.4, 9.1, 9.2, 11.5, 11.7, 13.12.
public struct StagePlanBuilder: Sendable {
    /// Requirement 9.1.
    public static let maximumScanAgeSeconds: TimeInterval = 5

    private let policy: any SafetyPolicying

    public init(policy: any SafetyPolicying) {
        self.policy = policy
    }

    /// Stage 4 has no process actions here; it yields an empty plan.
    public func plan(_ stage: ResolutionStage, input: StagePlanInput) async -> ResolutionPlan {
        switch stage {
        case .egressShells:
            return await evaluated(stage, candidates: egressCandidates(input), input: input)
        case .gracefulRequest:
            return await evaluated(stage, candidates: gracefulCandidates(input), input: input)
        case .banishLocks:
            return await banishPlan(input)
        case .cleanHandoff:
            return ResolutionPlan(stage: stage, actions: [], skipped: [])
        }
    }

    /// The facts `SafetyPolicy` needs for one lock. Shared with the pipeline, which re-checks an action
    /// with the same facts right before sending it.
    static func safetyContext(for lock: LockRecord, input: StagePlanInput) -> SafetyContext {
        SafetyContext(
            processName: lock.processName,
            role: lock.role,
            ownerUserID: input.ownerUserIDs[lock.pid],
            authorizedIdentities: input.authorizedIdentities,
            confirmedDaemons: input.confirmedDaemons,
            determinationMilliseconds: input.determinationMilliseconds
        )
    }
    private typealias Candidate = (lock: LockRecord, kind: ProposedActionKind)

    private func egressCandidates(_ input: StagePlanInput) -> [Candidate] {
        input.locks
            .filter { $0.category == .cwd && $0.role == .idleShell }
            .map { ($0, .resetShellCwd) }
    }

    private func gracefulCandidates(_ input: StagePlanInput) -> [Candidate] {
        firstLockPerPID(input.locks).map { lock in
            (lock, input.guiPIDs.contains(lock.pid) ? .quitApplication : .sendSIGTERM)
        }
    }

    private func banishPlan(_ input: StagePlanInput) async -> ResolutionPlan {
        let age = input.now.timeIntervalSince(input.scanCompletedAt)
        guard age >= 0, age <= Self.maximumScanAgeSeconds else {
            // A stale or future-dated scan cannot justify a kill: propose nothing.
            let skipped = firstLockPerPID(input.locks).map {
                SkippedLock(lock: $0, denial: .undeterminableState)
            }
            return ResolutionPlan(stage: .banishLocks, actions: [], skipped: skipped)
        }
        let candidates: [Candidate] = firstLockPerPID(input.locks).map { ($0, .sendSIGKILL) }
        return await evaluated(.banishLocks, candidates: candidates, input: input)
    }

    private func evaluated(
        _ stage: ResolutionStage,
        candidates: [Candidate],
        input: StagePlanInput
    ) async -> ResolutionPlan {
        var actions: [ProposedAction] = []
        var skipped: [SkippedLock] = []
        for (lock, kind) in candidates {
            let action = ProposedAction(
                kind: kind,
                target: lock.identity,
                reason: "\(lock.processName) (pid \(lock.pid)) holds \(lock.path)"
            )
            switch await policy.evaluate(action, context: Self.safetyContext(for: lock, input: input)) {
            case .allow:
                actions.append(action)
            case .deny(let denial):
                skipped.append(SkippedLock(lock: lock, denial: denial))
            }
        }
        return ResolutionPlan(stage: stage, actions: actions, skipped: skipped)
    }

    private func firstLockPerPID(_ locks: [LockRecord]) -> [LockRecord] {
        var seen = Set<UInt32>()
        return locks.filter { seen.insert($0.pid).inserted }
    }
}
