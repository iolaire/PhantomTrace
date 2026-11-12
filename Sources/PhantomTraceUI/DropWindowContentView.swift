import AppKit
import PhantomTraceCore
/// The drop window's content: the drop target on the left and the Volume_List beside it.
/// Requirements 12.2, 19.3. The app wires `dropTarget.onDrop` and `volumeList.onInspect` to the
/// same `InspectRequestRouter`, so a picked volume and a dropped one take the same path.
@MainActor
public final class DropWindowContentView: NSView {
    public static let contentSize = NSSize(width: 640, height: 240)
    public let dropTarget = DropTargetView(frame: NSRect(x: 0, y: 0, width: 280, height: 200))
    public let volumeList: VolumeListView
    public init(fontProvider: FontProvider = FontProvider()) {
        volumeList = VolumeListView(fontProvider: fontProvider)
        super.init(frame: NSRect(origin: .zero, size: Self.contentSize))
        for view in [dropTarget, volumeList] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            dropTarget.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            dropTarget.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            dropTarget.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            dropTarget.widthAnchor.constraint(equalToConstant: 280),
            volumeList.leadingAnchor.constraint(equalTo: dropTarget.trailingAnchor, constant: 12),
            volumeList.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            volumeList.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            volumeList.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    /// Platinum gray behind both panes.
    override public func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.867, alpha: 1).setFill()
        bounds.fill()
    }
}
