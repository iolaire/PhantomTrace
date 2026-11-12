import AppKit
import PhantomTraceCore
import PhantomTraceUI
/// Composition of the running app. Input arrives through `phantomtrace://` URLs, the Services entry,
/// the Dock icon, the drop window, the volume list, and the File menu; all go through
/// `InspectRequestRouter`. There is an App_Main_Menu but no menu-bar status item (Requirement 19.1).
///
/// Launch with no input item shows the drop window with the volume list (Requirement 19.14); a launch
/// that brings a URL or file opens no drop window, as before (Requirement 17.14).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Begins resolution for a validated canonical path; connected to the window controller at launch.
    var onInspect: (@MainActor (String) -> Void)?
    private var windowController: LockWindowController?
    private var mainMenuController: AppMainMenuController?
    private var router: InspectRequestRouter?
    private var servicesProvider: InspectServicesProvider?
    private var volumeRefresh: VolumeRefreshController?
    private var dropWindow: NSWindow?
    private var dropContent: DropWindowContentView?
    /// Last refresh result, applied to the drop window when it is (re)created.
    private var volumeState = VolumeRefreshState()
    /// Set when any input item arrives, so the launch check does not open the drop window over it.
    private var receivedInput = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let router = InspectRequestRouter(
            parser: InspectURLParser(canonicalizer: LiveInspectPathCanonicalizer()),
            onAccepted: { [weak self] path in self?.accept(path) },
            onRejected: { [weak self] error in self?.reject(error) }
        )
        self.router = router
        let controller = AppComposition.makeWindowController()
        windowController = controller
        controller.anchorWindow = { [weak self] in self?.dropWindow }
        onInspect = { [weak controller] path in controller?.inspect(path: path) }
        installMenu(router: router, controller: controller)
        startVolumeRefresh()
        let provider = InspectServicesProvider(router: router)
        servicesProvider = provider
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
        // URL and file-open events from the launch can arrive just after this point; wait briefly so an
        // input item suppresses the drop window. 300 ms keeps the window well within 2000 ms.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !self.receivedInput else { return }
            self.showDropWindow()
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    /// `phantomtrace://` URLs, and files or folders dropped on the Dock icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        receivedInput = true
        router?.handle(url: first)
    }
    /// Clicking the Dock icon with no window shows the drop window. Requirement 19.15.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showDropWindow() }
        return true
    }
    private func installMenu(router: InspectRequestRouter, controller: LockWindowController) {
        let menu = AppMainMenuController()
        menu.router = router
        menu.isRequestInFlight = { [weak controller] in controller?.isInspecting ?? false }
        menu.install(on: NSApp)
        mainMenuController = menu
    }
    /// One list feeds both the drop window and the Inspect Volume submenu. Requirements 19.3, 19.9.
    private func startVolumeRefresh() {
        let refresh = AppComposition.makeVolumeRefresh { [weak self] state in
            guard let self else { return }
            self.volumeState = state
            self.dropContent?.volumeList.update(state: state)
            self.mainMenuController?.updateVolumes(state.entries)
        }
        volumeRefresh = refresh
        refresh.start()
        refresh.refreshNow()
    }
    private func accept(_ path: String) {
        receivedInput = true
        dropContent?.volumeList.showRejection(nil)
        dropContent?.dropTarget.promptLabel.stringValue = "Inspecting \(path)"
        if let onInspect {
            onInspect(path)
        } else {
            showDropWindow()
        }
    }
    private func reject(_ error: InspectURLError) {
        dropContent?.volumeList.showRejection(error.reason)
        let spec = StageDialogs.notice(message: "PhantomTrace could not inspect that item", detail: error.reason)
        _ = PhantomDialog(spec: spec).runModal(over: dropWindow)
    }
    private func showDropWindow() {
        if dropWindow == nil {
            let content = DropWindowContentView()
            content.dropTarget.onDrop = { [weak self] url in self?.router?.handle(url: url) }
            // Same call a drop of the mount point makes. Requirement 19.8.
            content.volumeList.onInspect = { [weak self] entry in self?.router?.handle(path: entry.mountPoint.path) }
            content.volumeList.update(state: volumeState)
            // Same frame art as the lock windows; Cmd-W and the close box hide it, and it is kept so
            // reopening is instant and nothing is cancelled.
            let window = PlatinumWindow.make(size: DropWindowContentView.contentSize)
            window.title = "PhantomTrace"
            window.contentView = content
            window.autorecalculatesKeyViewLoop = true
            content.onClose = { [weak window] in window?.performClose(nil) }
            window.center()
            dropContent = content
            dropWindow = window
        }
        volumeRefresh?.refreshNow()
        dropWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
