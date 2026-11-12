import AppKit
import PhantomTraceCore

/// Builds the programmatic main menu (PhantomTrace, File, Window) and owns the actions that need
/// app state. Requirements 19.1, 19.2, 19.3, 19.13, 19.15. No `NSStatusItem` is ever created.
///
/// Standard commands (About, Hide, Quit, Minimize, Bring All to Front) use responder-chain
/// selectors with a nil target, so `NSApp` handles them. Quit is `NSApplication.terminate(_:)`.
@MainActor
public final class AppMainMenuController: NSObject, NSMenuItemValidation {
    /// Shown, disabled, when the volume list is empty. Requirement 19.13.
    public static let emptyVolumesTitle = "No volumes available to inspect"

    /// Shows the open panel and returns the chosen URL, or nil on cancel. Presentation only: no scan.
    public typealias ItemChooser = @MainActor () -> URL?

    /// The router that receives every choice. Set once it exists; choices made before that are dropped.
    public var router: InspectRequestRouter?

    /// True while the router has a request in flight; disables the Inspect items. Requirement 19.8.
    public var isRequestInFlight: @MainActor () -> Bool = { false }

    /// True when a window is key; Close Window is disabled otherwise. Requirement 19.15.
    public var hasKeyWindow: @MainActor () -> Bool = { NSApp.keyWindow != nil }

    /// Closes the key window without quitting. Replaceable in tests.
    public var closeKeyWindow: @MainActor () -> Void = { NSApp.keyWindow?.performClose(nil) }

    public private(set) var mainMenu = NSMenu(title: "MainMenu")
    public private(set) var windowMenu = NSMenu(title: "Window")
    public private(set) var volumeMenu = NSMenu(title: "Inspect Volume")

    private let appName: String
    private let chooseItem: ItemChooser

    public init(
        appName: String = "PhantomTrace",
        chooseItem: @escaping ItemChooser = AppMainMenuController.runOpenPanel
    ) {
        self.appName = appName
        self.chooseItem = chooseItem
        super.init()
        buildMenu()
    }

    /// Installs the menu as the application's main menu and Window menu.
    public func install(on application: NSApplication) {
        application.mainMenu = mainMenu
        application.windowsMenu = windowMenu
    }

    /// Rebuilds the Inspect Volume submenu in the order given (same as the window list).
    public func updateVolumes(_ entries: [VolumeListEntry]) {
        volumeMenu.removeAllItems()
        guard !entries.isEmpty else {
            let item = NSMenuItem(title: Self.emptyVolumesTitle, action: nil, keyEquivalent: "")
            item.isEnabled = false
            volumeMenu.addItem(item)
            return
        }
        for entry in entries {
            volumeMenu.addItem(makeVolumeItem(entry))
        }
    }

    // MARK: Actions

    @objc public func inspectItem(_ sender: Any?) {
        guard let url = chooseItem() else { return }
        router?.handle(url: url)
    }

    @objc public func inspectVolume(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        router?.handle(path: path)
    }

    @objc public func closeWindow(_ sender: Any?) {
        closeKeyWindow()
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(closeWindow(_:)):
            return hasKeyWindow()
        case #selector(inspectItem(_:)), #selector(inspectVolume(_:)):
            return !isRequestInFlight()
        default:
            return true
        }
    }

    /// Single selection of a file, folder, or volume. Cancel returns nil.
    public static func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Inspect"
        panel.message = "Choose a file, folder, or volume to inspect."
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: Structure

    private func buildMenu() {
        mainMenu.addItem(submenuItem(buildAppMenu()))
        mainMenu.addItem(submenuItem(buildFileMenu()))
        buildWindowMenu()
        mainMenu.addItem(submenuItem(windowMenu))
        updateVolumes([])
    }

    private func buildAppMenu() -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem(item("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""))
        menu.addItem(.separator())
        menu.addItem(item("Hide \(appName)", #selector(NSApplication.hide(_:)), "h"))
        let hideOthers = item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:)), ""))
        menu.addItem(.separator())
        menu.addItem(item("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private func buildFileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        let inspect = item("Inspect\u{2026}", #selector(inspectItem(_:)), "o")
        inspect.target = self
        menu.addItem(inspect)
        let volumes = NSMenuItem(title: "Inspect Volume", action: nil, keyEquivalent: "")
        volumes.submenu = volumeMenu
        menu.addItem(volumes)
        menu.addItem(.separator())
        let close = item("Close Window", #selector(closeWindow(_:)), "w")
        close.target = self
        menu.addItem(close)
        return menu
    }

    private func buildWindowMenu() {
        windowMenu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        windowMenu.addItem(item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)), ""))
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    private func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let holder = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        return holder
    }

    private func makeVolumeItem(_ entry: VolumeListEntry) -> NSMenuItem {
        let path = entry.mountPoint.path
        let item = NSMenuItem(title: entry.displayName, action: #selector(inspectVolume(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = path
        item.toolTip = path
        let marker = entry.isRemovable ? "Removable" : "Internal"
        let title = NSMutableAttributedString(string: entry.displayName)
        title.append(NSAttributedString(
            string: "\n\(path) \u{2022} \(marker)",
            attributes: [
                .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        item.attributedTitle = title
        return item
    }
}
