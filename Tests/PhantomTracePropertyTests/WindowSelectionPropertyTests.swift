import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 22: Window state selection.
///
/// Discovery states, windows, and the Proceeded_Flag are generated from small integer codes so every
/// run is deterministic and needs no system access.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct WindowSelectionPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func cleanUnmountingAndUnmountedAlwaysSelectVolumeReleased() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...2),
            Gen.bool(),
            Gen.int(in: 0...3)
        ) { code, proceeded, currentCode in
            let discovery: DiscoveryState = [.clean, .unmounting, .unmounted][code]
            let result = selectWindow(discovery: discovery, proceeded: proceeded, current: window(currentCode))
            #expect(result == .volumeReleased)
        }
    }

    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func blockedSelectsCannotPutAwayOnlyBeforeUserProceeds() async {
        await propertyCheck(count: Self.iterations, input: Gen.bool(), Gen.int(in: 0...3)) { proceeded, currentCode in
            let current = window(currentCode)
            let result = selectWindow(discovery: .blocked, proceeded: proceeded, current: current)
            if proceeded || current == .phantomTrace {
                #expect(result == .phantomTrace)
            } else {
                #expect(result == .cannotPutAway)
            }
        }
    }

    /// A rescan that finds locks never returns the user to `cannotPutAway`.
    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func blockedRescanFromPhantomTraceNeverReturnsToCannotPutAway() async {
        await propertyCheck(count: Self.iterations, input: Gen.bool()) { proceeded in
            let result = selectWindow(discovery: .blocked, proceeded: proceeded, current: .phantomTrace)
            #expect(result == .phantomTrace)
        }
    }

    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func failedAndPartialScansSelectPhantomTrace() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...9_999),
            Gen.bool(),
            Gen.int(in: 0...3)
        ) { seed, proceeded, currentCode in
            let discovery = scanFailureState(seed)
            let result = selectWindow(discovery: discovery, proceeded: proceeded, current: window(currentCode))
            #expect(result == .phantomTrace)
        }
    }

    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func scanningLeavesTheWindowUnchanged() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...2),
            Gen.bool(),
            Gen.int(in: 0...3)
        ) { code, proceeded, currentCode in
            let discovery: DiscoveryState = [.scanning, .parsed, .classified][code]
            let current = window(currentCode)
            let result = selectWindow(discovery: discovery, proceeded: proceeded, current: current)
            #expect(result == current)
        }
    }

    /// The window is a pure function of its inputs, and the ghost follows the window alone.
    /// **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
    @Test func selectionIsDeterministicAndOnlyShowsOneWindow() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...9_999),
            Gen.bool(),
            Gen.int(in: 0...3)
        ) { seed, proceeded, currentCode in
            let discovery = anyState(seed)
            let current = window(currentCode)
            let first = selectWindow(discovery: discovery, proceeded: proceeded, current: current)
            let second = selectWindow(discovery: discovery, proceeded: proceeded, current: current)
            #expect(first == second)
            if let first {
                let model = WindowModel(window: first)
                #expect(model.ghost == ghostFor(first))
            }
        }
    }
}

/// 0 maps to HIDDEN (nil); 1 to 3 map to the three windows.
private func window(_ code: Int) -> WindowState? {
    switch code {
    case 1: return .cannotPutAway
    case 2: return .phantomTrace
    case 3: return .volumeReleased
    default: return nil
    }
}

private func warnings(_ seed: Int) -> [ParseWarning] {
    (0..<(seed % 3)).map { .invalidPid(offset: seed + $0) }
}

private func scanFailureState(_ seed: Int) -> DiscoveryState {
    let errors: [PhantomTraceError] = [
        .lsofUnavailable,
        .lsofTimedOut(seconds: Double(seed % 30)),
        .commandTimedOut(command: "/usr/sbin/lsof", seconds: Double(seed % 30)),
        .commandLaunchFailed(command: "/usr/sbin/lsof"),
        .permissionDenied(pid: UInt32(seed)),
        .processIdentityChanged(pid: UInt32(seed)),
        .unmountBusy,
        .unmountFailed(code: Int32(seed))
    ]
    if seed % 5 == 0 {
        return .partial(warnings: warnings(seed))
    }
    return .failed(errors[seed % errors.count], warnings: warnings(seed))
}

private func anyState(_ seed: Int) -> DiscoveryState {
    let simple: [DiscoveryState] = [
        .idle, .resolving, .scanning, .parsed, .classified, .clean, .blocked, .unmounting, .unmounted,
        .resolvingStage(.egressShells)
    ]
    if seed % 3 == 0 {
        return scanFailureState(seed)
    }
    return simple[seed % simple.count]
}
