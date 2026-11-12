import AppKit

/// A square Platinum close box. Requirement 17.14.
///
/// Over the frame art it is a transparent hit area laid exactly on the X square painted in the
/// art, so the user clicks the art's X; it only darkens while pressed and draws a focus ring for
/// keyboard users. Without art it draws its own 1 px outline and bevel.
@MainActor
public final class PlatinumCloseBox: NSControl {
    /// Side of the drawn box used with the plain (no-art) chrome.
    public static let side: CGFloat = 13

    /// The X square in `window-frame` at 1x, measured from the art's top-left corner.
    /// Measured from `window-frame@2x.png` (outline at x 22...72, y 21...72) and halved.
    public static let artSquare = CGRect(x: 11, y: 11, width: 25, height: 25)

    /// True when the box is a transparent overlay on the art's X.
    public let isOverlay: Bool
    private let boxSide: CGFloat
    private var isPressed = false

    /// - Parameter overlay: true to sit transparently on the art's X square.
    public init(overlay: Bool = false) {
        isOverlay = overlay
        boxSide = overlay ? Self.artSquare.width : Self.side
        super.init(frame: NSRect(x: 0, y: 0, width: boxSide, height: boxSide))
        focusRingType = .exterior
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Close window")
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("PlatinumCloseBox is created in code only")
    }

    override public var intrinsicContentSize: NSSize {
        NSSize(width: boxSide, height: boxSide)
    }

    override public var acceptsFirstResponder: Bool { true }

    override public var focusRingMaskBounds: NSRect { bounds }

    override public func drawFocusRingMask() {
        bounds.fill()
    }

    override public func draw(_ dirtyRect: NSRect) {
        if isOverlay {
            // The art already shows the X; give press feedback only.
            guard isPressed else { return }
            NSColor(white: 0, alpha: 0.25).setFill()
            bounds.fill()
            return
        }
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        (isPressed ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        rect.fill()
        NSColor.black.setStroke()
        NSBezierPath(rect: rect).stroke()
        drawBevel()
    }

    /// 1 px bevel: light top-left, dark bottom-right.
    private func drawBevel() {
        let inner = bounds.insetBy(dx: 1.5, dy: 1.5)
        let light = NSBezierPath()
        light.move(to: NSPoint(x: inner.minX, y: inner.minY))
        light.line(to: NSPoint(x: inner.minX, y: inner.maxY))
        light.line(to: NSPoint(x: inner.maxX, y: inner.maxY))
        NSColor.white.setStroke()
        light.stroke()
        let dark = NSBezierPath()
        dark.move(to: NSPoint(x: inner.minX, y: inner.minY))
        dark.line(to: NSPoint(x: inner.maxX, y: inner.minY))
        dark.line(to: NSPoint(x: inner.maxX, y: inner.maxY))
        NSColor(white: 0.5, alpha: 1).setStroke()
        dark.stroke()
    }

    override public func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        // Track until release; fire only when released inside, like a standard button.
        var inside = true
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            inside = bounds.contains(convert(next.locationInWindow, from: nil))
            isPressed = inside
            needsDisplay = true
            if next.type == .leftMouseUp { break }
        }
        isPressed = false
        needsDisplay = true
        if inside { sendAction(action, to: target) }
    }

    override public func keyDown(with event: NSEvent) {
        if event.characters == " " || event.keyCode == 36 {
            sendAction(action, to: target)
        } else {
            super.keyDown(with: event)
        }
    }

    override public func accessibilityPerformPress() -> Bool {
        sendAction(action, to: target)
        return true
    }
}
