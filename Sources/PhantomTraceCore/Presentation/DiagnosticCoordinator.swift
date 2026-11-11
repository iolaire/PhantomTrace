import Foundation
/// View-model logic for the diagnostic sheet. No AppKit: the app observes `updates()` and draws.
///
/// Orchestrates the mount resolver, lock discovery, the discovery state machine, the resolution
/// pipeline, and window selection. Every effect goes through a protocol, so tests use mocks.
/// Requirements 2.4, 2.5, 13.4, 13.5, 13.12, 13.13, 14.1, 14.2, 14.4, 14.5, 18.x.
public actor DiagnosticCoordinator {
    /// PROVISIONAL (Req 18.7): the first scan shows the frame with a Scanning_Overlay only after this long.
    public static let firstScanOverlayDelaySeconds: TimeInterval = 0.5
    private let resolver: any MountResolving
    private let discovery: any LockDiscovering
    private let stages: any StageRunning
    private let reviewer: any StageReviewing
    private let sleeper: any Sleeping
    private let currentUser: String
    private(set) var state: DiscoveryState = .idle
    private var model = WindowModel()
    private var volume: MountInfo?
    private var lastInput: URL?
    /// The Proceeded_Flag (Requirement 18.12).
    private var proceeded = false
    private var degraded = false
    private var operationInFlight = false
    private var scanToken = 0
    private var subscribers: [UUID: AsyncStream<WindowModel>.Continuation] = [:]
    public init(
        resolver: any MountResolving,
        discovery: any LockDiscovering,
        stages: any StageRunning,
        reviewer: any StageReviewing,
        sleeper: any Sleeping,
        currentUser: String
    ) {
        self.resolver = resolver
        self.discovery = discovery
        self.stages = stages
        self.reviewer = reviewer
        self.sleeper = sleeper
        self.currentUser = currentUser
    }
    // MARK: - Observation
    /// The current model.
    public var current: WindowModel { model }
    /// A stream that yields the current model first, then every change.
    public func updates() -> AsyncStream<WindowModel> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<WindowModel>.makeStream(bufferingPolicy: .unbounded)
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        continuation.yield(model)
        return stream
    }
    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
    // MARK: - User actions
    /// Starts a new investigation of `input` (a volume, folder, file, or image).
    ///
    /// This is the only "first scan": only it may lead to `cannotPutAway` (Requirement 18.2).
    public func inspect(_ input: URL) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        lastInput = input
        proceeded = false
        degraded = false
        volume = nil
        state = .idle
        model = WindowModel()
        state = DiscoveryReducer.reduce(state, .inputReceived)
        publish()
        let mount: MountInfo
        do {
            mount = try resolver.resolve(input)
        } catch {
            // PROVISIONAL (Req 18.6): a resolve failure shows no window content, only an alert.
            state = DiscoveryReducer.reduce(state, .resolveFailed(Self.asPhantomTraceError(error, input: input)))
            model.resolveError = Self.asPhantomTraceError(error, input: input)
            publish()
            return
        }
        volume = mount
        state = DiscoveryReducer.reduce(state, .mountResolved)
        await scan(on: mount, isFirstScan: true)
    }
    /// The Rescan button (Requirement 14.2). Starts a new run and clears the banner and warnings.
    public func rescan() async {
        guard beginOperation() else { return }
        defer { endOperation() }
        guard let mount = volume else {
            if let input = lastInput {
                endOperation()
                await inspect(input)
                _ = beginOperation()
            }
            return
        }
        await scan(on: mount, isFirstScan: false)
    }
    /// Selects a Phantom_Choice option. Activation of a disabled option is ignored (Requirement 13.4).
    public func select(_ choice: PhantomChoice?) {
        guard model.window == .phantomTrace, !operationInFlight else { return }
        if let choice, !PhantomControls.isSelectable(choice, in: model.controls) { return }
        model.choice = choice
        refreshDerived()
        publish()
    }
    /// The Proceed button in `cannotPutAway` or `phantomTrace`.
    public func proceed() async {
        guard beginOperation() else { return }
        defer { endOperation() }
        switch model.window {
        case .cannotPutAway:
            // Requirement 18.12: set the Proceeded_Flag and show `phantomTrace`.
            proceeded = true
            model = model.applying(discovery: state, proceeded: proceeded)
            refreshDerived()
            publish()
        case .phantomTrace:
            await proceedFromPhantomTrace()
        case .volumeReleased, nil:
            return
        }
    }
    /// The Eject button: Clean Handoff (Requirement 18.22). `force` only after the advanced confirmation.
    public func eject(force: Bool = false) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        guard let mount = volume, model.window == .volumeReleased, model.volumeStillMounted,
              DiscoveryReducer.permitsUnmount(state) else { return }
        state = DiscoveryReducer.reduce(state, .handoffConfirmed)
        model.isUnmounting = true  // Requirement 18.24
        refreshDerived()
        publish()
        let result = await stages.cleanHandoff(on: mount, force: force)
        model.isUnmounting = false
        switch result {
        case .unmounted:
            state = DiscoveryReducer.reduce(state, .unmountSucceeded)
            model = model.applying(discovery: state, proceeded: proceeded)
        case .blocked(let locks):
            // Requirement 18.25: back to Blocked, `phantomTrace` with the new locks and the red ghost.
            proceeded = true
            state = DiscoveryReducer.reduce(state, .unmountBusy)
            model = model.applying(discovery: state, proceeded: proceeded)
            model.locks = locks
            model.banner = nil
        case .failed(let error):
            state = DiscoveryReducer.reduce(state, .unmountFailed(error))
            apply(failure: error, warnings: [])
        }
        refreshDerived()
        publish()
    }
    /// Call when the mount table changed. If the volume is gone, selects `volumeReleased` with
    /// `volumeStillMounted = false` from any window (Requirement 18.9).
    public func mountTableChanged() {
        guard volume != nil, !operationInFlight, isVolumeMissing() else { return }
        applyMountMissing()
        refreshDerived()
        publish()
    }
}

