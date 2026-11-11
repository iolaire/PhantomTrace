import Foundation

/// Slice insets of the shared `window-frame` art, in points at 1x, measured from each edge.
/// Recorded next to the sprite in `window-frame.insets.json`. Requirements 17.5, 17.6.
public struct NineSliceInsets: Codable, Equatable, Sendable {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// Reads the recorded insets file; nil when missing or malformed (callers then draw a plain chrome).
    public static func load(from url: URL) -> NineSliceInsets? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NineSliceInsets.self, from: data)
    }

    /// The rectangle left for content inside `bounds` (non-flipped coordinates), or nil when
    /// the insets do not fit.
    public func interior(in bounds: CGRect) -> CGRect? {
        let width = bounds.width - left - right
        let height = bounds.height - top - bottom
        guard width > 0, height > 0 else { return nil }
        return CGRect(x: bounds.minX + left, y: bounds.minY + bottom, width: width, height: height)
    }

    /// Source/destination rectangle pairs for the eight border slices, plus the center last.
    /// Coordinates are non-flipped (origin bottom-left) for both image and destination.
    /// Returns an empty array when either size is too small for fixed corners.
    public func slices(imageSize: CGSize, destination: CGRect) -> [(source: CGRect, destination: CGRect)] {
        guard imageSize.width > left + right, imageSize.height > top + bottom,
              destination.width >= left + right, destination.height >= top + bottom else { return [] }
        let srcX = [0, left, imageSize.width - right, imageSize.width]
        let srcY = [0, bottom, imageSize.height - top, imageSize.height]
        let dstX = [destination.minX, destination.minX + left, destination.maxX - right, destination.maxX]
        let dstY = [destination.minY, destination.minY + bottom, destination.maxY - top, destination.maxY]
        var result: [(source: CGRect, destination: CGRect)] = []
        for row in 0..<3 {
            for column in 0..<3 {
                let source = CGRect(x: srcX[column], y: srcY[row],
                                    width: srcX[column + 1] - srcX[column], height: srcY[row + 1] - srcY[row])
                let target = CGRect(x: dstX[column], y: dstY[row],
                                    width: dstX[column + 1] - dstX[column], height: dstY[row + 1] - dstY[row])
                result.append((source, target))
            }
        }
        // Row-major from the bottom-left; move the center (index 4) to the end so callers can skip it.
        let center = result.remove(at: 4)
        result.append(center)
        return result
    }
}
