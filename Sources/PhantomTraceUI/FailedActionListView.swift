import AppKit
import PhantomTraceCore

/// The failed actions of the last stage: pid and error kind per entry, at most 500, with a count of
/// the rest. Also shows the no-eligible-Banish message. Requirements 9.3, 14.5.
@MainActor
public final class FailedActionListView: NSView {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Hides the view when there is nothing to report.
    /// - Parameter noEligibleBanish: the Banish stage had no process it may act on.
    public func update(list: FailedActionList, noEligibleBanish: Bool = false) {
        let text = Self.text(for: list, noEligibleBanish: noEligibleBanish)
        textView.string = text
        isHidden = text.isEmpty
        setAccessibilityLabel(text.isEmpty ? "No failed actions" : "Failed actions. \(list.entries.count) listed")
    }

    static func text(for list: FailedActionList, noEligibleBanish: Bool) -> String {
        var lines: [String] = []
        if noEligibleBanish {
            lines.append(StageMessages.noEligibleBanishProcesses)
        }
        lines.append(contentsOf: list.entries.map(StageMessages.describe))
        if let omitted = StageMessages.omittedActions(list.omittedCount) {
            lines.append(omitted)
        }
        return lines.joined(separator: "\n")
    }

    private func configure() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        isHidden = true
    }
}
