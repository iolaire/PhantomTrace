import AppKit
import PhantomTraceCore

/// The Lock table: Process Name, PID, User, Lock Category, File Path in the Table_Font.
/// Requirements 13.1, 13.2, 13.5, 13.12, 13.13, 17.16.
@MainActor
public final class LockTableView: NSView {
    /// Shown when the volume is Blocked but no lock details could be retrieved (Requirement 13.13).
    public static let emptyMessage = "no lock details could be retrieved"
    static let dimmedAlpha: CGFloat = 0.4

    private let fontProvider: FontProvider
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: LockTableView.emptyMessage)
    private let dataSource: LockTableDataSource

    private var locks: [LockRecord] = []
    private var readOnlyIDs: Set<UUID> = []

    public init(fontProvider: FontProvider = FontProvider()) {
        self.fontProvider = fontProvider
        self.dataSource = LockTableDataSource(font: fontProvider.tableFont(size: 11))
        super.init(frame: .zero)
        configureTable()
        configureLayout()
        setAccessibilityLabel("Lock table")
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Replaces the rows. `showsEmptyMessage` is true when Blocked with no records.
    /// `isDimmed` is true while a Resolution_Stage runs (Requirement 13.5).
    public func update(
        locks: [LockRecord],
        readOnlyLockIDs: Set<UUID>,
        isDimmed: Bool,
        showsEmptyMessage: Bool
    ) {
        self.locks = locks
        self.readOnlyIDs = readOnlyLockIDs
        dataSource.locks = locks
        dataSource.readOnlyIDs = readOnlyLockIDs
        tableView.reloadData()
        scrollView.alphaValue = isDimmed ? Self.dimmedAlpha : 1
        emptyLabel.isHidden = !(showsEmptyMessage && locks.isEmpty)
    }

    /// Convenience: binds to a `WindowModel` (Blocked with no records shows the message).
    public func update(model: WindowModel) {
        update(
            locks: model.locks,
            readOnlyLockIDs: model.readOnlyLockIDs,
            isDimmed: model.isStageRunning,
            showsEmptyMessage: model.window == .phantomTrace
        )
    }

    /// Number of rows currently shown.
    public var rowCount: Int { locks.count }

    private func configureTable() {
        for column in LockTableColumn.allCases {
            let tableColumn = NSTableColumn(identifier: column.identifier)
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column.minWidth
            tableColumn.resizingMask = column == .path ? .autoresizingMask : .userResizingMask
            tableView.addTableColumn(tableColumn)
        }
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.usesAlternatingRowBackgroundColors = false
        // Clear, so the rows sit on the same gray as the rest of the frame interior.
        tableView.backgroundColor = .clear
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        // No opaque white corner square beside the header on the clear table.
        tableView.cornerView = nil
        tableView.rowHeight = 18
        tableView.setAccessibilityLabel("Locks holding the volume")
    }

    private func configureLayout() {
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = fontProvider.tableFont(size: 11)
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

/// The five columns, in display order (Requirement 13.1).
enum LockTableColumn: CaseIterable {
    case processName, pid, user, category, path

    var identifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("lock.\(self)") }

    var title: String {
        switch self {
        case .processName: "Process Name"
        case .pid: "PID"
        case .user: "User"
        case .category: "Lock Category"
        case .path: "File Path"
        }
    }

    var width: CGFloat {
        switch self {
        // Sized so all five columns fit the 760 pt chrome; File Path takes the rest.
        case .processName: 90
        case .pid: 50
        case .user: 64
        case .category: 84
        case .path: 140
        }
    }

    var minWidth: CGFloat { self == .path ? 100 : 40 }
}

/// Plain-language category names for display.
func lockCategoryTitle(_ category: LockCategory) -> String {
    switch category {
    case .cwd: "Working Directory"
    case .openFileHandle: "Open File"
    }
}

@MainActor
final class LockTableDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var locks: [LockRecord] = []
    var readOnlyIDs: Set<UUID> = []
    private let font: NSFont

    init(font: NSFont) {
        self.font = font
    }

    func numberOfRows(in tableView: NSTableView) -> Int { locks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard locks.indices.contains(row),
              let column = LockTableColumn.allCases.first(where: { $0.identifier == tableColumn?.identifier })
        else { return nil }
        let lock = locks[row]
        let cell = LockTableCellView(font: font)
        let readOnly = readOnlyIDs.contains(lock.id)
        switch column {
        case .processName: cell.configure(text: lock.processName, tooltip: lock.processName)
        case .pid: cell.configure(text: String(lock.pid), tooltip: nil)
        case .user:
            cell.configure(
                text: readOnly ? "\(lock.user) (read-only)" : lock.user,
                tooltip: readOnly ? "Owned by another user. Shown for information only; no action is taken." : nil,
                showsLock: readOnly
            )
        case .category: cell.configure(text: lockCategoryTitle(lock.category), tooltip: nil)
        case .path: cell.configure(text: lock.path, tooltip: lock.path, truncatesMiddle: true)
        }
        cell.setAccessibilityLabel("\(column.title): \(cell.displayedText)")
        return cell
    }
}

/// One table cell: optional lock icon plus text, middle-truncated for paths.
@MainActor
final class LockTableCellView: NSTableCellView {
    private let label = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let font: NSFont
    private var fullText = ""
    private var truncatesMiddle = false

    init(font: NSFont) {
        self.font = font
        super.init(frame: .zero)
        label.font = font
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isHidden = true
        addSubview(iconView)
        addSubview(label)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var displayedText: String { label.stringValue }

    func configure(text: String, tooltip: String?, showsLock: Bool = false, truncatesMiddle: Bool = false) {
        fullText = text
        self.truncatesMiddle = truncatesMiddle
        label.stringValue = text
        toolTip = tooltip
        iconView.isHidden = !showsLock
        if showsLock {
            iconView.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Read-only, other user")
            label.leadingConstraintShift(by: 14, in: self)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard truncatesMiddle else { return }
        let available = Double(max(0, label.frame.width))
        guard available > 0 else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        label.stringValue = PathTruncation.truncate(fullText, maxWidth: available) {
            Double(($0 as NSString).size(withAttributes: attributes).width)
        }
    }
}

private extension NSTextField {
    /// Moves the label right to make room for the lock icon.
    func leadingConstraintShift(by amount: CGFloat, in parent: NSView) {
        for constraint in parent.constraints where constraint.firstItem === self
            && constraint.firstAttribute == .leading {
            constraint.constant = amount + 4
        }
    }
}
