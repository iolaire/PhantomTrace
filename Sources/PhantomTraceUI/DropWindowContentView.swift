import AppKit
import PhantomTraceCore
/// The PhantomTrace main (drop) window's content, drawn in the same frame art as the lock windows:
/// the drop target on top and the Volume_List below it, with the yellow Ghost_Mascot hanging past
/// the right edge as on the other windows. Requirements 12.2, 13.9, 13.16, 19.3.
/// The app wires `dropTarget.onDrop` and `volumeList.onInspect` to the same `InspectRequestRouter`,
/// so a picked volume and a dropped one take the same path.
@MainActor
public final class DropWindowContentView: NSView {
    public static let plaqueTitle = "PHANTOMTRACE"
    /// The frame art itself, the same size as the lock windows; the interior is 460 x 331.
    public static let chromeSize = LockWindowContentView.chromeSize
    /// The NSWindow size: the chrome plus the transparent strip the ghost overhangs.
    public static let contentSize = NSSize(
        width: chromeSize.width + LockWindowContentView.ghostOverhang, height: chromeSize.height
    )
    static let dropTargetHeight: CGFloat = 100
    public let chrome: PlatinumWindowChromeView
    public let dropTarget = DropTargetView(frame: NSRect(x: 0, y: 0, width: 440, height: 100))
    public let volumeList: VolumeListView
    public let ghostView = NSImageView()
    /// The close box: closes the window without quitting (Requirement 19.15).
    public var onClose: (() -> Void)?
    public init(resourceDirectory: URL? = Bundle.main.resourceURL) {
        chrome = ArtChrome.make(title: Self.plaqueTitle, resourceDirectory: resourceDirectory)
        volumeList = VolumeListView(fontProvider: FontProvider(resourceDirectory: resourceDirectory))
        super.init(frame: NSRect(origin: .zero, size: Self.contentSize))
        build()
        ghostView.image = SpriteLoader(resourceDirectory: resourceDirectory)
            .image(named: WindowAppearance.ghostSpriteName(for: .yellow))
        ghostView.setAccessibilityElement(true)
        ghostView.setAccessibilityRole(.image)
        ghostView.setAccessibilityLabel(AccessibilityText.ghostLabel(for: .yellow))
    }
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    @objc private func closePressed(_ sender: Any?) { onClose?() }
    private func build() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)
        chrome.closeBox.target = self
        chrome.closeBox.action = #selector(closePressed(_:))
        chrome.closeBox.setAccessibilityLabel("Close window")
        let host = chrome.contentView
        for view in [dropTarget, volumeList] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(view)
        }
        ghostView.imageScaling = .scaleProportionallyUpOrDown
        ghostView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ghostView)
        let ghost = LockWindowContentView.ghostSize
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: leadingAnchor),
            chrome.topAnchor.constraint(equalTo: topAnchor),
            chrome.bottomAnchor.constraint(equalTo: bottomAnchor),
            chrome.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LockWindowContentView.ghostOverhang),
            dropTarget.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12),
            dropTarget.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -12),
            dropTarget.topAnchor.constraint(equalTo: host.topAnchor, constant: 8),
            dropTarget.heightAnchor.constraint(equalToConstant: Self.dropTargetHeight),
            volumeList.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12),
            volumeList.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -12),
            volumeList.topAnchor.constraint(equalTo: dropTarget.bottomAnchor, constant: 12),
            volumeList.bottomAnchor.constraint(lessThanOrEqualTo: host.bottomAnchor, constant: -12),
            ghostView.widthAnchor.constraint(equalToConstant: ghost.width),
            ghostView.heightAnchor.constraint(equalToConstant: ghost.height),
            ghostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ghostView.topAnchor.constraint(equalTo: topAnchor, constant: LockWindowContentView.ghostTop)
        ])
    }
}
