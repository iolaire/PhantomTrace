import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

struct AccessibilityTextTests {
    private let windows: [WindowState] = [.cannotPutAway, .phantomTrace, .volumeReleased]

    @Test func everyIllustrationHasANonEmptyDistinctLabel() {
        let labels = windows.map(AccessibilityText.illustrationLabel)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == windows.count)
    }

    @Test func everyGhostColourHasANonEmptyDistinctLabel() {
        let labels = [GhostState.yellow, .red, .green].map(AccessibilityText.ghostLabel)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == 3)
    }

    @Test func bannerLabelNamesKindAndMessage() {
        let failed = AccessibilityText.bannerLabel(kind: .failed, message: "lsof timed out")
        #expect(failed == "Scan failed. lsof timed out")
        #expect(AccessibilityText.bannerLabel(kind: .partial, message: "x") == "Partial results. x")
    }

    @Test func windowAnnouncementIncludesTitleAndMessage() {
        for window in windows {
            let text = AccessibilityText.windowAnnouncement(for: window, volumeStillMounted: true)
            #expect(text.lowercased().contains(WindowAppearance.title(for: window).lowercased()))
            #expect(!text.isEmpty)
        }
    }

    @Test func reduceMotionStopsSpinnersAndGlow() {
        #expect(!MotionPolicy(reduceMotion: true).animatesSpinners)
        #expect(!MotionPolicy(reduceMotion: true).animatesGlow)
        #expect(MotionPolicy(reduceMotion: false).animatesSpinners)
        #expect(MotionPolicy(reduceMotion: false).animatesGlow)
    }
}
