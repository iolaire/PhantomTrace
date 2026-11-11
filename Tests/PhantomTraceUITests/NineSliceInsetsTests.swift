import Foundation
import Testing
@testable import PhantomTraceUI

struct NineSliceInsetsTests {
    private let insets = NineSliceInsets(top: 10, left: 20, bottom: 30, right: 40)

    @Test
    func interiorIsBoundsMinusInsets() {
        let interior = insets.interior(in: CGRect(x: 5, y: 7, width: 200, height: 100))
        #expect(interior == CGRect(x: 25, y: 37, width: 140, height: 60))
    }

    @Test
    func interiorIsNilWhenInsetsDoNotFit() {
        #expect(insets.interior(in: CGRect(x: 0, y: 0, width: 60, height: 100)) == nil)
        #expect(insets.interior(in: CGRect(x: 0, y: 0, width: 200, height: 40)) == nil)
    }

    @Test
    func slicesAreNineWithCenterLast() {
        let image = CGSize(width: 100, height: 100)
        let destination = CGRect(x: 0, y: 0, width: 300, height: 200)
        let slices = insets.slices(imageSize: image, destination: destination)
        #expect(slices.count == 9)
        let center = slices[8]
        #expect(center.source == CGRect(x: 20, y: 30, width: 40, height: 60))
        #expect(center.destination == CGRect(x: 20, y: 30, width: 240, height: 160))
    }

    @Test
    func cornersKeepTheirSizeWhenTheDestinationGrows() {
        let slices = insets.slices(
            imageSize: CGSize(width: 100, height: 100),
            destination: CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        // Row-major from bottom-left: index 0 bottom-left, 2 bottom-right, 5 top-right (center removed).
        #expect(slices[0].destination.size == CGSize(width: 20, height: 30))
        #expect(slices[0].destination.size == slices[0].source.size)
        #expect(slices[1].destination.size == CGSize(width: 440, height: 30))
        #expect(slices[2].destination.origin == CGPoint(x: 460, y: 0))
    }

    @Test
    func destinationSlicesTileTheDestinationExactly() {
        let destination = CGRect(x: 3, y: 4, width: 333, height: 211)
        let slices = insets.slices(imageSize: CGSize(width: 100, height: 100), destination: destination)
        let area = slices.reduce(0) { $0 + $1.destination.width * $1.destination.height }
        #expect(area == destination.width * destination.height)
        let union = slices.map(\.destination).reduce(CGRect.null) { $0.union($1) }
        #expect(union == destination)
    }

    @Test
    func slicesAreEmptyWhenImageOrDestinationIsTooSmall() {
        #expect(insets.slices(imageSize: CGSize(width: 60, height: 100),
                              destination: CGRect(x: 0, y: 0, width: 300, height: 200)).isEmpty)
        #expect(insets.slices(imageSize: CGSize(width: 100, height: 100),
                              destination: CGRect(x: 0, y: 0, width: 50, height: 200)).isEmpty)
    }

    @Test
    func loadReadsRecordedInsetsAndIgnoresExtraKeys() throws {
        let dir = try SpriteFixtureDirectory()
        let file = dir.url.appendingPathComponent("window-frame.insets.json")
        try Data(#"{"top":111,"left":130,"bottom":78,"right":130,"scale":1}"#.utf8).write(to: file)
        #expect(NineSliceInsets.load(from: file) == NineSliceInsets(top: 111, left: 130, bottom: 78, right: 130))
    }

    @Test
    func loadReturnsNilForMissingOrMalformedFile() throws {
        let dir = try SpriteFixtureDirectory()
        #expect(NineSliceInsets.load(from: dir.url.appendingPathComponent("absent.json")) == nil)
        let bad = dir.url.appendingPathComponent("bad.json")
        try Data("{".utf8).write(to: bad)
        #expect(NineSliceInsets.load(from: bad) == nil)
        let partial = dir.url.appendingPathComponent("partial.json")
        try Data(#"{"top":1}"#.utf8).write(to: partial)
        #expect(NineSliceInsets.load(from: partial) == nil)
    }
}
