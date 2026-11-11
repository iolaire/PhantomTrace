import AppKit
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

/// Table data logic without showing a window.
@MainActor
struct LockTableViewTests {
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    private func cellText(_ source: LockTableDataSource, _ column: LockTableColumn, row: Int) -> String? {
        let tableColumn = NSTableColumn(identifier: column.identifier)
        let cell = source.tableView(NSTableView(), viewFor: tableColumn, row: row) as? LockTableCellView
        return cell?.displayedText
    }

    @Test
    func columnsAreTheFiveSpecifiedOnesInOrder() {
        #expect(LockTableColumn.allCases.map(\.title)
            == ["Process Name", "PID", "User", "Lock Category", "File Path"])
        let identifiers = LockTableColumn.allCases.map(\.identifier)
        #expect(Set(identifiers).count == 5)
    }

    @Test
    func categoryTitlesArePlainLanguage() {
        #expect(lockCategoryTitle(.cwd) == "Working Directory")
        #expect(lockCategoryTitle(.openFileHandle) == "Open File")
    }

    @Test
    func dataSourceProducesOneCellTextPerColumn() {
        let source = LockTableDataSource(font: font)
        source.locks = [UITestData.lock(pid: 42, name: "Preview", user: "me", category: .cwd, path: "/Volumes/X/a b")]
        #expect(source.numberOfRows(in: NSTableView()) == 1)
        #expect(cellText(source, .processName, row: 0) == "Preview")
        #expect(cellText(source, .pid, row: 0) == "42")
        #expect(cellText(source, .user, row: 0) == "me")
        #expect(cellText(source, .category, row: 0) == "Working Directory")
        #expect(cellText(source, .path, row: 0) == "/Volumes/X/a b")
    }

    @Test
    func readOnlyLocksAreMarkedInTheUserColumnOnly() {
        let mine = UITestData.lock(pid: 1, user: "me")
        let theirs = UITestData.lock(pid: 2, user: "root")
        let source = LockTableDataSource(font: font)
        source.locks = [mine, theirs]
        source.readOnlyIDs = [theirs.id]
        #expect(cellText(source, .user, row: 0) == "me")
        #expect(cellText(source, .user, row: 1) == "root (read-only)")
        #expect(cellText(source, .processName, row: 1) == "proc")
    }

    @Test
    func outOfRangeRowAndUnknownColumnYieldNoCell() {
        let source = LockTableDataSource(font: font)
        source.locks = [UITestData.lock(pid: 1)]
        #expect(cellText(source, .pid, row: 5) == nil)
        #expect(cellText(source, .pid, row: -1) == nil)
        let unknown = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("other"))
        #expect(source.tableView(NSTableView(), viewFor: unknown, row: 0) == nil)
    }

    @Test
    func cellsCarryAccessibilityLabelsWithColumnAndValue() {
        let source = LockTableDataSource(font: font)
        source.locks = [UITestData.lock(pid: 7)]
        let column = NSTableColumn(identifier: LockTableColumn.pid.identifier)
        let cell = source.tableView(NSTableView(), viewFor: column, row: 0)
        #expect(cell?.accessibilityLabel() == "PID: 7")
    }

    @Test
    func updateSetsRowCountAndEmptyMessageOnlyWhenBlockedWithNoLocks() {
        let view = LockTableView(fontProvider: FontProvider(resourceDirectory: nil, lookup: { _, _ in nil }))
        #expect(view.rowCount == 0)
        view.update(locks: [UITestData.lock(pid: 1), UITestData.lock(pid: 2)],
                    readOnlyLockIDs: [], isDimmed: false, showsEmptyMessage: true)
        #expect(view.rowCount == 2)
        #expect(emptyLabel(in: view)?.isHidden == true)
        view.update(locks: [], readOnlyLockIDs: [], isDimmed: false, showsEmptyMessage: true)
        #expect(view.rowCount == 0)
        #expect(emptyLabel(in: view)?.isHidden == false)
        view.update(locks: [], readOnlyLockIDs: [], isDimmed: false, showsEmptyMessage: false)
        #expect(emptyLabel(in: view)?.isHidden == true)
    }

    @Test
    func dimmedWhileStageRunsAndBoundToTheModel() {
        let view = LockTableView(fontProvider: FontProvider(resourceDirectory: nil, lookup: { _, _ in nil }))
        let lock = UITestData.lock(pid: 3, user: "root")
        let running = WindowModel(
            window: .phantomTrace, locks: [lock], isStageRunning: true, readOnlyLockIDs: [lock.id]
        )
        view.update(model: running)
        #expect(view.rowCount == 1)
        #expect(scrollView(in: view)?.alphaValue == LockTableView.dimmedAlpha)
        view.update(model: WindowModel(window: .phantomTrace, locks: [lock]))
        #expect(scrollView(in: view)?.alphaValue == 1)
    }

    @Test
    func emptyMessageTextMatchesTheSpec() {
        #expect(LockTableView.emptyMessage == "no lock details could be retrieved")
    }

    private func emptyLabel(in view: LockTableView) -> NSTextField? {
        view.subviews.compactMap { $0 as? NSTextField }.first
    }

    private func scrollView(in view: LockTableView) -> NSScrollView? {
        view.subviews.compactMap { $0 as? NSScrollView }.first
    }
}
