import AppKit
/// A modal dialog drawn with the same frame art as the lock windows, in place of a system alert.
/// Shows a `PhantomDialogSpec`: plaque title, bold message, scrollable detail, and buttons.
/// Return activates the default button; Escape and the close box activate the cancel button.
/// Requirements 9.5, 10.8, 11.5, 13.9.
@MainActor
public final class PhantomDialog {
    /// The same size as the start and lock windows (no ghost strip).
    public static let size = LockWindowContentView.chromeSize
    /// Modal response codes are `responseBase + button index`, clear of AppKit's own codes.
    private static let responseBase = 2000
    public let spec: PhantomDialogSpec
    public let window: NSWindow
    /// Index 0 is the rightmost button, as in `spec.buttons`.
    public private(set) var buttons: [NSButton] = []
    public let messageLabel = NSTextField(wrappingLabelWithString: "")
    public let detailView = NSTextView()
    /// The index of the pressed button, once one is pressed.
    public private(set) var result: Int?
    let chrome: PlatinumWindowChromeView
    private let content = DialogContentView()
    public init(spec: PhantomDialogSpec, resourceDirectory: URL? = Bundle.main.resourceURL) {
        self.spec = spec
        chrome = ArtChrome.make(title: spec.plaque, resourceDirectory: resourceDirectory)
        let window = PlatinumWindow.make(size: Self.size)
        window.isMovableByWindowBackground = true
        self.window = window
        build(fontProvider: FontProvider(resourceDirectory: resourceDirectory))
        window.contentView = content
        window.setAccessibilityRole(.window)
        window.setAccessibilitySubrole(.dialog)
        window.setAccessibilityTitle("\(spec.plaque.capitalized): \(spec.message)")
    }
    /// Runs the dialog modally over `parent` (centered on it, or on screen) and returns the pressed
    /// button's index. The close box and Escape return `spec.cancelButton`.
    public func runModal(over parent: NSWindow? = nil) -> Int {
        place(over: parent)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(buttons[safe: spec.defaultButton])
        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        let index = response.rawValue - Self.responseBase
        return spec.buttons.indices.contains(index) ? index : spec.cancelButton
    }
    /// Presses the button at `index`, as a click would. Ends the modal session if one is running.
    public func press(_ index: Int) {
        result = index
        if NSApp.modalWindow === window {
            NSApp.stopModal(withCode: NSApplication.ModalResponse(
                rawValue: Self.responseBase + index))
        }
    }
    @objc private func buttonPressed(_ sender: NSButton) {
        press(sender.tag)
    }
    @objc private func closePressed(_ sender: Any?) {
        press(spec.cancelButton)
    }
    private func place(over parent: NSWindow?) {
        guard let parent, parent.isVisible else {
            window.center()
            return
        }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: parent.frame.midX - size.width / 2, y: parent.frame.midY - size.height / 2))
    }
    // MARK: Layout
    private func build(fontProvider: FontProvider) {
        content.frame = NSRect(origin: .zero, size: Self.size)
        content.onCancel = { [weak self] in
            guard let self else { return }
            self.press(self.spec.cancelButton)
        }
        chrome.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(chrome)
        pin(chrome, to: content)
        chrome.closeBox.target = self
        chrome.closeBox.action = #selector(closePressed(_:))
        chrome.closeBox.setAccessibilityLabel(spec.buttons[safe: spec.cancelButton] ?? "Cancel")
        configureText(fontProvider: fontProvider)
        buttons = spec.buttons.enumerated().map(makeButton)
        let footer = NSStackView(views: [NSView()] + buttons.reversed())
        footer.orientation = .horizontal
        footer.spacing = 8
        let scroll = NSScrollView()
        scroll.documentView = detailView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.borderType = .noBorder
        let stack = NSStackView(views: [messageLabel, scroll, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(stack)
        pin(stack, to: chrome.contentView)
        for row in [messageLabel, scroll, footer] as [NSView] {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        }
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
    }
    private func configureText(fontProvider: FontProvider) {
        messageLabel.stringValue = spec.message
        messageLabel.font = .boldSystemFont(ofSize: 13)
        // Meaning is in the words; the color only reinforces a destructive confirmation.
        let warning = NSColor(srgbRed: 0.5, green: 0, blue: 0, alpha: 1)
        messageLabel.textColor = spec.severity == .critical ? warning : .black
        detailView.string = spec.detail
        detailView.font = fontProvider.tableFont(size: 11)
        detailView.textColor = .black
        detailView.isEditable = false
        detailView.isSelectable = true
        detailView.drawsBackground = false
        detailView.isVerticallyResizable = true
        detailView.autoresizingMask = [.width]
        detailView.textContainer?.widthTracksTextView = true
        detailView.setAccessibilityLabel("Details")
    }
    private func makeButton(_ index: Int, _ title: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(buttonPressed(_:)))
        button.tag = index
        button.bezelStyle = .push
        if index == spec.defaultButton {
            button.keyEquivalent = "\r"
        } else if index == spec.cancelButton {
            button.keyEquivalent = "\u{1b}"
        }
        return button
    }
    private func pin(_ view: NSView, to container: NSView) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
/// Root view of the dialog: Escape cancels even when the cancel button is also the default.
private final class DialogContentView: NSView {
    var onCancel: (() -> Void)?
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
