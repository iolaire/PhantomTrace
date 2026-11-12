import AppKit
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI
@MainActor
struct VolumeListViewTests {
    private func entry(_ name: String, _ path: String, removable: Bool = true) -> VolumeListEntry {
        VolumeListEntry(
            mountPoint: URL(fileURLWithPath: path), displayName: name, isRemovable: removable, isDiskImage: false
        )
    }
    private func recordingList() -> (VolumeListView, Recorder) {
        let view = VolumeListView()
        let recorder = Recorder()
        view.onInspect = { recorder.entries.append($0) }
        return (view, recorder)
    }
    private final class Recorder {
        var entries: [VolumeListEntry] = []
    }
    private func key(_ code: UInt16) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code
        ))
    }
    @Test func rowsFollowTheGivenOrder() {
        let view = VolumeListView()
        let given = [entry("Flash1GB", "/Volumes/Flash1GB"), entry("Archive", "/Volumes/Archive", removable: false)]
        view.update(entries: given)
        #expect(view.entries == given)
        #expect(view.rows.count == 2)
        #expect(view.emptyLabel.isHidden)
    }
    @Test func emptyListShowsTheMessageInPlaceOfTheList() {
        let view = VolumeListView()
        view.update(entries: [])
        #expect(!view.emptyLabel.isHidden)
        #expect(view.emptyLabel.stringValue == "No volumes available to inspect")
        #expect(view.rows.isEmpty)
    }
    @Test func enumerationFailureKeepsThePreviousListAndSuccessClearsTheMessage() {
        let view = VolumeListView()
        let first = [entry("Flash1GB", "/Volumes/Flash1GB")]
        view.update(state: VolumeRefreshState(entries: first, enumerationFailed: false))
        #expect(view.failureLabel.isHidden)
        view.update(state: VolumeRefreshState(entries: first, enumerationFailed: true))
        #expect(!view.failureLabel.isHidden)
        #expect(view.failureLabel.stringValue == "Couldn't read the list of volumes")
        #expect(view.entries == first)
        let next = [entry("Other", "/Volumes/Other")]
        view.update(state: VolumeRefreshState(entries: next, enumerationFailed: false))
        #expect(view.failureLabel.isHidden)
        #expect(view.entries == next)
    }
    @Test func rowAndButtonLabelsNameTheVolumeInWords() throws {
        let view = VolumeListView()
        view.update(entries: [entry("Flash1GB", "/Volumes/Flash1GB"), entry("Mac", "/Volumes/Mac", removable: false)])
        let removable = try #require(view.rows.first)
        let internalRow = try #require(view.rows.last)
        #expect(removable.accessibilityLabel() == "Flash1GB, /Volumes/Flash1GB, removable")
        #expect(removable.accessibilityValue() as? String == "/Volumes/Flash1GB")
        #expect(removable.inspectButton.accessibilityLabel() == "Inspect Flash1GB")
        #expect(internalRow.accessibilityLabel() == "Mac, /Volumes/Mac, internal")
        #expect(VolumeListRowView.markerText(for: removable.entry).hasSuffix("Removable"))
        #expect(VolumeListRowView.markerText(for: internalRow.entry).hasSuffix("Internal"))
    }
    @Test func inspectButtonDeliversTheEntryExactlyOnce() throws {
        let (view, recorder) = recordingList()
        let flash = entry("Flash1GB", "/Volumes/Flash1GB")
        view.update(entries: [flash])
        try #require(view.rows.first).inspectButton.performClick(nil)
        #expect(recorder.entries == [flash])
    }
    @Test func returnAndSpaceOnARowDeliverTheEntryOncePerPress() throws {
        let (view, recorder) = recordingList()
        let flash = entry("Flash1GB", "/Volumes/Flash1GB")
        view.update(entries: [flash])
        let row = try #require(view.rows.first)
        row.keyDown(with: try key(36))
        row.keyDown(with: try key(49))
        #expect(recorder.entries == [flash, flash])
    }
    @Test func arrowKeysDoNotInspect() throws {
        let (view, recorder) = recordingList()
        view.update(entries: [entry("A", "/Volumes/A"), entry("B", "/Volumes/B")])
        try #require(view.rows.first).keyDown(with: try key(125))
        #expect(recorder.entries.isEmpty)
    }
    @Test func rejectionReasonIsShownAndCleared() {
        let view = VolumeListView()
        view.showRejection("the path does not exist.")
        #expect(!view.rejectionLabel.isHidden)
        #expect(view.rejectionLabel.stringValue.contains("the path does not exist."))
        view.showRejection(nil)
        #expect(view.rejectionLabel.isHidden)
    }
    @Test func dropWindowHoldsTheDropTargetBesideTheList() {
        let content = DropWindowContentView()
        #expect(content.dropTarget.superview === content)
        #expect(content.volumeList.superview === content)
    }
}
