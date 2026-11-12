import AppKit
import PhantomTraceCore
/// One row of the drop window's Volume_List: name, middle-truncated mount point, a text
/// removable marker, and a square-edged Inspect button. Requirements 19.3, 19.8, 19.10.
///
/// The row itself takes keyboard focus (so arrow keys move between rows and Return or a
/// double-click inspects it), and its Inspect button stays in the key view loop for Tab and Space.
@MainActor
public final class VolumeListRowView: NSView {
    public static let rowHeight: CGFloat = 40
    /// Platinum selection highlight for the focused row.
    static let selectionColor = NSColor(srgbRed: 0.8, green: 0.8, blue: 1.0, alpha: 1)
    public let entry: VolumeListEntry
    public let inspectButton: NSButton
    /// Called once per activation (Inspect button, Return, Space on the row, or double-click).
    var onActivate: (@MainActor (VolumeListEntry) -> Void)?
    /// Asks the list to move focus by `delta` rows (arrow keys).
    var onMoveFocus: (@MainActor (VolumeListRowView, Int) -> Void)?
    private let nameLabel: NSTextField
    private let pathLabel: NSTextField
    private let markerLabel: NSTextField
    private var isFocused = false {
        didSet { needsDisplay = true }
    }
    /// "<name>, <mount point>, <removable|internal>". Requirement 19.10.
    public static func accessibilityLabel(for entry: VolumeListEntry) -> String {
        "\(entry.displayName), \(entry.mountPoint.path), \(entry.isRemovable ? "removable" : "internal")"
    }
    /// The visible marker: a glyph plus a word, never color alone. Requirement 19.3.
    public static func markerText(for entry: VolumeListEntry) -> String {
        entry.isRemovable ? "\u{23CF} Removable" : "\u{25A3} Internal"
    }
    public static func inspectLabel(for entry: VolumeListEntry) -> String {
        "Inspect \(entry.displayName)"
    }
    public init(entry: VolumeListEntry, fontProvider: FontProvider = FontProvider()) {
        self.entry = entry
        let font = fontProvider.tableFont(size: 12)
        nameLabel = NSTextField(labelWithString: entry.displayName)
        pathLabel = NSTextField(labelWithString: entry.mountPoint.path)
        markerLabel = NSTextField(labelWithString: Self.markerText(for: entry))
        inspectButton = NSButton(title: "Inspect", target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: Self.rowHeight))
        configureLabels(font: font)
        configureButton()
        layoutRow()
        configureAccessibility()
    }
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    /// Delivers this row's entry once.
    public func activate() {
        onActivate?(entry)
    }
    // MARK: Focus and keys
    override public var acceptsFirstResponder: Bool { true }
    override public var canBecomeKeyView: Bool { true }
    override public func becomeFirstResponder() -> Bool {
        isFocused = true
        return true
    }
    override public func resignFirstResponder() -> Bool {
        isFocused = false
        return true
    }
    override public func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76, 49: activate()  // Return, keypad Enter, Space
        case 125: onMoveFocus?(self, 1)  // down arrow
        case 126: onMoveFocus?(self, -1)  // up arrow
        default: super.keyDown(with: event)
        }
    }
    override public func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { activate() }
    }
    override public func drawFocusRingMask() {
        bounds.fill()
    }
    override public var focusRingMaskBounds: NSRect { bounds }
    override public func draw(_ dirtyRect: NSRect) {
        guard isFocused else { return }
        Self.selectionColor.setFill()
        bounds.fill()
    }
    // MARK: Setup
    private func configureLabels(font: NSFont) {
        nameLabel.font = font
        nameLabel.lineBreakMode = .byTruncatingTail
        pathLabel.font = smallFont(font)
        // Middle truncation keeps the volume's own name visible (Property 19); full path in the tooltip.
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.toolTip = entry.mountPoint.path
        markerLabel.font = smallFont(font)
        for label in [nameLabel, pathLabel, markerLabel] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setAccessibilityElement(false)
        }
        markerLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    private func smallFont(_ font: NSFont) -> NSFont {
        NSFont(descriptor: font.fontDescriptor, size: 10) ?? font
    }
    private func configureButton() {
        inspectButton.bezelStyle = .smallSquare
        inspectButton.target = self
        inspectButton.action = #selector(inspectPressed(_:))
        inspectButton.setAccessibilityLabel(Self.inspectLabel(for: entry))
        inspectButton.setAccessibilityHelp("Finds which programs are keeping this volume busy.")
        inspectButton.setContentHuggingPriority(.required, for: .horizontal)
    }
    @objc private func inspectPressed(_ sender: Any?) {
        activate()
    }
    private func layoutRow() {
        let text = NSStackView(views: [nameLabel, pathLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1
        // The spacer takes the slack so the marker and Inspect button line up at the right edge.
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [text, spacer, markerLabel, inspectButton])
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: Self.rowHeight)
        ])
    }
    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(Self.accessibilityLabel(for: entry))
        setAccessibilityValue(entry.mountPoint.path)
        toolTip = entry.mountPoint.path
    }
}
