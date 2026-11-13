import Foundation

/// Performs stage 4, Clean Handoff (Requirements 10.1 to 10.9).
///
/// Internal on purpose: only `ResolutionPipeline` may reach it, and only after the user confirmed the
/// unmount (Requirement 10.1). Every call starts with its own fresh scan; nothing from an earlier scan is
/// reused. An unmount is attempted only when that scan finished in time, was complete, and found zero locks.
struct CleanHandoffPerformer: Sendable {
    /// Requirement 10.1: the pre-unmount scan must finish within this many seconds.
    static let scanTimeoutSeconds: TimeInterval = 10

    private let scanner: TimedScanner
    private let policy: any SafetyPolicying
    private let unmounter: any Unmounting

    init(
        discovery: any LockDiscovering,
        policy: any SafetyPolicying,
        unmounter: any Unmounting,
        clock: any Sleeping
    ) {
        scanner = TimedScanner(discovery: discovery, clock: clock, limitSeconds: Self.scanTimeoutSeconds)
        self.policy = policy
        self.unmounter = unmounter
    }

    /// `force` must be true only after the advanced confirmation (Requirement 10.8).
    func perform(on volume: MountInfo, force: Bool) async -> CleanHandoffResult {
        let scan = await freshScan(of: volume)
        let locks: [LockRecord]
        switch scan {
        case .failure(let error):
            // Requirement 10.4: no unmount call when the scan failed or timed out.
            return .failed(error)
        case .success(let found):
            locks = found
        }
        guard locks.isEmpty else { return .blocked(locks) }
        // A cancelled run must not reach the unmount call.
        guard !Task.isCancelled else { return .failed(.cancelled) }

        let action = ProposedAction(
            kind: .unmount,
            target: nil,
            reason: force ? "Forced unmount of the volume" : "Unmount the volume"
        )
        switch await policy.evaluate(action, context: SafetyContext(processName: nil, role: nil, ownerUserID: nil)) {
        case .deny:
            return .failed(.protectedVolume(volume.mountPoint))
        case .allow:
            break
        }
        return await unmount(volume, force: force)
    }

    private func unmount(_ volume: MountInfo, force: Bool) async -> CleanHandoffResult {
        do {
            try await unmounter.unmount(volume, force: force)
            return .unmounted
        } catch PhantomTraceError.unmountBusy {
            // Requirement 10.3: back to Blocked, with a rescan to show what appeared.
            switch await freshScan(of: volume) {
            case .success(let locks):
                return .blocked(locks)
            case .failure(let error):
                return .failed(error)
            }
        } catch let error as PhantomTraceError {
            return .failed(error)
        } catch is CancellationError {
            return .failed(.cancelled)
        } catch {
            // Any unexpected error: nothing is known to have unmounted.
            return .failed(.unmountFailed(code: -1))
        }
    }

    // MARK: - Scanning with a time limit

    /// A scan that is only trusted when it is complete. A partial result may miss locks, so it is a failure.
    private func freshScan(of volume: MountInfo) async -> Result<[LockRecord], PhantomTraceError> {
        switch await scanner.scan(volume) {
        case .failure(let error):
            return .failure(error)
        case .success(let result):
            return result.partial ? .failure(.lsofUnavailable) : .success(result.locks)
        }
    }
}
