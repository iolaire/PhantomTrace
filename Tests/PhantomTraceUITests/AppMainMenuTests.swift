import AppKit
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

@MainActor
struct AppMainMenuTests {
    private func entry(_ name: String, _ path: String, removable: Bool = true) -> VolumeListEntry {
        VolumeListEntry(
            mountPoint: URL(fileURLWithPath: path), displayName: name, isRemovable: removable, isDiskImage: false
        )
    }

    private func submenu(_ menu: AppMainMenuController, _ title: String) -> NSMenu? {
        menu.mainMenu.items.first { $0.title == title }?.submenu
    }

    @Test func menuHasAppFileAndWindowMenus() {
        let menu = AppMainMenuController(chooseItem: { nil })
        #expect(menu.mainMenu.items.map(\.title) == ["PhantomTrace", "File", "Window"])
    }

    @Test func quitIsCommandQAndTerminates() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        let quit = try #require(submenu(menu, "PhantomTrace")?.items.last)
        #expect(quit.title == "Quit PhantomTrace")
        #expect(quit.keyEquivalent == "q")
        #expect(quit.action == #selector(NSApplication.terminate(_:)))
        #expect(quit.target == nil)
    }

    @Test func hideOthersUsesOptionCommandH() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        let item = try #require(submenu(menu, "PhantomTrace")?.items.first { $0.title == "Hide Others" })
        #expect(item.keyEquivalent == "h")
        #expect(item.keyEquivalentModifierMask == [.command, .option])
    }

    @Test func emptyVolumeListShowsOneDisabledItem() {
        let menu = AppMainMenuController(chooseItem: { nil })
        menu.updateVolumes([])
        #expect(menu.volumeMenu.items.count == 1)
        #expect(menu.volumeMenu.items[0].title == AppMainMenuController.emptyVolumesTitle)
        #expect(!menu.volumeMenu.items[0].isEnabled)
    }

    @Test func volumeSubmenuKeepsOrderAndStoresMountPath() {
        let menu = AppMainMenuController(chooseItem: { nil })
        menu.updateVolumes([entry("Alpha", "/Volumes/Alpha"), entry("Beta", "/Volumes/Beta", removable: false)])
        let names = menu.volumeMenu.items.map {
            $0.attributedTitle?.string.split(separator: "\n").first.map(String.init)
        }
        #expect(names == ["Alpha", "Beta"])
        #expect(menu.volumeMenu.items[0].attributedTitle?.string.hasSuffix("Removable") == true)
        #expect(menu.volumeMenu.items.map { $0.representedObject as? String } == ["/Volumes/Alpha", "/Volumes/Beta"])
        #expect(menu.volumeMenu.items[0].toolTip == "/Volumes/Alpha")
    }

    @Test func closeWindowDisabledWithoutKeyWindow() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        let close = try #require(submenu(menu, "File")?.items.last)
        menu.hasKeyWindow = { false }
        #expect(!menu.validateMenuItem(close))
        menu.hasKeyWindow = { true }
        #expect(menu.validateMenuItem(close))
    }

    @Test func inspectItemsDisabledOnlyWhileRequestInFlight() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        let inspect = try #require(submenu(menu, "File")?.items.first)
        menu.isRequestInFlight = { true }
        #expect(!menu.validateMenuItem(inspect))
        menu.isRequestInFlight = { false }
        #expect(menu.validateMenuItem(inspect))
    }

    @Test func cancelledPanelRoutesNothing() {
        var panelShown = 0
        let menu = AppMainMenuController(chooseItem: { panelShown += 1; return nil })
        menu.inspectItem(nil)
        #expect(panelShown == 1)
    }

    @Test func chosenItemIsRoutedThroughRouter() {
        var accepted: [String] = []
        let router = InspectRequestRouter(
            parser: InspectURLParser(canonicalizer: PassThroughCanonicalizer()),
            onAccepted: { accepted.append($0) },
            onRejected: { _ in }
        )
        let menu = AppMainMenuController(chooseItem: { URL(fileURLWithPath: "/tmp") })
        menu.router = router
        menu.inspectItem(nil)
        #expect(accepted == ["/tmp"])
    }
}

private struct PassThroughCanonicalizer: InspectPathCanonicalizing {
    func canonicalPath(for path: String) -> String? { path }
}
