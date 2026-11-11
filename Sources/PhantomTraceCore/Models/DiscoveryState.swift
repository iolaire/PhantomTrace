import Foundation

/// The discovery state machine's states. Transitions live in the reducer (task 7.2).
public enum DiscoveryState: Equatable, Sendable {
    case idle
    case resolving
    case scanning
    case parsed
    case classified
    case clean
    case blocked
    case resolvingStage(ResolutionStage)
    case unmounting
    case unmounted
    /// Discovery failed. Warnings feed the failure banner. No action is possible from this state.
    case failed(PhantomTraceError, warnings: [ParseWarning])
    /// Discovery returned incomplete results.
    case partial(warnings: [ParseWarning])
}
