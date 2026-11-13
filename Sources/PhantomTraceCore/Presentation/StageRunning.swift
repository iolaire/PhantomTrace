import Foundation
/// How a Clean Handoff ended (Requirement 10).
public enum CleanHandoffResult: Equatable, Sendable {
    case unmounted
    /// Locks were present in the pre-unmount scan, or the unmount returned busy. Carries the new locks.
    case blocked([LockRecord])
    case failed(PhantomTraceError)
}
/// What the coordinator needs from the resolution pipeline (tasks 8.2 and 8.4).
///
/// The pipeline owns the fresh scan at stage start, identity checks, signals, and the post-stage
/// rescan. The coordinator never calls a system adapter directly (safety rule: single choke point).
public protocol StageRunning: Sendable {
    /// Scans afresh and builds the plan for `stage`. Throws when the fresh scan fails (no plan, Req 11.1).
    /// `confirmedDaemons` are `systemDaemon` identities the user confirmed by name and pid for this run;
    /// only they may be sent `SIGKILL` without a prior graceful attempt (Requirement 6.4).
    func plan(
        _ stage: ResolutionStage,
        on volume: MountInfo,
        confirmedDaemons: Set<ProcessIdentity>
    ) async throws -> ResolutionPlan
    /// Executes an approved plan, settles, and rescans. Never called without user approval of the plan.
    func execute(_ plan: ResolutionPlan, on volume: MountInfo) async throws -> StageOutcome
    /// Clean Handoff: fresh scan, then a non-forced unmount unless `force` was confirmed.
    func cleanHandoff(on volume: MountInfo, force: Bool) async -> CleanHandoffResult
}
extension StageRunning {
    /// Plans with no user-confirmed daemons, which is every caller until the UI asks for that confirmation.
    public func plan(_ stage: ResolutionStage, on volume: MountInfo) async throws -> ResolutionPlan {
        try await plan(stage, on: volume, confirmedDaemons: [])
    }
}

/// The user-facing review of a plan before anything runs.
public protocol StageReviewing: Sendable {
    /// Shows the plan (actions and skipped locks with reasons). Returns true to run it.
    ///
    /// For `banishLocks` the answer must come from an explicit confirmation naming each process and
    /// pid (Requirements 9.3, 9.4). A plan with no actions needs no approval and is never executed.
    func review(_ plan: ResolutionPlan) async -> Bool
}
