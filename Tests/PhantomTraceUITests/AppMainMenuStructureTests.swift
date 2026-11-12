import AppKit
import Foundation
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI
/// Property 29: the app has a standard main menu and no status-bar item. Built without launching
/// the app. Requirements 19.1, 19.13, 19.15.
@MainActor
struct AppMainMenuStructureTests {
    private func items(_ menu: AppMainMenuController, _ title: String) -> [NSMenuItem] {
        menu.mainMenu.items.first { $0.title == title }?.submenu?.items ?? []
    }
    private func key(_ items: [NSMenuItem], _ title: String) -> String? {
        items.first { $0.title == title }?.keyEquivalent
    }
    /// **Validates: Requirements 19.1**
    @Test func standardCommandsCarryTheirKeyEquivalents() {
        let menu = AppMainMenuController(chooseItem: { nil })
        #expect(key(items(menu, "PhantomTrace"), "Hide PhantomTrace") == "h")
        #expect(key(items(menu, "PhantomTrace"), "Quit PhantomTrace") == "q")
        #expect(key(items(menu, "File"), "Inspect\u{2026}") == "o")
        #expect(key(items(menu, "File"), "Close Window") == "w")
        #expect(key(items(menu, "Window"), "Minimize") == "m")
    }
    /// **Validates: Requirements 19.1, 19.3**
    @Test func fileMenuHoldsTheInspectVolumeSubmenu() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        let holder = try #require(items(menu, "File").first { $0.title == "Inspect Volume" })
        #expect(holder.submenu === menu.volumeMenu)
    }
    /// **Validates: Requirements 19.13**
    @Test func filledThenEmptiedListFallsBackToTheDisabledEmptyItem() {
        let menu = AppMainMenuController(chooseItem: { nil })
        menu.updateVolumes([VolumeListEntry(
            mountPoint: URL(fileURLWithPath: "/Volumes/A"), displayName: "A", isRemovable: true, isDiskImage: false
        )])
        menu.updateVolumes([])
        #expect(menu.volumeMenu.items.map(\.title) == [AppMainMenuController.emptyVolumesTitle])
        #expect(menu.volumeMenu.items.first?.isEnabled == false)
    }
    /// **Validates: Requirements 19.15**
    @Test func closeWindowClosesWithoutTerminating() throws {
        let menu = AppMainMenuController(chooseItem: { nil })
        var closed = 0
        menu.closeKeyWindow = { closed += 1 }
        let close = try #require(items(menu, "File").first { $0.title == "Close Window" })
        #expect(close.action == #selector(AppMainMenuController.closeWindow(_:)))
        #expect(close.action != #selector(NSApplication.terminate(_:)))
        menu.closeWindow(nil)
        #expect(closed == 1)
    }
    /// Property 29: no source file creates a status-bar item. **Validates: Requirements 19.1**
    @Test func noSourceFileCreatesAStatusBarItem() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var checked = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("statusItem(withLength"), "\(file.lastPathComponent) creates a status item")
            #expect(!text.contains("NSStatusBar"), "\(file.lastPathComponent) uses NSStatusBar")
            checked += 1
        }
        #expect(checked > 20)
    }
}
