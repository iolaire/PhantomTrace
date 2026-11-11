import AppKit

/// Accepts dragged volumes and folders (file URLs) and forwards the first one.
/// Requirements 12.2, 12.10.
@MainActor
public final class DropTargetView: NSView {
    /// Called with the first dropped file URL.
    public var onDrop: (@MainActor (URL) -> Void)?
    public let promptLabel = NSTextField(labelWithString: "Drop a volume or folder here")
    private var highlighted = false {
        didSet { needsDisplay = true }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        promptLabel.alignment = .center
        promptLabel.lineBreakMode = .byTruncatingMiddle
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(promptLabel)
        NSLayoutConstraint.activate([
            promptLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            promptLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            promptLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
        setAccessibilityRole(.group)
        setAccessibilityLabel("Drop target. Drop a volume or folder to find what is keeping it busy.")
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func draw(_ dirtyRect: NSRect) {
        (highlighted ? NSColor.selectedContentBackgroundColor : NSColor(white: 0.867, alpha: 1)).setFill()
        bounds.fill()
        NSColor.black.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 8, dy: 8))
        border.setLineDash([6, 3], count: 2, phase: 0)
        border.lineWidth = 1
        border.stroke()
    }

    private func firstFileURL(_ sender: any NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first
    }

    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard firstFileURL(sender) != nil else { return [] }
        highlighted = true
        return .generic
    }

    override public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        highlighted = false
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        highlighted = false
        guard let url = firstFileURL(sender) else { return false }
        onDrop?(url)
        return true
    }
}
