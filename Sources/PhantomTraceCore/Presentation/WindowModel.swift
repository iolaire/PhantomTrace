import Foundation

/// Everything a window needs to draw. `window` is nil while HIDDEN.
public struct WindowModel: Equatable, Sendable {
    public var window: WindowState?
    public var locks: [LockRecord]
    /// Progress overlay inside the current window. Scanning never changes window or ghost.
    public var isScanning: Bool
    public var banner: Banner?
    public var volumeStillMounted: Bool
    /// Only meaningful in `phantomTrace`.
    public var choice: PhantomChoice?
    /// Which controls are enabled. Derived by the coordinator (Requirements 13.4, 13.13, 18.14, 18.26).
    public var controls: PhantomControls
    /// True while a Resolution_Stage executes: dim the table, show progress on Proceed (Requirement 13.5).
    public var isStageRunning: Bool
    /// True while the unmounter runs: progress on the Eject button (Requirement 18.24).
    public var isUnmounting: Bool
    /// Failed actions of the last stage, capped at 500 entries (Requirement 14.5).
    public var failedActions: FailedActionList
    /// Egress Shells actions of the last stage that need a hand-typed `cd ~` (Requirement 7.5).
    public var manualActions: ManualActionList
    /// Locks owned by another user: shown read-only and never a stage target (Requirement 13.12).
    public var readOnlyLockIDs: Set<UUID>
    /// Set when the input could not be resolved (Requirement 2). Alert only; no window content.
    public var resolveError: PhantomTraceError?

    /// Derived from `window` only (Requirement 18.5).
    public var ghost: GhostState? { window.map(ghostFor) }

    public init(
        window: WindowState? = nil,
        locks: [LockRecord] = [],
        isScanning: Bool = false,
        banner: Banner? = nil,
        volumeStillMounted: Bool = true,
        choice: PhantomChoice? = nil,
        controls: PhantomControls = PhantomControls(),
        isStageRunning: Bool = false,
        isUnmounting: Bool = false,
        failedActions: FailedActionList = FailedActionList(),
        manualActions: ManualActionList = ManualActionList(),
        readOnlyLockIDs: Set<UUID> = [],
        resolveError: PhantomTraceError? = nil
    ) {
        self.window = window
        self.locks = locks
        self.isScanning = isScanning
        self.banner = banner
        self.volumeStillMounted = volumeStillMounted
        self.choice = choice
        self.controls = controls
        self.isStageRunning = isStageRunning
        self.isUnmounting = isUnmounting
        self.failedActions = failedActions
        self.manualActions = manualActions
        self.readOnlyLockIDs = readOnlyLockIDs
        self.resolveError = resolveError
    }

    /// Returns the model after a discovery state change.
    ///
    /// A missing mount selects `volumeReleased` with `volumeStillMounted = false` from any window
    /// (Requirement 18.9). Otherwise the window follows `selectWindow`; scanning only sets `isScanning`.
    public func applying(
        discovery: DiscoveryState,
        proceeded: Bool,
        mountMissing: Bool = false
    ) -> WindowModel {
        var next = self
        if mountMissing {
            next.window = .volumeReleased
            next.volumeStillMounted = false
            next.isScanning = false
            return next
        }
        switch discovery {
        case .scanning, .parsed, .classified:
            next.isScanning = true
            return next
        case .unmounted:
            next.volumeStillMounted = false
        case .idle, .resolving, .clean, .blocked, .resolvingStage, .unmounting, .failed, .partial:
            next.volumeStillMounted = true
        }
        next.isScanning = false
        next.window = selectWindow(discovery: discovery, proceeded: proceeded, current: window)
        return next
    }
}
