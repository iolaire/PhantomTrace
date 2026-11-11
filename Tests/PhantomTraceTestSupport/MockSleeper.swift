import Foundation
import PhantomTraceCore
import Synchronization

/// Injected clock. `sleep` returns immediately and advances `now()` by the requested amount,
/// so tests never wait on wall-clock time.
public final class MockSleeper: Sleeping {
    private let current: Mutex<Date>
    private let failure: Mutex<(any Error & Sendable)?>
    public let log = CallLog<TimeInterval>()

    public init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        current = Mutex(start)
        failure = Mutex(nil)
    }

    /// Durations passed to `sleep`, in call order.
    public var calls: [TimeInterval] { log.calls }

    public func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }

    /// Makes later sleeps throw, for example `CancellationError()`.
    public func failSleeps(with error: (any Error & Sendable)?) {
        failure.withLock { $0 = error }
    }

    public func now() -> Date {
        current.withLock { $0 }
    }

    public func sleep(seconds: TimeInterval) async throws {
        log.record(seconds)
        if let error = failure.withLock({ $0 }) { throw error }
        advance(by: seconds)
    }
}
