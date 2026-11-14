import Foundation

/// Maps a window to its ghost colour. Requirement 18.5.
public func ghostFor(_ window: WindowState) -> GhostState {
    switch window {
    case .cannotPutAway: return .yellow
    case .phantomTrace: return .red
    case .volumeReleased: return .green
    }
}

/// Picks the window for a discovery state. Returns nil for HIDDEN (nothing to show yet).
///
/// Pure. `proceeded` is the Proceeded_Flag: the user pressed proceed in `cannotPutAway`.
/// Requirements 18.1 to 18.4, 18.8.
public func selectWindow(
    discovery: DiscoveryState,
    proceeded: Bool,
    current: WindowState?
) -> WindowState? {
    switch discovery {
    case .clean, .unmounting, .unmounted:
        return .volumeReleased
    case .blocked:
        return proceeded || current == .phantomTrace ? .phantomTrace : .cannotPutAway
    case .resolvingStage:
        // A stage is running, so the user has already proceeded.
        return .phantomTrace
    case .partial:
        return .phantomTrace
    case .failed(let error, _):
        switch error {
        case .notAMountPoint, .protectedVolume:
            return nil  // resolve failure: alert only, no lock window (Requirement 2)
        case .lsofUnavailable, .lsofTimedOut, .commandTimedOut, .commandLaunchFailed, .permissionDenied,
             .processIdentityChanged, .safetyDenied, .unmountBusy, .unmountFailed, .cancelled:
            return .phantomTrace
        }
    case .scanning, .parsed, .classified:
        return current  // scanning never changes the window
    case .idle, .resolving:
        return nil
    }
}
