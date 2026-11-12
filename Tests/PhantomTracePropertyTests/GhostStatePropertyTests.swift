import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 20: Ghost state mapping.
///
/// Windows and discovery states come from small integer codes, so runs are deterministic and touch no system.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct GhostStatePropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 13.6, 13.7, 13.8, 18.5, 18.8**
    @Test func ghostColourMatchesWindow() async {
        await propertyCheck(count: Self.iterations, input: Gen.int(in: 0...2)) { code in
            let (window, expected) = Self.pairs[code]
            #expect(ghostFor(window) == expected)
        }
    }

    /// The ghost of a model is derived from its window alone, whatever else the model holds.
    /// **Validates: Requirements 13.6, 13.7, 13.8, 18.5, 18.8**
    @Test func modelGhostIsNilWhenHiddenAndDerivedFromWindowOtherwise() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...3),
            Gen.bool(),
            Gen.bool(),
            Gen.int(in: 0...2)
        ) { code, scanning, mounted, choiceCode in
            let window = Self.window(code)
            let model = WindowModel(
                window: window,
                isScanning: scanning,
                volumeStillMounted: mounted,
                choice: Self.choice(choiceCode)
            )
            #expect(model.ghost == window.map(ghostFor))
        }
    }

    /// Scanning in progress does not change the ghost.
    /// **Validates: Requirements 13.6, 13.7, 13.8, 18.5, 18.8**
    @Test func scanningDoesNotChangeTheGhost() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...3),
            Gen.int(in: 0...2),
            Gen.bool()
        ) { code, scanCode, proceeded in
            let before = WindowModel(window: Self.window(code))
            let scanning: DiscoveryState = [.scanning, .parsed, .classified][scanCode]
            let after = before.applying(discovery: scanning, proceeded: proceeded)
            #expect(after.isScanning)
            #expect(after.ghost == before.ghost)
        }
    }

    /// After any discovery change the ghost still equals the mapping of the resulting window.
    /// **Validates: Requirements 13.6, 13.7, 13.8, 18.5, 18.8**
    @Test func ghostNeverDivergesFromWindowAfterAnyTransition() async {
        await propertyCheck(
            count: Self.iterations,
            input: Gen.int(in: 0...3),
            Gen.int(in: 0...9),
            Gen.bool(),
            Gen.bool()
        ) { code, stateCode, proceeded, missing in
            let states: [DiscoveryState] = [
                .idle, .resolving, .scanning, .clean, .blocked, .unmounting, .unmounted,
                .partial(warnings: []), .failed(.lsofUnavailable, warnings: []), .resolvingStage(.egressShells)
            ]
            let model = WindowModel(window: Self.window(code))
            let next = model.applying(discovery: states[stateCode], proceeded: proceeded, mountMissing: missing)
            #expect(next.ghost == next.window.map(ghostFor))
            if missing {
                #expect(next.ghost == .green)
            }
        }
    }

    private static let pairs: [(WindowState, GhostState)] = [
        (.cannotPutAway, .yellow),
        (.phantomTrace, .red),
        (.volumeReleased, .green)
    ]

    /// 0 maps to HIDDEN (nil); 1 to 3 map to the three windows.
    private static func window(_ code: Int) -> WindowState? {
        switch code {
        case 1: return .cannotPutAway
        case 2: return .phantomTrace
        case 3: return .volumeReleased
        default: return nil
        }
    }

    private static func choice(_ code: Int) -> PhantomChoice? {
        switch code {
        case 1: return .letPhantomTraceAct(.egressShells)
        case 2: return .letPhantomTraceAct(.banishLocks)
        default: return nil
        }
    }
}
