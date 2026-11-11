import AppKit
import OSLog

/// The outcome of loading one sprite. Requirements 17.4, 17.7.
public struct SpriteLoadResult {
    public let image: NSImage
    /// True when the image is the system-drawn stand-in rather than the sprite files.
    public let isSubstitute: Bool
    /// File names that were missing or could not be decoded.
    public let missingFiles: [String]
}

/// Loads `name.png` (1x) and `name@2x.png` (2x) from a resource directory and composes them
/// into one `NSImage`. Never throws: a missing or corrupt 1x file yields a drawn substitute.
@MainActor
public struct SpriteLoader {
    private let resourceDirectory: URL?
    private let logger = Logger(subsystem: "com.phantomtrace.ui", category: "SpriteLoader")

    /// - Parameter resourceDirectory: defaults to `Bundle.main.resourceURL` (Requirement 17.1).
    public init(resourceDirectory: URL? = Bundle.main.resourceURL) {
        self.resourceDirectory = resourceDirectory
    }

    public func image(named name: String, substituteSize: NSSize = NSSize(width: 96, height: 96)) -> NSImage {
        load(named: name, substituteSize: substituteSize).image
    }

    public func load(named name: String, substituteSize: NSSize = NSSize(width: 96, height: 96)) -> SpriteLoadResult {
        var missing: [String] = []
        let oneX = "\(name).png"
        let twoX = "\(name)@2x.png"
        guard let rep1 = bitmap(file: oneX) else {
            missing.append(oneX)
            if bitmap(file: twoX) == nil { missing.append(twoX) }
            logger.error("Sprite file missing or unreadable: \(missing.joined(separator: ", "), privacy: .public)")
            return SpriteLoadResult(
                image: Self.substituteImage(label: name, size: substituteSize),
                isSubstitute: true,
                missingFiles: missing
            )
        }
        // Point size comes from the 1x file; both reps share it so AppKit picks by backing scale.
        let pointSize = NSSize(width: rep1.pixelsWide, height: rep1.pixelsHigh)
        rep1.size = pointSize
        let image = NSImage(size: pointSize)
        image.addRepresentation(rep1)
        if let rep2 = bitmap(file: twoX) {
            rep2.size = pointSize
            image.addRepresentation(rep2)
        } else {
            missing.append(twoX)
            logger.error("Sprite file missing or unreadable: \(twoX, privacy: .public)")
        }
        return SpriteLoadResult(image: image, isSubstitute: false, missingFiles: missing)
    }

    private func bitmap(file: String) -> NSBitmapImageRep? {
        guard let directory = resourceDirectory,
              let data = try? Data(contentsOf: directory.appendingPathComponent(file)),
              let rep = NSBitmapImageRep(data: data),
              rep.pixelsWide > 0, rep.pixelsHigh > 0 else {
            return nil
        }
        return rep
    }

    /// A bordered box with the sprite name, drawn at paint time.
    static func substituteImage(label: String, size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
            NSColor.secondaryLabelColor.setStroke()
            NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            NSAttributedString(string: label, attributes: attributes)
                .draw(in: rect.insetBy(dx: 4, dy: 4))
            return true
        }
        image.accessibilityDescription = label
        return image
    }
}
