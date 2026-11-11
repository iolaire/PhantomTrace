import AppKit
import PhantomTraceCore
import PhantomTraceUI

/// Forwards plan review to the window controller. The coordinator needs a reviewer at creation
/// and the controller needs the coordinator, so the controller is attached afterwards.
@MainActor
final class ReviewerBridge: StageReviewing {
    weak var controller: LockWindowController?

    func review(_ plan: ResolutionPlan) async -> Bool {
        guard let controller else { return false }
        return await controller.review(plan)
    }
}

/// Composition root for the app: the only place live adapters are constructed and wired.
/// Scans and subprocesses run inside actors and `async` adapters, off the main actor.
/// The app opens no network connections (Requirements 15.3, 15.5).
@MainActor
enum AppComposition {
    static func makeWindowController() -> LockWindowController {
        let runner = LiveProcessRunner()
        let fileSystem = LiveFileSystemProbe()
        let processes = LiveProcessInspector()
        let clock = SystemClock()
        let history = AttemptHistory()
        let discovery = LockDiscoveryEngine(
            runner: runner,
            classifier: LockClassifier(fileSystem: fileSystem, processes: processes),
            processes: processes
        )
        let pipeline = ResolutionPipeline(
            discovery: discovery,
            policy: SafetyPolicy(
                ownPID: UInt32(clamping: processes.currentProcessID),
                currentUserID: processes.currentUserID,
                history: history
            ),
            history: history,
            inspector: processes,
            signals: LiveSignalSender(),
            quitter: AppQuitter(),
            terminal: LiveTerminalScripting(runner: runner),
            unmounter: LiveUnmounter(runner: runner),
            clock: clock
        )
        let bridge = ReviewerBridge()
        let coordinator = DiagnosticCoordinator(
            resolver: MountResolver(
                fileSystem: fileSystem,
                mountTable: LiveMountTable(runner: runner, fileSystem: fileSystem)
            ),
            discovery: discovery,
            stages: pipeline,
            reviewer: bridge,
            sleeper: clock,
            currentUser: NSUserName()
        )
        let controller = LockWindowController(coordinator: coordinator)
        bridge.controller = controller
        controller.start()
        return controller
    }
}
