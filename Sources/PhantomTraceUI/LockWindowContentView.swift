import AppKit
import PhantomTraceCore

/// The shared sheet for Cannot_Put_Away, Phantom_Trace and Volume_Released. It draws a
/// `WindowModel` and reports user intent through callbacks; it never talks to Core actors.
/// Requirements 2.4, 2.5, 18.6, 18.10, 18.11, 18.13, 18.15, 18.20, 18.21, 18.23, 18.24.
@MainActor
public final class LockWindowContentView: NSView {
    /// Size of the Platinum window itself (the frame art and everything inside it). Shared by the
    /// start (drop) window, the three lock windows, and the dialogs so they all match.
    public static let chromeSize = NSSize(width: 720, height: 520)
    /// Ghost size; the sprite is 115 x 128 at 1x and ships a 2x file, so this stays sharp.
    static let ghostSize = NSSize(width: 153, height: 170)
    /// About a third of the ghost hangs past the window's right edge, over transparency.
    static let ghostOverhang: CGFloat = 51
    /// Ghost top, measured down from the window top: just below the title bar.
    static let ghostTop: CGFloat = 40
    /// Box for the window illustration (shackled volume, CRT, shattered chains).
    static let illustrationBox: CGFloat = 150
    /// Gap between the illustration and the inner edges of the right and bottom ribbons in the
    /// art (those edges sit about 70 pt and 74 pt from the window's right and bottom edges).
    static let illustrationRightInset: CGFloat = 78
    static let illustrationBottomInset: CGFloat = 78
    /// Right padding the footer keeps so its buttons stay left of the illustration.
    static let footerClearance: CGFloat = 106
    /// The NSWindow size: the chrome plus the transparent strip the ghost overhangs.
    public static let preferredSize = NSSize(width: chromeSize.width + ghostOverhang, height: chromeSize.height)

    public var onProceed: (() -> Void)?
    public var onGoBack: (() -> Void)?
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
    public let goBackButton = ActionButton.goBack(target: nil, action: nil)
    public let forceButton = NSButton(title: "Force Unmount...", target: nil, action: nil)

    private let sprites: SpriteLoader
    private var imageCache: [String: NSImage] = [:]
    private let illustrationView = NSImageView()
    private let ghostView = NSImageView()
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    /// Keeps the lock table above the illustration; re-activated whenever the table is shown,
    /// because a stack view drops constraints of views it detaches while hidden.
    private var tableClearance: NSLayoutConstraint?
    /// Full-width rows of the content stack and their edge constraints, re-activated after a
    /// hidden row is re-attached by the stack view.
    private var rowViews: [NSView] = []
    private var rowEdges: [ObjectIdentifier: [NSLayoutConstraint]] = [:]
    private weak var contentStack: NSStackView?

