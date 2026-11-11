import AppKit
import Foundation
import Testing
@testable import PhantomTraceUI

@MainActor
struct SpriteLoaderTests {
    @Test
    func missingSpriteYieldsSubstituteAndNamesBothFiles() {
        let empty = URL(fileURLWithPath: "/nonexistent-phantomtrace-resources")
        let result = SpriteLoader(resourceDirectory: empty).load(named: "window-frame")
        #expect(result.isSubstitute)
        #expect(result.missingFiles == ["window-frame.png", "window-frame@2x.png"])
    }

    @Test
    func nilResourceDirectoryYieldsSubstitute() {
        let result = SpriteLoader(resourceDirectory: nil).load(named: "ghost")
        #expect(result.isSubstitute)
        #expect(result.image.accessibilityDescription == "ghost")
    }

    @Test
    func substituteUsesRequestedSize() {
        let loader = SpriteLoader(resourceDirectory: nil)
        let image = loader.image(named: "ghost", substituteSize: NSSize(width: 40, height: 30))
        #expect(image.size == NSSize(width: 40, height: 30))
    }

    @Test
    func corruptOneXFileYieldsSubstituteAndReportsIt() throws {
        let dir = try SpriteFixtureDirectory()
        try dir.writeCorrupt("ghost.png")
        try dir.writePNG("ghost@2x.png", pixelsWide: 20, pixelsHigh: 20)
        let result = SpriteLoader(resourceDirectory: dir.url).load(named: "ghost")
        #expect(result.isSubstitute)
        #expect(result.missingFiles == ["ghost.png"])
    }

    @Test
    func oneXAndTwoXAreComposedIntoOneImageAtTheOneXPointSize() throws {
        let dir = try SpriteFixtureDirectory()
        try dir.writePNG("ghost.png", pixelsWide: 10, pixelsHigh: 8)
        try dir.writePNG("ghost@2x.png", pixelsWide: 20, pixelsHigh: 16)
        let result = SpriteLoader(resourceDirectory: dir.url).load(named: "ghost")
        #expect(!result.isSubstitute)
        #expect(result.missingFiles.isEmpty)
        #expect(result.image.size == NSSize(width: 10, height: 8))
        let pixelWidths = result.image.representations.map(\.pixelsWide).sorted()
        #expect(pixelWidths == [10, 20])
    }

    @Test
    func missingTwoXKeepsOneXImageAndReportsTheGap() throws {
        let dir = try SpriteFixtureDirectory()
        try dir.writePNG("ghost.png", pixelsWide: 10, pixelsHigh: 8)
        let result = SpriteLoader(resourceDirectory: dir.url).load(named: "ghost")
        #expect(!result.isSubstitute)
        #expect(result.missingFiles == ["ghost@2x.png"])
        #expect(result.image.representations.count == 1)
    }

    @Test
    func corruptTwoXKeepsOneXImageAndReportsTheGap() throws {
        let dir = try SpriteFixtureDirectory()
        try dir.writePNG("ghost.png", pixelsWide: 10, pixelsHigh: 8)
        try dir.writeCorrupt("ghost@2x.png")
        let result = SpriteLoader(resourceDirectory: dir.url).load(named: "ghost")
        #expect(!result.isSubstitute)
        #expect(result.missingFiles == ["ghost@2x.png"])
    }
}

@MainActor
struct FontProviderTests {
    @Test
    func tableFontFallsBackToSystemMonospacedWhenNoneInstalled() {
        let provider = FontProvider(resourceDirectory: nil, lookup: { _, _ in nil })
        #expect(provider.tableFont(size: 12).isFixedPitch)
        #expect(provider.registeredTitleFontName == nil)
    }

    @Test
    func tableFontTriesMonacoThenMenlo() {
        var asked: [String] = []
        let provider = FontProvider(resourceDirectory: nil, lookup: { name, _ in
            asked.append(name)
            return nil
        })
        _ = provider.tableFont(size: 11)
        #expect(asked == ["Monaco", "Menlo"])
    }

    @Test
    func tableFontStopsAtMonacoWhenInstalled() {
        var asked: [String] = []
        let marker = NSFont.systemFont(ofSize: 17)
        let provider = FontProvider(resourceDirectory: nil, lookup: { name, _ in
            asked.append(name)
            return name == "Monaco" ? marker : nil
        })
        #expect(provider.tableFont(size: 11) === marker)
        #expect(asked == ["Monaco"])
    }

    @Test
    func tableFontUsesMenloWhenMonacoIsMissing() {
        let marker = NSFont.systemFont(ofSize: 17)
        let provider = FontProvider(resourceDirectory: nil, lookup: { name, _ in name == "Menlo" ? marker : nil })
        #expect(provider.tableFont(size: 11) === marker)
    }

    @Test
    func titleFontFallsBackToBoldSystemFontWhenNoFontFileIsPresent() throws {
        let dir = try SpriteFixtureDirectory()
        let provider = FontProvider(resourceDirectory: dir.url, lookup: { _, _ in nil })
        #expect(provider.registeredTitleFontName == nil)
        let font = provider.titleFont(size: 14)
        #expect(font.pointSize == 14)
        #expect(font == NSFont.systemFont(ofSize: 14, weight: .bold))
    }

    @Test
    func unreadableTitleFontFileFallsBackToSystemFont() throws {
        let dir = try SpriteFixtureDirectory()
        try dir.writeCorrupt("Title.ttf")
        let provider = FontProvider(resourceDirectory: dir.url, lookup: { _, _ in nil })
        #expect(provider.registeredTitleFontName == nil)
        #expect(provider.titleFont(size: 14) == NSFont.systemFont(ofSize: 14, weight: .bold))
    }
}
