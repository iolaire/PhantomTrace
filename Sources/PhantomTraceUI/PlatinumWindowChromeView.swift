import AppKit

/// Platinum window chrome: #DDDDDD background, pinstripe title bar, 1 px bevels, square close box.
/// With frame art it draws the shared `window-frame` as a 9-slice and exposes `contentView`
/// pinned to the recorded interior rectangle. The title text is drawn by the app, never baked
/// into the art. Requirements 13.9, 17.5, 17.6, 17.14, 18.10, 18.13, 18.20.
@MainActor
public final class PlatinumWindowChromeView: NSView {
    /// Height of the plain pinstripe title bar used when no frame art is available.
    public static let plainTitleBarHeight: CGFloat = 22
    private static let bevelInset: CGFloat = 1

    /// Host for the table, buttons, and sprites.
    public let contentView = NSView()
    public let closeBox: PlatinumCloseBox
    public let titleLabel: NSTextField

    private let frameArt: NinePartImageView?
    private let insets: NineSliceInsets?

    /// - Parameters:
    ///   - title: plaque text, e.g. "CANNOT PUT AWAY".
    ///   - frameArt: the `window-frame` sprite; nil draws plain chrome.
    ///   - insets: recorded 9-slice insets for `frameArt`.
    ///   - titleFont: from `FontProvider.titleFont(size:)`.
    public init(title: String, frameArt: NSImage?, insets: NineSliceInsets?, titleFont: NSFont) {
        titleLabel = NSTextField(labelWithString: title)
        // With art the close box is a transparent hit area on the X painted in the art.
        closeBox = PlatinumCloseBox(overlay: frameArt != nil && insets != nil)
        if let frameArt, let insets {
            self.frameArt = NinePartImageView(image: frameArt, insets: insets)
            self.insets = insets
        } else {
            self.frameArt = nil
            self.insets = nil
        }
        super.init(frame: .zero)
        titleLabel.font = titleFont
        titleLabel.textColor = .black
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setAccessibilityRole(.staticText)
        setAccessibilityElement(false)
        buildHierarchy()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("PlatinumWindowChromeView is created in code only")
    }

    /// Title bar area in this view's (non-flipped) coordinates.
    public var titleBarRect: CGRect {
        let height = insets.map { min($0.top, bounds.height) } ?? Self.plainTitleBarHeight
        return CGRect(x: 0, y: bounds.maxY - height, width: bounds.width, height: height)
    }

    private func buildHierarchy() {
        for subview in [frameArt, contentView, titleLabel, closeBox].compactMap({ $0 }) {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        if let frameArt {
            NSLayoutConstraint.activate([
                frameArt.leadingAnchor.constraint(equalTo: leadingAnchor),
                frameArt.trailingAnchor.constraint(equalTo: trailingAnchor),
                frameArt.topAnchor.constraint(equalTo: topAnchor),
                frameArt.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        let edge = insets
        let barHeight = edge.map { CGFloat($0.top) } ?? Self.plainTitleBarHeight
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edge.map { CGFloat($0.left) } ?? 2),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor,
                                                  constant: -(edge.map { CGFloat($0.right) } ?? 2)),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: barHeight),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor,
                                                constant: -(edge.map { CGFloat($0.bottom) } ?? 2)),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: titleCenterOffset(barHeight)),
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.6),
            closeBox.widthAnchor.constraint(equalToConstant: closeBox.intrinsicContentSize.width),
            closeBox.heightAnchor.constraint(equalToConstant: closeBox.intrinsicContentSize.height)
        ])
        if edge == nil {
            NSLayoutConstraint.activate([
                closeBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                closeBox.centerYAnchor.constraint(equalTo: topAnchor, constant: barHeight / 2)
            ])
        } else {
            // The top-left corner slice is drawn unscaled, so the art's X stays at this offset.
            NSLayoutConstraint.activate([
                closeBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PlatinumCloseBox.artSquare.minX),
                closeBox.topAnchor.constraint(equalTo: topAnchor, constant: PlatinumCloseBox.artSquare.minY)
            ])
        }
    }

    /// Art frames carry a tall plaque area; the plaque text sits in its upper part.
    private func titleCenterOffset(_ barHeight: CGFloat) -> CGFloat {
        min(barHeight, 40) / 2 + (insets == nil ? 0 : 8)
    }

    override public func draw(_ dirtyRect: NSRect) {
        guard frameArt == nil else { return }
        NinePartImageView.platinum.setFill()
        bounds.fill()
        drawPinstripeTitleBar()
        drawBevelFrame()
    }

    private func drawPinstripeTitleBar() {
        let bar = titleBarRect
        NSColor.white.setFill()
        bar.fill()
        NSColor(white: 0.62, alpha: 1).setFill()
        var lineY = bar.minY + Self.bevelInset
        while lineY < bar.maxY - 1 {
            CGRect(x: bar.minX + 1, y: lineY, width: bar.width - 2, height: 1).fill()
            lineY += 2
        }
        // Plaque behind the title so the stripes do not run through the text.
        let plaqueWidth = min(titleLabel.fittingSize.width + 24, bar.width * 0.6)
        NinePartImageView.platinum.setFill()
        CGRect(x: bar.midX - plaqueWidth / 2, y: bar.minY + 2, width: plaqueWidth, height: bar.height - 4).fill()
        NSColor.black.setFill()
        CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 1).fill()
    }

    private func drawBevelFrame() {
        let outer = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor.black.setStroke()
        NSBezierPath(rect: outer).stroke()
        let lowerBody = CGRect(x: 1, y: 1, width: bounds.width - 2, height: titleBarRect.minY - 1)
        NSColor.white.setFill()
        CGRect(x: lowerBody.minX, y: lowerBody.maxY - 1, width: lowerBody.width, height: 1).fill()
        CGRect(x: lowerBody.minX, y: lowerBody.minY, width: 1, height: lowerBody.height).fill()
        NSColor(white: 0.5, alpha: 1).setFill()
        CGRect(x: lowerBody.minX, y: lowerBody.minY, width: lowerBody.width, height: 1).fill()
        CGRect(x: lowerBody.maxX - 1, y: lowerBody.minY, width: 1, height: lowerBody.height).fill()
    }
}
