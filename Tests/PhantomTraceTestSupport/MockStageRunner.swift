import Foundation
import PhantomTraceCore
import Synchronization
/// Scripted `StageRunning` and `StageReviewing`. Records every call; sends no signal.
public final class MockStageRunner: StageRunning, StageReviewing {
    public enum Call: Equatable, Sendable {
        case plan(ResolutionStage)
        case execute(ResolutionStage)
        case review(ResolutionStage)
        case cleanHandoff(force: Bool)
    }
    public let log = CallLog<Call>()
    public let plans = Script<Result<ResolutionPlan, PhantomTraceError>>(
        fallback: .failure(.lsofUnavailable)
    )
    public let outcomes = Script<Result<StageOutcome, PhantomTraceError>>(
        fallback: .failure(.lsofUnavailable)
    )
    public let handoffs = Script<CleanHandoffResult>(fallback: .unmounted)
    private let approval = Mutex(true)
    public init() {}
    public func setApproval(_ value: Bool) {
        approval.withLock { $0 = value }
    }
    public func plan(_ stage: ResolutionStage, on volume: MountInfo) async throws -> ResolutionPlan {
        log.record(.plan(stage))
        return try plans.next().get()
    }
    public func execute(_ plan: ResolutionPlan, on volume: MountInfo) async throws -> StageOutcome {
        log.record(.execute(plan.stage))
        return try outcomes.next().get()
    }
    public func cleanHandoff(on volume: MountInfo, force: Bool) async -> CleanHandoffResult {
        log.record(.cleanHandoff(force: force))
        return handoffs.next()
    }
    public func review(_ plan: ResolutionPlan) async -> Bool {
        log.record(.review(plan.stage))
        return approval.withLock { $0 }
    }
}
