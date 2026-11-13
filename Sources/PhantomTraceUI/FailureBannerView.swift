import AppKit
import PhantomTraceCore

/// Whether the scan failed outright or returned partial results.
public enum FailureBannerKind: Equatable, Sendable {
    case failed
    case partial
}

/// The Failure_Banner: states what went wrong, lists up to 100 Parse_Warnings with a count of the
/// rest, and offers Rescan. Requirements 14.1, 14.2, 18.26.
@MainActor
public final class FailureBannerView: NSView {
    /// Called when the user presses Rescan. The coordinator clears the banner when the run begins.
    public var onRescan: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let warningsView = NSTextView()
    private let scrollView = NSScrollView()
    private let rescanButton = NSButton(title: "Rescan", target: nil, action: nil)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Shows `banner`, or hides the view when it is nil.
    public func update(banner: Banner?, kind: FailureBannerKind, rescanEnabled: Bool) {
        guard let banner else {
            isHidden = true
            return
        }
        isHidden = false
        let title = kind == .failed ? "Scan failed" : "Partial results"
        titleLabel.stringValue = title
        messageLabel.stringValue = banner.message
        warningsView.string = Self.warningText(for: banner)
        scrollView.isHidden = warningsView.string.isEmpty
        rescanButton.isEnabled = rescanEnabled
        setAccessibilityLabel(AccessibilityText.bannerLabel(kind: kind, message: banner.message))
    }

    static func warningText(for banner: Banner) -> String {
        var lines = banner.warnings.map(StageMessages.describe)
        if let omitted = StageMessages.omittedWarnings(banner.omittedWarningCount) {
            lines.append(omitted)
        }
        return lines.joined(separator: "\n")
    }

    @objc private func rescanPressed(_ sender: Any?) {
        onRescan?()
    }

    private func configure() {
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        warningsView.isEditable = false
        warningsView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        warningsView.setAccessibilityLabel("Parse warnings")
        scrollView.documentView = warningsView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        rescanButton.target = self
        rescanButton.action = #selector(rescanPressed(_:))
        rescanButton.setAccessibilityLabel("Rescan the volume")
        let stack = NSStackView(views: [titleLabel, messageLabel, scrollView, rescanButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        isHidden = true
    }
}
