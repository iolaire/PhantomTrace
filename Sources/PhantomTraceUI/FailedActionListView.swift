import AppKit
import PhantomTraceCore

/// The failed actions of the last stage: pid and error kind per entry, at most 500, with a count of
/// the rest. Also shows the no-eligible-Banish message and, for shells PhantomTrace could not move, the
/// `cd ~` the user should type. Requirements 7.5, 9.3, 14.5.
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
    /// - Parameters:
    ///   - manual: shells the user must move with `cd ~` themselves; listed first.
    ///   - noEligibleBanish: the Banish stage had no process it may act on.
    public func update(
        list: FailedActionList,
        manual: ManualActionList = ManualActionList(),
        noEligibleBanish: Bool = false
    ) {
        let text = Self.text(for: list, manual: manual, noEligibleBanish: noEligibleBanish)
        textView.string = text
        isHidden = text.isEmpty
        setAccessibilityLabel(Self.accessibilityLabel(failed: list.entries.count, manual: manual.entries.count))
    }

    static func text(
        for list: FailedActionList,
        manual: ManualActionList = ManualActionList(),
        noEligibleBanish: Bool
    ) -> String {
        var lines: [String] = []
        if noEligibleBanish {
            lines.append(StageMessages.noEligibleBanishProcesses)
        }
        lines.append(contentsOf: manual.entries.map(StageMessages.describe))
        if let omitted = StageMessages.omittedManualActions(manual.omittedCount) {
            lines.append(omitted)
        }
        lines.append(contentsOf: list.entries.map(StageMessages.describe))
        if let omitted = StageMessages.omittedActions(list.omittedCount) {
            lines.append(omitted)
        }
        return lines.joined(separator: "\n")
    }

    /// VoiceOver label that says what kind of results are listed and how many.
    static func accessibilityLabel(failed: Int, manual: Int) -> String {
        var parts: [String] = []
        if manual > 0 { parts.append("\(manual) shell\(manual == 1 ? "" : "s") to move by hand") }
        if failed > 0 { parts.append("\(failed) failed action\(failed == 1 ? "" : "s")") }
        return parts.isEmpty ? "No failed actions" : "Stage results. " + parts.joined(separator: ", ")
    }

    private func configure() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        // A text view made with a zero frame never grows on its own: let it track the scroll view's width
        // and grow vertically, or nothing is drawn.
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 2, height: 2)
        // Transparent, so the list sits on the window's grey like the lock table, not as a white block.
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
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
