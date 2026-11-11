import Foundation

/// An input to the discovery state machine reducer.
public enum DiscoveryEvent: Equatable, Sendable {
    /// A volume, folder, file, or image was provided (also used to start a new run).
    case inputReceived
    case mountResolved
    case resolveFailed(PhantomTraceError)
    /// `lsof` output was captured.
    case scanCaptured
    /// `lsof` failed or timed out. Carries any parse warnings gathered so far.
    case scanFailed(PhantomTraceError, warnings: [ParseWarning])
    /// The captured output was parsed.
    case recordsParsed
    /// Classification finished. `partial` marks incomplete results (Requirement 3.6).
    case classificationFinished(lockCount: Int, partial: Bool, warnings: [ParseWarning])
    /// The user selected stage 1 to 3. `cleanHandoff` is started with `handoffConfirmed`.
    case stageSelected(ResolutionStage)
    /// The stage finished; a rescan follows.
    case stageCompleted
    /// The user confirmed Clean Handoff (Requirement 10.1).
    case handoffConfirmed
    case unmountSucceeded
    /// `kDAReturnBusy` or `EBUSY`: back to Blocked, then rescan (Requirement 10.6).
    case unmountBusy
    case unmountFailed(PhantomTraceError)
}
