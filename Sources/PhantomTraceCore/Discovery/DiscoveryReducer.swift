import Foundation

/// Pure transition function for the discovery state machine (design: Discovery State Machine).
///
/// Events that are not valid in the current state leave it unchanged, so a stray event can never
/// start an action. Requirements 3.6, 10.3, 10.6, 14.1, 14.4.
public enum DiscoveryReducer {
    /// Returns the next state. Performs no I/O.
    public static func reduce(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch state {
        case .idle, .unmounted, .failed, .partial:
            // Idle starts a run. Terminal states only accept a fresh run (the Rescan control, Requirement 14.5),
            // which drops the old warnings. Nothing else, so no signal or unmount can follow a failure.
            return event == .inputReceived ? .resolving : state
        case .resolving:
            return reduceResolving(state, event)
        case .scanning:
            return reduceScanning(state, event)
        case .parsed:
            return reduceParsed(state, event)
        case .classified:
            return reduceClassified(state, event)
        case .clean:
            return event == .handoffConfirmed ? .unmounting : state
        case .blocked:
            if case .stageSelected(let stage) = event, stage != .cleanHandoff {
                return .resolvingStage(stage)
            }
            return state
        case .resolvingStage:
            return reduceResolvingStage(state, event)
        case .unmounting:
            return reduceUnmounting(state, event)
        }
    }

    /// True only when the state allows sending signals or quitting apps (Requirements 6, 14.4).
    public static func permitsSignals(_ state: DiscoveryState) -> Bool {
        switch state {
        case .blocked, .resolvingStage:
            return true
        case .idle, .resolving, .scanning, .parsed, .classified, .clean, .unmounting, .unmounted,
             .failed, .partial:
            return false
        }
    }

    /// True only when the state allows an unmount call (Requirement 10.3).
    public static func permitsUnmount(_ state: DiscoveryState) -> Bool {
        switch state {
        case .clean, .unmounting:
            return true
        case .idle, .resolving, .scanning, .parsed, .classified, .blocked, .resolvingStage, .unmounted,
             .failed, .partial:
            return false
        }
    }

    /// Parse warnings the Failure_Banner should show, empty when the state carries none.
    public static func warnings(of state: DiscoveryState) -> [ParseWarning] {
        switch state {
        case .failed(_, let warnings), .partial(let warnings):
            return warnings
        case .idle, .resolving, .scanning, .parsed, .classified, .clean, .blocked, .resolvingStage,
             .unmounting, .unmounted:
            return []
        }
    }

    private static func reduceResolving(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch event {
        case .mountResolved:
            return .scanning
        case .resolveFailed(let error):
            return .failed(error, warnings: [])
        default:
            return state
        }
    }

    private static func reduceScanning(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch event {
        case .scanCaptured:
            return .parsed
        case .scanFailed(let error, let warnings):
            return .failed(error, warnings: warnings)
        default:
            return state
        }
    }

    private static func reduceParsed(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch event {
        case .recordsParsed:
            return .classified
        case .scanFailed(let error, let warnings):
            return .failed(error, warnings: warnings)
        default:
            return state
        }
    }

    private static func reduceClassified(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        guard case .classificationFinished(let lockCount, let partial, let warnings) = event else {
            return state
        }
        if partial {
            return .partial(warnings: warnings)
        }
        return lockCount > 0 ? .blocked : .clean
    }

    private static func reduceResolvingStage(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch event {
        case .stageCompleted:
            return .scanning
        case .scanFailed(let error, let warnings):
            // The stage-start scan failed: abort with no plan (Requirement 11.1).
            return .failed(error, warnings: warnings)
        default:
            return state
        }
    }

    private static func reduceUnmounting(_ state: DiscoveryState, _ event: DiscoveryEvent) -> DiscoveryState {
        switch event {
        case .unmountSucceeded:
            return .unmounted
        case .unmountBusy:
            return .blocked
        case .unmountFailed(let error):
            return .failed(error, warnings: [])
        default:
            return state
        }
    }
}
