import AppKit
import PhantomTraceCore
import PhantomTraceUI

/// Launches with no window; windows appear only when input arrives. Requirement 17.14.
/// Input arrives through `phantomtrace://` URLs, the Services entry, the Dock icon, or the
/// drop window; all four go through `InspectRequestRouter`. There is no menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Begins resolution for a validated canonical path; connected to the window controller at launch.
    var onInspect: (@MainActor (String) -> Void)?

    private var windowController: LockWindowController?

    private var router: InspectRequestRouter?
    private var servicesProvider: InspectServicesProvider?
    private var dropWindow: NSWindow?
    private var dropView: DropTargetView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let router = InspectRequestRouter(
            parser: InspectURLParser(canonicalizer: LiveInspectPathCanonicalizer()),
            onAccepted: { [weak self] path in self?.accept(path) },
            onRejected: { [weak self] error in self?.reject(error) }
        )
        self.router = router
        let controller = AppComposition.makeWindowController()
        windowController = controller
        onInspect = { [weak controller] path in controller?.inspect(path: path) }
        let provider = InspectServicesProvider(router: router)
        servicesProvider = provider
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// `phantomtrace://` URLs, and files or folders dropped on the Dock icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        router?.handle(url: first)
    }

    /// Clicking the Dock icon with no window shows the drop window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showDropWindow() }
        return true
    }

    private func accept(_ path: String) {
        dropView?.promptLabel.stringValue = "Inspecting \(path)"
        if let onInspect {
            onInspect(path)
        } else {
            showDropWindow()
        }
    }

    private func reject(_ error: InspectURLError) {
        let alert = NSAlert()
        alert.messageText = "PhantomTrace could not inspect that item"
        alert.informativeText = error.reason
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showDropWindow() {
        if dropWindow == nil {
            let view = DropTargetView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))
            view.onDrop = { [weak self] url in self?.router?.handle(url: url) }
            let window = NSWindow(
                contentRect: view.frame,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "PhantomTrace"
            window.contentView = view
            window.isReleasedWhenClosed = false
            window.center()
            dropView = view
            dropWindow = window
        }
        dropWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
