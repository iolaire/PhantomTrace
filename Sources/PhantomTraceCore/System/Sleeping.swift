import Foundation

/// Injectable clock. Tests use it instead of real sleeps and wall-clock time (Requirement 15.5).
public protocol Sleeping: Sendable {
    func now() -> Date

    /// Suspends for `seconds`. Honors task cancellation by throwing `CancellationError`.
    func sleep(seconds: TimeInterval) async throws
}
