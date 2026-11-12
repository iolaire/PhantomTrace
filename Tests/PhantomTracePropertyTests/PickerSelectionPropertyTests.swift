import AppKit
import Foundation
import PhantomTraceTestSupport
import PropertyBased
import Testing
@testable import PhantomTraceCore
@testable import PhantomTraceUI
/// Property 28: choosing a volume from the window list, the Inspect Volume submenu, or the
/// File > Inspect... panel delivers the same router input as dropping that mount point, exactly
/// once per choice, and touches nothing but the router's canonicalizer.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct PickerSelectionPropertyTests {
    private static let iterations = 500
    /// **Validates: Requirements 19.2, 19.8, 12.1, 12.3**
    @Test func pickerSelectionEqualsDrop() async {
        await propertyCheck(count: Self.iterations, input: entriesGenerator()) { entries in
            await MainActor.run { checkEverySource(entries) }
        }
    }
}
@MainActor
private final class Recorder {
    var accepted: [String] = []
    var rejected: [InspectURLError] = []
}
@MainActor
private func checkEverySource(_ entries: [VolumeListEntry]) {
    let paths = entries.map(\.mountPoint.path)
    let canonicalizer = MockInspectPathCanonicalizer(results: Dictionary(paths.map { ($0, $0) }) { first, _ in first })
    let recorder = Recorder()
    let router = InspectRequestRouter(
        parser: InspectURLParser(canonicalizer: canonicalizer),
        onAccepted: { recorder.accepted.append($0) },
        onRejected: { recorder.rejected.append($0) }
    )
    // The app's wiring: the list's activation goes to `handle(path:)`, like a drop of the mount point.
    let list = VolumeListView()
    list.onInspect = { router.handle(path: $0.mountPoint.path) }
    list.update(entries: entries)
    var chosen: URL?
    let menu = AppMainMenuController(chooseItem: { chosen })
    menu.router = router
    menu.updateVolumes(entries)
    for (index, entry) in entries.enumerated() {
        let url = entry.mountPoint
        router.handle(url: url)  // the drop
        guard let drop = recorder.accepted.last, recorder.accepted.count == 1 else {
            Issue.record("drop of \(url.path) was not accepted once")
            return
        }
        recorder.accepted = []
        list.rows[index].inspectButton.performClick(nil)
        menu.inspectVolume(menu.volumeMenu.items[index])
        chosen = url
        menu.inspectItem(nil)
        #expect(recorder.accepted == [drop, drop, drop])
        recorder.accepted = []
    }
    #expect(recorder.rejected.isEmpty)
    // Every call reached only the canonicalizer: four per entry (drop, list, submenu, panel).
    #expect(canonicalizer.calls.count == entries.count * 4)
}
private let volumeNames = ["Flash1GB", "A", "AB", "A B", "\u{E9}t\u{E9}", "\u{65E5}\u{672C}", "x-y", "50%", "Q&A"]
private func entriesGenerator() -> Generator<[VolumeListEntry], some SendableSequenceType> {
    zip(Gen.int(in: 0..<volumeNames.count), Gen.bool).array(of: 1...4).map { picks in
        var seen = Set<String>()
        return picks.compactMap { index, removable -> VolumeListEntry? in
            let name = volumeNames[index]
            guard seen.insert(name).inserted else { return nil }
            return VolumeListEntry(
                mountPoint: URL(fileURLWithPath: "/Volumes/\(name)"), displayName: name,
                isRemovable: removable, isDiskImage: false
            )
        }
    }
}
