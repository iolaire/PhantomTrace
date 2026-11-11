import AppKit

/// A square Platinum close box: 1 px black outline with a bevel. Requirement 17.14.
@MainActor
public final class PlatinumCloseBox: NSControl {
    public static let side: CGFloat = 13
    private var isPressed = false

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Close window")
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("PlatinumCloseBox is created in code only")
    }

    override public var intrinsicContentSize: NSSize {
        NSSize(width: Self.side, height: Self.side)
    }

    override public var acceptsFirstResponder: Bool { true }

    override public func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        (isPressed ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        rect.fill()
        NSColor.black.setStroke()
        NSBezierPath(rect: rect).stroke()
        // 1 px bevel: light top-left, dark bottom-right.
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
