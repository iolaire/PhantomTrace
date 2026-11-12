import AppKit
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI
/// The art-framed dialog that replaces system alerts. Never run modally here.
@MainActor
struct PhantomDialogTests {
    private func preview() -> PhantomDialogSpec {
        StageDialogs.planPreview(ResolutionPlan(stage: .gracefulRequest, actions: [], skipped: []), locks: [])
    }
    @Test func dialogShowsThePlaqueMessageDetailAndButtons() {
        let dialog = PhantomDialog(spec: preview(), resourceDirectory: nil)
        #expect(dialog.buttons.map(\.title) == ["Ask to Quit", "Cancel"])
        #expect(dialog.messageLabel.stringValue == "Graceful Request: review the plan")
        #expect(dialog.detailView.string == "No actions will be taken.")
        #expect(!dialog.detailView.isEditable)
    }
    @Test func returnConfirmsAndEscapeCancelsThePlanPreview() {
        let dialog = PhantomDialog(spec: preview(), resourceDirectory: nil)
        #expect(dialog.buttons[0].keyEquivalent == "\r")
        #expect(dialog.buttons[1].keyEquivalent == "\u{1b}")
    }
    @Test func returnNeverConfirmsAForcedStop() {
        let plan = ResolutionPlan(stage: .banishLocks, actions: [UITestData.action(.sendSIGKILL, pid: 5)], skipped: [])
        let dialog = PhantomDialog(spec: StageDialogs.banishConfirmation(plan, locks: []), resourceDirectory: nil)
        #expect(dialog.buttons[0].title == "Cancel")
        #expect(dialog.buttons[0].keyEquivalent == "\r")
        #expect(dialog.buttons[1].keyEquivalent.isEmpty)
    }
    @Test func pressingAButtonRecordsItsIndex() {
        let dialog = PhantomDialog(spec: preview(), resourceDirectory: nil)
        dialog.buttons[1].performClick(nil)
        #expect(dialog.result == 1)
    }
    @Test func closeBoxCancels() {
        let dialog = PhantomDialog(spec: preview(), resourceDirectory: nil)
        _ = dialog.chrome.closeBox.accessibilityPerformPress()
        #expect(dialog.result == 1)
    }
}
