import Foundation
/// Which controls of the sheet are enabled. Pure data derived from the model, so the rules are
/// testable without a UI. Requirements 13.4, 13.5, 13.12, 13.13, 18.14, 18.24, 18.26.
public struct PhantomControls: Equatable, Sendable {
    /// Stage options (egressShells, gracefulRequest, banishLocks) the user may select.
    public var enabledStages: Set<ResolutionStage>
    public var handleMyselfEnabled: Bool
    /// Proceed in `cannotPutAway` and in `phantomTrace`.
    public var proceedEnabled: Bool
    /// The Rescan button of the Failure_Banner.
    public var rescanEnabled: Bool
    /// Eject plus the Finder note, shown while the volume is still mounted (PROVISIONAL, Req 18.21, 18.23).
    public var ejectVisible: Bool
    public var ejectEnabled: Bool
    public init(
        enabledStages: Set<ResolutionStage> = [],
        handleMyselfEnabled: Bool = false,
        proceedEnabled: Bool = false,
        rescanEnabled: Bool = false,
        ejectVisible: Bool = false,
        ejectEnabled: Bool = false
    ) {
        self.enabledStages = enabledStages
        self.handleMyselfEnabled = handleMyselfEnabled
        self.proceedEnabled = proceedEnabled
        self.rescanEnabled = rescanEnabled
        self.ejectVisible = ejectVisible
        self.ejectEnabled = ejectEnabled
    }
    /// Stages that have a possible target among the current user's own locks.
    ///
    /// Locks of other users never count (Requirement 13.12). No locks at all disables every stage
    /// (Requirement 13.13).
    public static func applicableStages(locks: [LockRecord], currentUser: String) -> Set<ResolutionStage> {
        let own = locks.filter { $0.user == currentUser }
        var stages = Set<ResolutionStage>()
        if own.contains(where: { $0.category == .cwd && $0.role == .idleShell }) {
            stages.insert(.egressShells)
        }
        if own.contains(where: { $0.role != .systemDaemon }) {
            stages.insert(.gracefulRequest)
        }
        if !own.isEmpty {
            stages.insert(.banishLocks)
        }
        return stages
    }
    /// Derives the controls for a model.
    ///
    /// - Parameters:
    ///   - degraded: the last scan failed or was partial. PROVISIONAL (Req 18.26): Proceed and every
    ///     stage option are disabled; Rescan stays enabled.
    ///   - busy: a scan, stage, or unmount is running.
    public static func derive(
        from model: WindowModel,
        currentUser: String,
        degraded: Bool,
        busy: Bool
    ) -> PhantomControls {
        var controls = PhantomControls()
        switch model.window {
        case .cannotPutAway:
            controls.proceedEnabled = !busy
        case .phantomTrace:
            controls.rescanEnabled = degraded && !busy
            if !degraded && !busy {
                controls.enabledStages = applicableStages(locks: model.locks, currentUser: currentUser)
                controls.handleMyselfEnabled = true
                controls.proceedEnabled = isSelectable(model.choice, in: controls)
            }
        case .volumeReleased:
            controls.ejectVisible = model.volumeStillMounted
            controls.ejectEnabled = model.volumeStillMounted && !busy && !model.isUnmounting
        case nil:
            break
        }
        return controls
    }
    /// True when `choice` is non-nil and its option is enabled (Requirement 18.14).
    public static func isSelectable(_ choice: PhantomChoice?, in controls: PhantomControls) -> Bool {
        switch choice {
        case .none:
            return false
        case .handleMyself:
            return controls.handleMyselfEnabled
        case .letPhantomTraceAct(let stage):
            return controls.enabledStages.contains(stage)
        }
    }
}
