import AppKit
import PhantomTraceCore
/// The drop window's Volume_List (Requirement 19, design Component 8a). Shows one
/// `VolumeListRowView` per entry, in the order given (the same order as the Inspect Volume
/// submenu), inside a 1px framed list. Shows the empty and enumeration-failure messages and a
/// router rejection reason. Never calls adapters or `MountResolver`: every activation goes to
/// `onInspect`, which the app connects to `InspectRequestRouter.handle(path:)`.
///
/// Updates swap rows without animation, so Reduce Motion needs no special case (Requirement 13.14).
@MainActor
public final class VolumeListView: NSView {
    /// Requirement 19.13.
    public static let emptyMessage = "No volumes available to inspect"
    /// Requirement 19.11.
    public static let failureMessage = "Couldn't read the list of volumes"
    /// Called with the activated entry, exactly once per activation. Requirement 19.8.
    public var onInspect: (@MainActor (VolumeListEntry) -> Void)?
    public private(set) var rows: [VolumeListRowView] = []
    public let emptyLabel = NSTextField(labelWithString: VolumeListView.emptyMessage)
    public let failureLabel = NSTextField(labelWithString: VolumeListView.failureMessage)
    public let rejectionLabel = NSTextField(wrappingLabelWithString: "")
    private let headerLabel = NSTextField(labelWithString: "Mounted volumes")
    private let scrollView = NSScrollView()
    private let rowStack = NSStackView()
    private let fontProvider: FontProvider
    public init(fontProvider: FontProvider = FontProvider()) {
        self.fontProvider = fontProvider
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        configure()
        update(entries: [])
    }
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    /// The entries shown, in display order.
    public var entries: [VolumeListEntry] { rows.map(\.entry) }
    /// Replaces the rows. An empty list shows `emptyMessage` in place of the list.
    public func update(entries: [VolumeListEntry]) {
        rows.forEach { $0.removeFromSuperview() }
        rows = entries.map(makeRow)
        rows.forEach { rowStack.addArrangedSubview($0) }
        for row in rows {
            row.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
        }
        emptyLabel.isHidden = !entries.isEmpty
        scrollView.isHidden = entries.isEmpty
        window?.recalculateKeyViewLoop()
    }
    /// Applies a refresh result. On failure the previous rows stay and the failure message shows;
    /// the next success clears it. Requirement 19.11.
    public func update(state: VolumeRefreshState) {
        if !state.enumerationFailed || rows.isEmpty {
            update(entries: state.entries)
        }
        failureLabel.isHidden = !state.enumerationFailed
    }
    /// Shows why the router rejected a selection, or clears it with nil. Requirement 19.12.
    public func showRejection(_ reason: String?) {
        rejectionLabel.stringValue = reason.map { "Can't inspect that volume: \($0)" } ?? ""
        rejectionLabel.isHidden = reason == nil
    }
    private func makeRow(_ entry: VolumeListEntry) -> VolumeListRowView {
        let row = VolumeListRowView(entry: entry, fontProvider: fontProvider)
        row.onActivate = { [weak self] entry in self?.onInspect?(entry) }
        row.onMoveFocus = { [weak self] row, delta in self?.moveFocus(from: row, by: delta) }
        return row
    }
    private func moveFocus(from row: VolumeListRowView, by delta: Int) {
        guard let index = rows.firstIndex(where: { $0 === row }) else { return }
        let target = index + delta
        guard rows.indices.contains(target) else { return }
        window?.makeFirstResponder(rows[target])
        rows[target].scrollToVisible(rows[target].bounds)
    }
    private func configure() {
        headerLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        for label in [emptyLabel, failureLabel] {
            label.font = fontProvider.tableFont(size: 11)
        }
        failureLabel.isHidden = true
        rejectionLabel.isHidden = true
        rejectionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rowStack)
        scrollView.documentView = document
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: document.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        layoutColumn()
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        setAccessibilityLabel("Mounted volumes")
    }
    private func layoutColumn() {
        let column = NSStackView(views: [headerLabel, failureLabel, emptyLabel, scrollView, rejectionLabel])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            scrollView.widthAnchor.constraint(equalTo: column.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: VolumeListRowView.rowHeight * 4 + 2),
            rejectionLabel.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
    }
}
/// Top-to-bottom document view so the first row sits at the top of the scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
