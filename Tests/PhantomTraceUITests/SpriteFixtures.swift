import AppKit
import Foundation

/// A throwaway directory with generated PNGs, so sprite tests never read the real bundle.
final class SpriteFixtureDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phantomtrace-ui-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes a solid-color PNG of the given pixel size.
    func writePNG(_ name: String, pixelsWide: Int, pixelsHigh: Int) throws {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let data = rep.representation(using: .png, properties: [:]) else {
            throw FixtureError.encodingFailed
        }
        try data.write(to: url.appendingPathComponent(name))
    }

    /// Writes bytes that are not an image.
    func writeCorrupt(_ name: String) throws {
        try Data("not a png".utf8).write(to: url.appendingPathComponent(name))
    }

    enum FixtureError: Error {
        case encodingFailed
    }
}
