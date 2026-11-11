import AppKit
import PhantomTraceCore

/// The shared sheet for Cannot_Put_Away, Phantom_Trace and Volume_Released. It draws a
/// `WindowModel` and reports user intent through callbacks; it never talks to Core actors.
/// Requirements 2.4, 2.5, 18.6, 18.10, 18.11, 18.13, 18.15, 18.20, 18.21, 18.23, 18.24.
@MainActor
public final class LockWindowContentView: NSView {
    public static let preferredSize = NSSize(width: 620, height: 560)

    public var onProceed: (() -> Void)?
    public var onEject: ((_ forced: Bool) -> Void)?
    public var onRescan: (() -> Void)?
    public var onSelect: ((PhantomChoice) -> Void)?
    public var onClose: (() -> Void)?

    public let chrome: PlatinumWindowChromeView
    public let lockTable: LockTableView
    public let choiceControl = PhantomChoiceControl()
    public let bannerView = FailureBannerView()
    public let failedList = FailedActionListView()
    public let overlay = ScanningOverlayView()
    public let proceedButton = ActionButton.proceed(target: nil, action: nil)
    public let ejectButton = ActionButton.eject(target: nil, action: nil)
    public let forceButton = NSButton(title: "Force Unmount...", target: nil, action: nil)

    private let sprites: SpriteLoader
    private var imageCache: [String: NSImage] = [:]
    private let illustrationView = NSImageView()
    private let ghostView = NSImageView()
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let noteLabel = NSTextField(wrappingLabelWithString: "")

    public init(resourceDirectory: URL? = Bundle.main.resourceURL) {
        let fonts = FontProvider(resourceDirectory: resourceDirectory)
        sprites = SpriteLoader(resourceDirectory: resourceDirectory)
        lockTable = LockTableView(fontProvider: fonts)
        let frame = sprites.load(named: "window-frame")
        let insets = resourceDirectory.flatMap {
            NineSliceInsets.load(from: $0.appendingPathComponent("window-frame.insets.json"))
        }
        let useArt = !frame.isSubstitute && insets != nil
        chrome = PlatinumWindowChromeView(
            title: "",
            frameArt: useArt ? frame.image : nil,
            insets: useArt ? insets : nil,
            titleFont: fonts.titleFont(size: 14)
        )
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
        build()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("LockWindowContentView is created in code only")
    }

    /// Redraws the sheet. A nil window means nothing is shown (PROVISIONAL, Req 18.6), so the
    /// caller hides the NSWindow and this view keeps its last content.
    public func apply(_ model: WindowModel) {
        guard let window = model.window else { return }
        let look = WindowAppearance.appearance(for: window)
        chrome.titleLabel.stringValue = look.title
        illustrationView.image = image(named: look.illustration)
        ghostView.image = image(named: look.ghost)
        messageLabel.stringValue = WindowAppearance.message(for: window, volumeStillMounted: model.volumeStillMounted)
        let isTrace = window == .phantomTrace
        lockTable.isHidden = !isTrace
        choiceControl.isHidden = !isTrace
        if isTrace {
            lockTable.update(model: model)
            choiceControl.update(from: model)
        }
        let banner = isTrace ? model.banner : nil
        bannerView.update(
            banner: banner,
            kind: banner.map(WindowAppearance.bannerIsPartial) == true ? .partial : .failed,
            rescanEnabled: model.controls.rescanEnabled
        )
        failedList.update(list: isTrace ? model.failedActions : FailedActionList())
        proceedButton.updateProceed(from: model)
        ejectButton.updateEject(from: model)
        let showEject = window == .volumeReleased && model.controls.ejectVisible
        forceButton.isHidden = !showEject
        forceButton.isEnabled = model.controls.ejectEnabled
        noteLabel.isHidden = window != .volumeReleased
        noteLabel.stringValue = WindowAppearance.note(volumeStillMounted: model.volumeStillMounted)
        overlay.setScanning(model.isScanning)
        applyAccessibility(window: window)
        applyMotion(MotionPolicy(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
    }

    /// Labels for the illustration and ghost; the message and note are static text and read as such.
    private func applyAccessibility(window: WindowState) {
        illustrationView.setAccessibilityElement(true)
        illustrationView.setAccessibilityRole(.image)
        illustrationView.setAccessibilityLabel(AccessibilityText.illustrationLabel(for: window))
        ghostView.setAccessibilityElement(true)
        ghostView.setAccessibilityRole(.image)
        ghostView.setAccessibilityLabel(AccessibilityText.ghostLabel(for: ghostFor(window)))
    }

    /// Requirement 13.14: sprites are static images already; spinners stop animating.
    private func applyMotion(_ policy: MotionPolicy) {
        overlay.motion = policy
        proceedButton.motion = policy
        ejectButton.motion = policy
    }

    private func image(named name: String) -> NSImage {
        if let cached = imageCache[name] { return cached }
        let loaded = sprites.image(named: name)
        imageCache[name] = loaded
        return loaded
    }

    @objc private func proceedPressed(_ sender: Any?) { onProceed?() }

    @objc private func ejectPressed(_ sender: Any?) {
        onEject?(NSEvent.modifierFlags.contains(.option))
    }

    @objc private func forcePressed(_ sender: Any?) { onEject?(true) }

    @objc private func closePressed(_ sender: Any?) { onClose?() }

    private func build() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)
        pin(chrome, to: self)
        chrome.closeBox.target = self
        chrome.closeBox.action = #selector(closePressed(_:))
        proceedButton.target = self
        proceedButton.action = #selector(proceedPressed(_:))
        ejectButton.target = self
        ejectButton.action = #selector(ejectPressed(_:))
        forceButton.target = self
        forceButton.action = #selector(forcePressed(_:))
        forceButton.setAccessibilityLabel("Force unmount, advanced")
        bannerView.onRescan = { [weak self] in self?.onRescan?() }
        choiceControl.onSelect = { [weak self] choice in self?.onSelect?(choice) }
        noteLabel.textColor = .darkGray
        for imageView in [illustrationView, ghostView] {
            imageView.imageScaling = .scaleProportionallyUpOrDown
        }
        let stack = makeStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(stack)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(overlay)
        pin(stack, to: chrome.contentView)
        pin(overlay, to: chrome.contentView)
    }

    private func makeStack() -> NSStackView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [illustrationView, spacer, ghostView])
        header.orientation = .horizontal
        let footer = NSStackView(views: [noteLabel, forceButton, ejectButton, proceedButton])
        footer.orientation = .horizontal
        footer.spacing = 8
        noteLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [header, messageLabel, lockTable, bannerView, failedList, choiceControl, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)
        var constraints = [
            illustrationView.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            illustrationView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            ghostView.widthAnchor.constraint(lessThanOrEqualToConstant: 72),
            ghostView.heightAnchor.constraint(lessThanOrEqualToConstant: 72),
            lockTable.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            failedList.heightAnchor.constraint(lessThanOrEqualToConstant: 70)
        ]
        for view in [header, messageLabel, lockTable, bannerView, failedList, footer] {
            constraints.append(view.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12))
            constraints.append(view.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12))
        }
        NSLayoutConstraint.activate(constraints)
        return stack
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