extension DiagnosticCoordinator {
    // MARK: - Scanning
    private func scan(on mount: MountInfo, isFirstScan: Bool) async {
        // Not a reducer transition for a rescan from Blocked or Clean: the user asked for a fresh run
        // and the reducer only models the first run and stage runs. Failed/partial accept it there too.
        state = .scanning
        beginScanning(isFirstScan: isFirstScan)
        let token = scanToken
        let overlay = isFirstScan ? startOverlayTimer(token: token) : nil
        let result: DiscoveryResult?
        var error: PhantomTraceError?
        do {
            result = try await discovery.discover(in: mount)
        } catch let thrown {
            result = nil
            error = Self.asPhantomTraceError(thrown, input: mount.mountPoint)
        }
        overlay?.cancel()
        scanToken += 1
        if let result {
            finishScan(
                locks: result.locks,
                partial: result.partial,
                warnings: result.warnings,
                isFirstScan: isFirstScan
            )
        } else if let error {
            state = DiscoveryReducer.reduce(.scanning, .scanFailed(error, warnings: []))
            finishFailed(error: error, isFirstScan: isFirstScan)
        }
    }
    private func beginScanning(isFirstScan: Bool) {
        // Requirement 14.2: clear the banner and warnings once the new run begins.
        model.banner = nil
        model.failedActions = FailedActionList()
        model.resolveError = nil
        degraded = false
        if isFirstScan {
            // PROVISIONAL (Req 18.7): no overlay until the delay passes (see startOverlayTimer).
            model.isScanning = false
        } else {
            model = model.applying(discovery: .scanning, proceeded: proceeded)  // overlay now, window unchanged
        }
        refreshDerived()
        publish()
    }
    private func startOverlayTimer(token: Int) -> Task<Void, Never> {
        let sleeper = self.sleeper
        return Task { [weak self] in
            do { try await sleeper.sleep(seconds: Self.firstScanOverlayDelaySeconds) } catch { return }
            await self?.showFirstScanOverlay(token: token)
        }
    }
    private func showFirstScanOverlay(token: Int) {
        guard token == scanToken, state == .scanning else { return }
        model.isScanning = true
        refreshDerived()
        publish()
    }
    /// Feeds a finished scan through the state machine and updates the model.
    private func finishScan(locks: [LockRecord], partial: Bool, warnings: [ParseWarning], isFirstScan: Bool) {
        state = DiscoveryReducer.reduce(state, .scanCaptured)
        state = DiscoveryReducer.reduce(state, .recordsParsed)
        state = DiscoveryReducer.reduce(
            state,
            .classificationFinished(lockCount: locks.count, partial: partial, warnings: warnings)
        )
        markProceededUnlessFirstScan(isFirstScan)
        let missing = isVolumeMissing()
        model = model.applying(discovery: state, proceeded: proceeded, mountMissing: missing)
        model.locks = missing ? [] : locks
        degraded = false
        if !missing, case .partial = state {
            degraded = true
            model.banner = Banner.capped(
                message: "Discovery returned partial results. Some locks may be missing.",
                warnings: warnings
            )
        }
        refreshDerived()
        publish()
    }
    private func finishFailed(error: PhantomTraceError, isFirstScan: Bool) {
        markProceededUnlessFirstScan(isFirstScan)
        apply(failure: error, warnings: DiscoveryReducer.warnings(of: state))
        refreshDerived()
        publish()
    }
    /// Shows a failure in `phantomTrace` with the Failure_Banner. No action is possible from Failed
    /// (Requirement 14.4), which the reducer guarantees.
    private func apply(failure error: PhantomTraceError, warnings: [ParseWarning]) {
        let missing = isVolumeMissing()
        model = model.applying(discovery: state, proceeded: proceeded, mountMissing: missing)
        model.locks = []
        degraded = !missing
        // Requirement 14.1: the banner says the discovery failed and carries up to 100 warnings.
        model.banner = missing ? nil : Banner.capped(
            message: "Discovery failed: \(Self.describe(error))",
            warnings: warnings
        )
    }
    /// `cannotPutAway` is reachable only from the first scan of an input that found locks
    /// (Requirement 18.2; design Property 22). Every later run, whether a Rescan, a handle-myself
    /// rescan, a post-stage result, or an unmount that came back busy, counts as proceeded, so a
    /// Blocked result from it selects `phantomTrace`.
    private func markProceededUnlessFirstScan(_ isFirstScan: Bool) {
        if !isFirstScan { proceeded = true }
    }
    // MARK: - Proceed in phantomTrace
    private func proceedFromPhantomTrace() async {
        guard let mount = volume, let choice = model.choice,
              PhantomControls.isSelectable(choice, in: model.controls) else { return }
        switch choice {
        case .handleMyself:
            // PROVISIONAL (Req 18.16): a fresh rescan only. No signal, no pipeline call.
            await scan(on: mount, isFirstScan: false)
        case .letPhantomTraceAct(let stage):
            guard stage != .cleanHandoff else { return }  // Eject is its own button (Requirement 13.3)
            await runStage(stage, on: mount)
        }
    }
    private func runStage(_ stage: ResolutionStage, on mount: MountInfo) async {
        // Signals only from Blocked (Requirements 6, 14.4); the reducer refuses anything else.
        let next = DiscoveryReducer.reduce(state, .stageSelected(stage))
        guard DiscoveryReducer.permitsSignals(state), next == .resolvingStage(stage) else { return }
        state = next
        model.isStageRunning = true  // Requirement 13.5
        model.failedActions = FailedActionList()
        refreshDerived()
        publish()
        let plan: ResolutionPlan
        do {
            plan = try await stages.plan(stage, on: mount)  // fresh scan; failure means no plan (Req 11.1)
        } catch {
            await stageFailed(Self.asPhantomTraceError(error, input: mount.mountPoint))
            return
        }
        // An empty plan is never executed. A refused review sends nothing either.
        let approved = plan.actions.isEmpty ? false : await reviewer.review(plan)
        guard approved else {
            await rescanAfterStage(on: mount)
            return
        }
        do {
            let outcome = try await stages.execute(plan, on: mount)
            model.failedActions = FailedActionList(capping: outcome.failed)
            state = DiscoveryReducer.reduce(state, .stageCompleted)
            model.isStageRunning = false
            // The pipeline already rescanned (Requirement 11.2). Use that fresh result; a timed-out
            // rescan verifies nothing and is reported as a failure.
            if outcome.rescanTimedOut {
                let timeout = PhantomTraceError.lsofTimedOut(seconds: 30)
                state = DiscoveryReducer.reduce(state, .scanFailed(timeout, warnings: []))
                finishFailed(error: timeout, isFirstScan: false)
            } else {
                finishScan(locks: outcome.remainingLocks, partial: false, warnings: [], isFirstScan: false)
            }
        } catch {
            await stageFailed(Self.asPhantomTraceError(error, input: mount.mountPoint))
        }
    }
    private func stageFailed(_ error: PhantomTraceError) async {
        model.isStageRunning = false
        state = DiscoveryReducer.reduce(state, .scanFailed(error, warnings: []))
        finishFailed(error: error, isFirstScan: false)
    }
    private func rescanAfterStage(on mount: MountInfo) async {
        model.isStageRunning = false
        state = DiscoveryReducer.reduce(state, .stageCompleted)
        await scan(on: mount, isFirstScan: false)
    }
    // MARK: - Helpers
    private func beginOperation() -> Bool {
        if operationInFlight { return false }
        operationInFlight = true
        return true
    }
    private func endOperation() {
        operationInFlight = false
        refreshDerived()
        publish()
    }
    private func isVolumeMissing() -> Bool {
        guard let mount = volume else { return false }
        // If the mount table cannot be read, the volume is assumed to be present.
        guard let mounts = try? resolver.allMounts() else { return false }
        return !mounts.contains { $0.mountPoint == mount.mountPoint }
    }
    private func applyMountMissing() {
        model = model.applying(discovery: state, proceeded: proceeded, mountMissing: true)
        model.locks = []
        model.banner = nil
        degraded = false
    }
    /// Recomputes the controls, the read-only lock set, and drops a choice that is no longer enabled.
    private func refreshDerived() {
        model.readOnlyLockIDs = Set(model.locks.filter { $0.user != currentUser }.map(\.id))
        let busy = model.isScanning || model.isStageRunning || model.isUnmounting || operationInFlight
        var controls = PhantomControls.derive(from: model, currentUser: currentUser, degraded: degraded, busy: busy)
        if model.window != .phantomTrace || !PhantomControls.isSelectable(model.choice, in: controls) {
            if !busy || model.window != .phantomTrace { model.choice = nil }
        }
        controls = PhantomControls.derive(from: model, currentUser: currentUser, degraded: degraded, busy: busy)
        model.controls = controls
    }
    private func publish() {
        for continuation in subscribers.values { continuation.yield(model) }
    }
    private static func asPhantomTraceError(_ error: any Error, input: URL) -> PhantomTraceError {
        if let known = error as? PhantomTraceError { return known }
        return .notAMountPoint(input)  // an unknown resolver error is reported as an unresolvable input
    }
    /// Plain text for the Failure_Banner. Names the kind of failure and avoids paths at default detail.
    static func describe(_ error: PhantomTraceError) -> String {
        switch error {
        case .notAMountPoint: return "the path is not on a mounted volume."
        case .protectedVolume: return "this volume is protected and is never scanned."
        case .lsofUnavailable: return "lsof is not available."
        case .lsofTimedOut(let seconds): return "lsof did not finish within \(Int(seconds)) seconds."
        case .commandTimedOut(let command, let seconds):
            return "\(command) did not finish within \(Int(seconds)) seconds."
        case .commandLaunchFailed(let command): return "\(command) could not be started."
        case .permissionDenied(let pid): return "permission denied for pid \(pid)."
        case .processIdentityChanged(let pid): return "pid \(pid) changed, so it was left alone."
        case .unmountBusy: return "the volume is still busy."
        case .unmountFailed(let code): return "the unmount failed (code \(code))."
        }
    }
}
