import Foundation
import Testing
@testable import PhantomTraceCore

struct DiscoveryReducerTests {
    private func run(_ events: [DiscoveryEvent], from start: DiscoveryState = .idle) -> DiscoveryState {
        events.reduce(start) { DiscoveryReducer.reduce($0, $1) }
    }

    @Test func lockedVolumeReachesBlocked() {
        let state = run([
            .inputReceived, .mountResolved, .scanCaptured, .recordsParsed,
            .classificationFinished(lockCount: 2, partial: false, warnings: [])
        ])
        #expect(state == .blocked)
    }

    @Test func zeroLocksReachesCleanThenUnmounted() {
        let state = run([
            .inputReceived, .mountResolved, .scanCaptured, .recordsParsed,
            .classificationFinished(lockCount: 0, partial: false, warnings: []),
            .handoffConfirmed, .unmountSucceeded
        ])
        #expect(state == .unmounted)
    }

    @Test func stageRunsThenRescans() {
        #expect(run([.stageSelected(.gracefulRequest)], from: .blocked) == .resolvingStage(.gracefulRequest))
        #expect(run([.stageCompleted], from: .resolvingStage(.egressShells)) == .scanning)
    }

    @Test func busyUnmountReturnsToBlocked() {
        #expect(run([.unmountBusy], from: .unmounting) == .blocked)
    }

    @Test func partialResultCarriesWarnings() {
        let warnings: [ParseWarning] = [.invalidPid(offset: 3)]
        let state = run([.classificationFinished(lockCount: 1, partial: true, warnings: warnings)], from: .classified)
        #expect(state == .partial(warnings: warnings))
        #expect(DiscoveryReducer.warnings(of: state) == warnings)
    }

    @Test func scanFailureCarriesWarningsAndAllowsNoAction() {
        let warnings: [ParseWarning] = [.invalidPid(offset: 0)]
        let failed = run([.scanFailed(.lsofTimedOut(seconds: 15), warnings: warnings)], from: .scanning)
        #expect(failed == .failed(.lsofTimedOut(seconds: 15), warnings: warnings))
        #expect(!DiscoveryReducer.permitsSignals(failed))
        #expect(!DiscoveryReducer.permitsUnmount(failed))
        let attempts: [DiscoveryEvent] = [
            .stageSelected(.banishLocks), .handoffConfirmed, .unmountSucceeded, .stageCompleted
        ]
        let after = run(attempts, from: failed)
        #expect(after == failed)
    }

    @Test func failedStateRestartsOnlyWithNewInput() {
        let failed = DiscoveryState.failed(.lsofUnavailable, warnings: [.invalidPid(offset: 1)])
        let restarted = run([.inputReceived], from: failed)
        #expect(restarted == .resolving)
        #expect(DiscoveryReducer.warnings(of: restarted).isEmpty)
    }

    @Test func resolveFailureFails() {
        let url = URL(fileURLWithPath: "/nope")
        let state = run([.resolveFailed(.notAMountPoint(url))], from: .resolving)
        #expect(state == .failed(.notAMountPoint(url), warnings: []))
    }

    @Test func unmountIsOnlyPermittedFromClean() {
        #expect(DiscoveryReducer.permitsUnmount(.clean))
        #expect(run([.handoffConfirmed], from: .blocked) == .blocked)
        #expect(!DiscoveryReducer.permitsUnmount(.blocked))
        #expect(run([.stageSelected(.cleanHandoff)], from: .blocked) == .blocked)
    }

    @Test func signalsArePermittedOnlyWhileBlockedOrRunningAStage() {
        #expect(DiscoveryReducer.permitsSignals(.blocked))
        #expect(DiscoveryReducer.permitsSignals(.resolvingStage(.banishLocks)))
        #expect(!DiscoveryReducer.permitsSignals(.clean))
        #expect(!DiscoveryReducer.permitsSignals(.partial(warnings: [])))
    }
}
