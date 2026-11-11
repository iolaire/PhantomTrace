import Foundation
import PhantomTraceCore

/// Live `Sleeping`: real time for the running app. Tests inject their own clock instead.
struct SystemClock: Sleeping {
    func now() -> Date {
        Date()
    }

    func sleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }
}
