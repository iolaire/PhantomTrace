import AppKit
import PhantomTraceCore

/// A borderless window that can take focus; the Platinum chrome draws the title bar and close box.
private final class PlatinumWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Owns the one lock-forensics window and wires it to a `DiagnosticCoordinator`.
///
/// The controller is the only UI object that calls coordinator actions. It also acts as the
/// coordinator's `StageReviewing`: plan preview first, then (Banish Locks only) the explicit
/// confirmation. Requirements 9.5, 10.8, 11.5, 18.6, 18.15 and the window requirements of 18.
@MainActor
public final class LockWindowController: StageReviewing {
    /// Name used in the force-unmount confirmation. Set before the user can reach Eject.
    public var volumeName = "this volume"

    private let coordinator: DiagnosticCoordinator
    private let contentView: LockWindowContentView
    private let window: NSWindow
    private var latestModel = WindowModel()
    private var observation: Task<Void, Never>?
    private var alertedError: PhantomTraceError?

    public init(coordinator: DiagnosticCoordinator, resourceDirectory: URL? = Bundle.main.resourceURL) {
        self.coordinator = coordinator
        contentView = LockWindowContentView(resourceDirectory: resourceDirectory)
        window = PlatinumWindow(
            contentRect: NSRect(origin: .zero, size: LockWindowContentView.preferredSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.center()
        connectActions()
    }

    isolated deinit {
        observation?.cancel()
    }

    /// Starts observing the coordinator. Safe to call once; later calls are ignored.
    public func start() {
        guard observation == nil else { return }
        let coordinator = coordinator
        observation = Task { [weak self] in
            for await model in await coordinator.updates() {
                guard !Task.isCancelled else { return }
                self?.apply(model)
            }
        }
    }

    /// Begins an investigation of `path`. The window appears when the model selects one.
    public func inspect(path: String) {
        let coordinator = coordinator
        volumeName = URL(fileURLWithPath: path).lastPathComponent
        Task { await coordinator.inspect(URL(fileURLWithPath: path)) }
    }

    // MARK: - StageReviewing

    /// Plan preview, then for Banish Locks the explicit confirmation (Requirements 9.5, 11.5).
    public func review(_ plan: ResolutionPlan) async -> Bool {
        let locks = latestModel.locks
        let preview = StageDialogs.planPreview(plan, locks: locks).runModal()
        guard preview == .alertFirstButtonReturn else { return false }
        guard plan.stage == .banishLocks else { return true }
        return StageDialogs.banishConfirmation(plan, locks: locks).runModal() == .alertSecondButtonReturn
    }

    // MARK: - Model

    private func apply(_ model: WindowModel) {
        latestModel = model
        contentView.apply(model)
        if model.window == nil {
            window.orderOut(nil)  // PROVISIONAL (Req 18.6): nothing is shown for Idle/Resolving/resolve-failed
        } else if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        presentResolveError(model.resolveError)
    }

    /// One dismiss-only alert per error (Requirements 2.4, 2.5).
    private func presentResolveError(_ error: PhantomTraceError?) {
        guard let error else {
            alertedError = nil
            return
        }
        guard error != alertedError else { return }
        alertedError = error
        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "PhantomTrace cannot inspect that item"
            alert.informativeText = WindowAppearance.resolveErrorText(error)
            alert.addButton(withTitle: "Dismiss")
            alert.runModal()
        }
    }

    // MARK: - Actions

    private func connectActions() {
        let coordinator = coordinator
        contentView.onProceed = { Task { await coordinator.proceed() } }
        contentView.onRescan = { Task { await coordinator.rescan() } }
        contentView.onSelect = { choice in Task { await coordinator.select(choice) } }
        contentView.onEject = { [weak self] forced in self?.eject(forced: forced) }
        contentView.onClose = { [weak self] in self?.window.close() }
    }

    /// Normal eject runs at once. Force asks for the advanced confirmation first (Requirement 10.8).
    private func eject(forced: Bool) {
        let coordinator = coordinator
        guard forced else {
            Task { await coordinator.eject(force: false) }
            return
        }
        let alert = StageDialogs.forceUnmountConfirmation(volumeName: volumeName)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        Task { await coordinator.eject(force: true) }
    }
}
