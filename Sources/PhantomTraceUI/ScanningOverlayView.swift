import AppKit

/// The Scanning_Overlay: a progress indicator drawn inside the current sheet. It never changes the
/// window or the ghost (Requirement 18.5). Requirements 9.2, 18.7.
@MainActor
public final class ScanningOverlayView: NSView {
    /// For the first scan the frame and overlay appear only after this delay (PROVISIONAL, Req 18.7).
    public static let firstScanDelay: Duration = .milliseconds(500)

    private let spinner = NSProgressIndicator()
    private let label = NSTextField(labelWithString: "Scanning for locks...")
    private var firstScanTask: Task<Void, Never>?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    isolated deinit {
        firstScanTask?.cancel()
    }

    /// Shows or hides the overlay. With `isFirstScan` the overlay waits `firstScanDelay` and is
    /// skipped when the scan ends first.
    public func setScanning(_ scanning: Bool, isFirstScan: Bool = false) {
        firstScanTask?.cancel()
        firstScanTask = nil
        guard scanning else {
            hide()
            return
        }
        guard isFirstScan else {
            show()
            return
        }
        firstScanTask = Task { [weak self] in
            try? await Task.sleep(for: Self.firstScanDelay)
            guard !Task.isCancelled else { return }
            self?.show()
        }
    }

    /// Lets clicks through to nothing while scanning, so the sheet below cannot be acted on.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        isHidden ? nil : super.hitTest(point)
    }

    /// Reduce Motion (Requirement 13.14): the spinner stays visible but does not animate.
    public var motion = MotionPolicy(reduceMotion: false) {
        didSet {
            guard !isHidden else { return }
            if motion.animatesSpinners { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
        }
    }

    private func show() {
        isHidden = false
        if motion.animatesSpinners { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }

    private func hide() {
        isHidden = true
        spinner.stopAnimation(nil)
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = true
        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Scanning for locks")
        isHidden = true
    }
}
