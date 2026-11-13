import Foundation

/// Runs one discovery against a time limit, using the injected clock for the limit.
///
/// Internal: used by `ResolutionPipeline` for stage-start and post-stage scans (Requirements 11.1, 11.3)
/// and by `CleanHandoffPerformer` for the pre-unmount scan (Requirement 10.1).
struct TimedScanner: Sendable {
    /// Requirements 11.1 and 11.3: stage scans and rescans finish within this many seconds.
    static let timeoutSeconds: TimeInterval = 30

    private let discovery: any LockDiscovering
    private let clock: any Sleeping
    private let limitSeconds: TimeInterval

    init(
        discovery: any LockDiscovering,
        clock: any Sleeping,
        limitSeconds: TimeInterval = TimedScanner.timeoutSeconds
    ) {
        self.discovery = discovery
        self.clock = clock
        self.limitSeconds = limitSeconds
    }

    private enum Raced: Sendable {
        case scan(Result<DiscoveryResult, PhantomTraceError>)
        case timedOut
    }

    /// Fails with `lsofTimedOut` when the limit passes first and with `cancelled` when the calling task is
    /// cancelled. Any other failure is reported as is.
    func scan(_ volume: MountInfo) async -> Result<DiscoveryResult, PhantomTraceError> {
        let seconds = limitSeconds
        let discovery = self.discovery
        let clock = self.clock
        let winner = await withTaskGroup(of: Raced?.self, returning: Raced.self) { group in
            group.addTask {
                do {
                    return .scan(.success(try await discovery.discover(in: volume)))
                } catch let error as PhantomTraceError {
                    return .scan(.failure(error))
                } catch is CancellationError {
                    return .scan(.failure(.cancelled))
                } catch {
                    return .scan(.failure(.lsofUnavailable))
                }
            }
            group.addTask {
                do {
                    try await clock.sleep(seconds: seconds)
                    return .timedOut
                } catch {
                    return nil
                }
            }
            var result = Raced.timedOut
            for await outcome in group {
                if let outcome {
                    result = outcome
                    break
                }
            }
            group.cancelAll()
            return result
        }
        switch winner {
        case .timedOut:
            return .failure(.lsofTimedOut(seconds: seconds))
        case .scan(let result):
            return result
        }
    }
}
