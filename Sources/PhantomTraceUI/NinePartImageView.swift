import AppKit

/// Draws an image as a 9-slice: fixed corners, stretched edges, and a center that is either
/// filled with platinum or left to the content. Requirements 17.5, 17.6, 18.10.
@MainActor
public final class NinePartImageView: NSView {
    public static let platinum = NSColor(srgbRed: 0xDD / 255, green: 0xDD / 255, blue: 0xDD / 255, alpha: 1)

    /// The gray at the center of the `window-frame` art (average of the center of
    /// `window-frame@2x.png`, RGB 193/193/188), so the content area blends into the frame.
    public static let artCenterGray = NSColor(srgbRed: 193 / 255, green: 193 / 255, blue: 188 / 255, alpha: 1)

    public var image: NSImage? {
        didSet { needsDisplay = true }
    }

    public var insets: NineSliceInsets {
        didSet { needsDisplay = true }
    }

    /// Paint the interior from the art's own center (stretched, smoothly interpolated) so the
    /// content background is the same gray as the frame design with no visible seam. When the
    /// center slice is unusable it falls back to a flat `artCenterGray` fill.
    public var fillsCenterWithPlatinum = true {
        didSet { needsDisplay = true }
    }

    public init(image: NSImage?, insets: NineSliceInsets) {
        self.image = image
        self.insets = insets
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("NinePartImageView is created in code only")
    }

    /// Where content belongs, in this view's coordinates.
    public var interiorRect: CGRect {
        insets.interior(in: bounds) ?? bounds
    }

    override public func draw(_ dirtyRect: NSRect) {
        guard let image else {
            Self.platinum.setFill()
            bounds.fill()
            return
        }
        let slices = insets.slices(imageSize: image.size, destination: bounds)
        guard slices.count == 9 else {
            Self.platinum.setFill()
            bounds.fill()
            return
        }
        if fillsCenterWithPlatinum, let center = slices.last {
            Self.artCenterGray.setFill()
            interiorRect.fill()
            image.draw(in: center.destination, from: center.source, operation: .sourceOver,
                       fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
        for slice in slices.dropLast() {
            image.draw(in: slice.destination, from: slice.source, operation: .sourceOver,
                       fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
    }
}
