import Foundation

/// The previewable plan for one stage: approved actions plus skipped locks with denial reasons.
public struct ResolutionPlan: Equatable, Sendable {
    public let stage: ResolutionStage
    public let actions: [ProposedAction]
    public let skipped: [SkippedLock]

    public init(stage: ResolutionStage, actions: [ProposedAction], skipped: [SkippedLock]) {
        self.stage = stage
        self.actions = actions
        self.skipped = skipped
    }
}
