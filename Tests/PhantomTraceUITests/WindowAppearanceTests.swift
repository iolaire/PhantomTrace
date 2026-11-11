import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

struct WindowAppearanceTests {
    @Test func ghostSpriteFollowsGhostColour() {
        #expect(WindowAppearance.ghostSpriteName(for: .yellow) == "ghost-looking-left-yellow")
        #expect(WindowAppearance.ghostSpriteName(for: .red) == "ghost-looking-left-red")
        #expect(WindowAppearance.ghostSpriteName(for: .green) == "ghost-looking-left-green")
    }

    @Test func eachWindowUsesItsTitleIllustrationAndGhost() {
        let cannot = WindowAppearance.appearance(for: .cannotPutAway)
        #expect(cannot == WindowAppearance(
            title: "CANNOT PUT AWAY",
            illustration: "shackled-volume-and-padlocks",
            ghost: "ghost-looking-left-yellow"
        ))
        let trace = WindowAppearance.appearance(for: .phantomTrace)
        #expect(trace.title == "PHANTOM TRACE")
        #expect(trace.illustration == "crt-diagnostic-portal")
        #expect(trace.ghost == "ghost-looking-left-red")
        let released = WindowAppearance.appearance(for: .volumeReleased)
        #expect(released.title == "VOLUME RELEASED")
        #expect(released.illustration == "shattered-chains-and-portullis")
        #expect(released.ghost == "ghost-looking-left-green")
    }

    @Test func releasedMessageDependsOnMountedState() {
        let mounted = WindowAppearance.message(for: .volumeReleased, volumeStillMounted: true)
        let gone = WindowAppearance.message(for: .volumeReleased, volumeStillMounted: false)
        #expect(mounted != gone)
        #expect(WindowAppearance.note(volumeStillMounted: true).contains("Finder"))
    }
}