    public init(resourceDirectory: URL? = Bundle.main.resourceURL) {
        sprites = SpriteLoader(resourceDirectory: resourceDirectory)
        lockTable = LockTableView(fontProvider: FontProvider(resourceDirectory: resourceDirectory))
        chrome = ArtChrome.make(title: "", resourceDirectory: resourceDirectory)
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
        needsUpdateConstraints = true
        let banner = isTrace ? model.banner : nil
        bannerView.update(
            banner: banner,
            kind: banner.map(WindowAppearance.bannerIsPartial) == true ? .partial : .failed,
            rescanEnabled: model.controls.rescanEnabled
        )
        failedList.update(list: isTrace ? model.failedActions : FailedActionList())
        proceedButton.updateProceed(from: model)
        goBackButton.updateGoBack(from: model)
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

    override public func updateConstraints() {
        let tableAttached = !lockTable.isHidden && lockTable.superview != nil
        if tableAttached, tableClearance?.isActive != true {
            let clearance = lockTable.bottomAnchor.constraint(
                lessThanOrEqualTo: illustrationView.topAnchor, constant: -8)
            clearance.priority = .defaultHigh
            clearance.isActive = true
            tableClearance = clearance
        }
        attachRowEdges()
        super.updateConstraints()
    }

    /// Pins each attached row to the stack's leading and trailing edges (12 pt inside).
    private func attachRowEdges() {
        guard let stack = contentStack else { return }
        for row in rowViews where row.superview === stack {
            let key = ObjectIdentifier(row)
            if let edges = rowEdges[key], edges.allSatisfy(\.isActive) { continue }
            let edges = [
                row.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12),
                row.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12)
            ]
            NSLayoutConstraint.activate(edges)
            rowEdges[key] = edges
        }
    }

    private func image(named name: String) -> NSImage {
        if let cached = imageCache[name] { return cached }
        let loaded = sprites.image(named: name)
        imageCache[name] = loaded
        return loaded
    }

    @objc private func proceedPressed(_ sender: Any?) { onProceed?() }

    @objc private func goBackPressed(_ sender: Any?) { onGoBack?() }

    @objc private func ejectPressed(_ sender: Any?) {
        onEject?(NSEvent.modifierFlags.contains(.option))
    }

    @objc private func forcePressed(_ sender: Any?) { onEject?(true) }

    @objc private func closePressed(_ sender: Any?) { onClose?() }

    private func build() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: leadingAnchor),
            chrome.topAnchor.constraint(equalTo: topAnchor),
            chrome.bottomAnchor.constraint(equalTo: bottomAnchor),
            chrome.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.ghostOverhang)
        ])
        connectControls()
        noteLabel.textColor = .darkGray
        for imageView in [illustrationView, ghostView] {
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
        }
        placeIllustration()
        let stack = makeStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(stack)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(overlay)
        pin(stack, to: chrome.contentView)
        pin(overlay, to: chrome.contentView)
        placeGhost()
    }

    private func connectControls() {
        chrome.closeBox.target = self
        chrome.closeBox.action = #selector(closePressed(_:))
        proceedButton.target = self
        proceedButton.action = #selector(proceedPressed(_:))
        goBackButton.target = self
        goBackButton.action = #selector(goBackPressed(_:))
        ejectButton.target = self
        ejectButton.action = #selector(ejectPressed(_:))
        forceButton.target = self
        forceButton.action = #selector(forcePressed(_:))
        forceButton.setAccessibilityLabel("Force unmount, advanced")
        bannerView.onRescan = { [weak self] in self?.onRescan?() }
        choiceControl.onSelect = { [weak self] choice in self?.onSelect?(choice) }
    }

    /// Lower right, above and left of the ribbon corner, behind the content (composed reference).
    private func placeIllustration() {
        chrome.addSubview(illustrationView, positioned: .below, relativeTo: chrome.contentView)
        NSLayoutConstraint.activate([
            illustrationView.widthAnchor.constraint(equalToConstant: Self.illustrationBox),
            illustrationView.heightAnchor.constraint(equalToConstant: Self.illustrationBox),
            illustrationView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor,
                                                       constant: -Self.illustrationRightInset),
            illustrationView.bottomAnchor.constraint(equalTo: chrome.bottomAnchor,
                                                     constant: -Self.illustrationBottomInset)
        ])
    }

    /// Top right, in front of everything, with about a third past the window's right edge.
    private func placeGhost() {
        addSubview(ghostView)
        NSLayoutConstraint.activate([
            ghostView.widthAnchor.constraint(equalToConstant: Self.ghostSize.width),
            ghostView.heightAnchor.constraint(equalToConstant: Self.ghostSize.height),
            ghostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ghostView.topAnchor.constraint(equalTo: topAnchor, constant: Self.ghostTop)
        ])
    }

    private func makeStack() -> NSStackView {
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(
            views: [goBackButton, noteLabel, footerSpacer, forceButton, ejectButton, proceedButton]
        )
        footer.orientation = .horizontal
        footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: Self.footerClearance)
        // The spacer takes the slack so the buttons stay right-aligned when the note is hidden.
        noteLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        // Takes the spare height so the footer sits at the bottom, beside the illustration. The
        // lock table hugs less, so in Phantom_Trace the table grows first.
        let bottomSpacer = NSView()
        bottomSpacer.setContentHuggingPriority(NSLayoutConstraint.Priority(200), for: .vertical)
        lockTable.setContentHuggingPriority(NSLayoutConstraint.Priority(150), for: .vertical)
        let rows: [NSView] = [messageLabel, lockTable, bannerView, failedList, choiceControl, bottomSpacer, footer]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.detachesHiddenViews = true
        rowViews = [messageLabel, lockTable, bannerView, failedList, footer]
        contentStack = stack
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)
        footer.setContentHuggingPriority(.required, for: .vertical)
        needsUpdateConstraints = true
        NSLayoutConstraint.activate([
            lockTable.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            failedList.heightAnchor.constraint(lessThanOrEqualToConstant: 70)
        ])
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
