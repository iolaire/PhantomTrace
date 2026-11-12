import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore
/// Properties 23-27: the volume picker's pure lister (design Component 8a, Requirement 19).
struct VolumeListerPropertyTests {
    private static let iterations = 500
    /// Property 23: no protected, hidden, or system mount is ever listed.
    /// **Validates: Requirements 19.4, 19.5, 2.1, 2.5**
    @Test func volumeListExcludesProtectedHiddenAndSystemMounts() async {
        await propertyCheck(count: Self.iterations, input: tableGenerator()) { table in
            let listed = Set(VolumeLister.list(table.mounts).map(\.mountPoint.path))
            let hidden = Set(table.rows.filter { !$0.isVisible }.map(\.canonicalPath))
            let visible = Set(table.rows.filter(\.isVisible).map(\.canonicalPath))
            // A canonical path can appear both hidden (e.g. devfs) and visible (apfs); only purely
            // hidden paths must be absent.
            #expect(listed.isDisjoint(with: hidden.subtracting(visible)))
            for path in listed {
                #expect(path != "/")
                #expect(!path.hasPrefix("/System/Volumes"))
                #expect(!path.hasPrefix("/private/var"))
                #expect(!path.contains("com.apple.TimeMachine.localsnapshots"))
                #expect(!(URL(fileURLWithPath: path).lastPathComponent.hasPrefix(".")))
            }
        }
    }
    /// Property 24: every mount not excluded is listed, with a non-empty display name.
    /// **Validates: Requirements 19.3, 19.6**
    @Test func volumeListIncludesEveryVisibleMount() async {
        await propertyCheck(count: Self.iterations, input: tableGenerator()) { table in
            let entries = VolumeLister.list(table.mounts)
            #expect(Set(entries.map(\.mountPoint.path)) == Set(table.rows.filter(\.isVisible).map(\.canonicalPath)))
            for entry in entries {
                #expect(!entry.displayName.isEmpty)
            }
        }
    }
    /// Property 25: listing is idempotent, and duplicating the table changes nothing.
    /// **Validates: Requirements 19.6**
    @Test func volumeListIsIdempotent() async {
        await propertyCheck(count: Self.iterations, input: tableGenerator()) { table in
            let once = VolumeLister.list(table.mounts)
            #expect(VolumeLister.list(mounts(from: once)) == once)
            #expect(VolumeLister.list(table.mounts + table.mounts) == once)
        }
    }
    /// Property 26: the result does not depend on input order and is sorted by the documented key.
    /// **Validates: Requirements 19.7**
    @Test func volumeListIsOrderIndependentAndSorted() async {
        await propertyCheck(count: Self.iterations, input: tableGenerator()) { table in
            let entries = VolumeLister.list(table.mounts)
            #expect(VolumeLister.list(table.shuffledMounts) == entries)
            #expect(VolumeLister.list(table.mounts.reversed()) == entries)
            for (lhs, rhs) in zip(entries, entries.dropFirst()) {
                #expect(!sortKey(rhs).lexicographicallyPrecedes(sortKey(lhs)))
            }
        }
    }
    /// Property 27: one entry per canonical mount point, even when spellings differ.
    /// **Validates: Requirements 19.6**
    @Test func volumeListDeduplicatesSpellingsOfOneMountPoint() async {
        await propertyCheck(count: Self.iterations, input: tableGenerator()) { table in
            let paths = VolumeLister.list(table.mounts).map(\.mountPoint.path)
            #expect(paths.count == Set(paths).count)
            for path in paths {
                #expect(path == "/" || !path.hasSuffix("/"))
                #expect(!path.split(separator: "/").contains("."))
            }
        }
    }
}
// MARK: - Generators and oracle
/// A base mount point and whether its path alone allows listing (independent of the lister).
private let basePaths: [(path: String, visible: Bool)] = [
    ("/Volumes/A", true), ("/Volumes/AB", true), ("/Volumes/a", true), ("/Volumes/A B", true),
    ("/Volumes/\u{E9}", true), ("/Volumes/e\u{301}x", true), ("/Volumes/\u{65E5}\u{672C}", true),
    ("/", false), ("/System/Volumes/Data", false), ("/System/Volumes/VM", false), ("/private/var/vm", false),
    ("/private/var/folders/x", false), ("/Volumes/.hidden", false),
    ("/Volumes/com.apple.TimeMachine.localsnapshots/Backups", false),
    ("/Volumes/X/com.apple.TimeMachine.localsnapshots", false)
]
/// Spellings of the same mount point; all normalize to the base path.
private let suffixes = ["", "/", "/.", "/./", "/Sibling/.."]
private let fileSystems: [(type: String, visible: Bool)] = [
    ("apfs", true), ("msdos", true), ("exfat", true), ("smbfs", true),
    ("devfs", false), ("autofs", false), ("nullfs", false), ("fdesc", false)
]
private let devices: [(node: String, visible: Bool)] = [
    ("/dev/disk4s1", true), ("/dev/disk5", true), ("map auto_home", false), ("//me@server/share", false)
]
private let names = ["", "A", "Zed", "zed", "\u{E9}"]
private struct Row: Sendable {
    let mount: MountInfo
    let canonicalPath: String
    let isVisible: Bool
}
private struct Table: Sendable {
    let rows: [Row]
    let order: [Int]
    var mounts: [MountInfo] { rows.map(\.mount) }
    /// A permutation of the rows, driven by generated keys.
    var shuffledMounts: [MountInfo] {
        zip(rows, order).sorted { $0.1 < $1.1 }.map(\.0.mount)
    }
}
private func spelled(_ base: String, _ suffix: String) -> String {
    base == "/" ? "/" : base + suffix
}
private func row(_ indices: [Int]) -> Row {
    let base = basePaths[indices[0] % basePaths.count]
    let suffix = suffixes[indices[1] % suffixes.count]
    let fileSystem = fileSystems[indices[2] % fileSystems.count]
    let device = devices[indices[3] % devices.count]
    let mount = MountInfo(
        mountPoint: URL(fileURLWithPath: spelled(base.path, suffix)),
        volumeName: names[indices[4] % names.count],
        deviceNode: device.node,
        fileSystemType: fileSystem.type,
        isInternal: indices[5] % 2 == 0,
        isRemovable: indices[5] % 3 == 0,
        isDiskImage: indices[5] % 5 == 0
    )
    return Row(mount: mount, canonicalPath: base.path, isVisible: base.visible && fileSystem.visible && device.visible)
}
private func tableGenerator() -> Generator<Table, some SendableSequenceType> {
    let rows = Gen.int(in: 0...999).array(of: 6...6).array(of: 0...12)
    let order = Gen.int(in: 0...999).array(of: 12...12)
    return zip(rows, order).map { rowIndices, order in
        Table(rows: rowIndices.map(row), order: order)
    }
}
/// Maps entries back to a mount table that keeps each entry visible.
private func mounts(from entries: [VolumeListEntry]) -> [MountInfo] {
    entries.enumerated().map { index, entry in
        MountInfo(
            mountPoint: entry.mountPoint, volumeName: entry.displayName, deviceNode: "/dev/disk\(index)s1",
            fileSystemType: "apfs", isInternal: !entry.isRemovable, isRemovable: entry.isRemovable,
            isDiskImage: entry.isDiskImage
        )
    }
}
private func sortKey(_ entry: VolumeListEntry) -> [[UInt8]] {
    [
        Array(entry.displayName.lowercased().precomposedStringWithCanonicalMapping.utf8),
        Array(entry.displayName.precomposedStringWithCanonicalMapping.utf8),
        Array(entry.mountPoint.path.utf8)
    ]
}
private extension Array where Element == [UInt8] {
    func lexicographicallyPrecedes(_ other: [[UInt8]]) -> Bool {
        for (lhs, rhs) in zip(self, other) where lhs != rhs {
            return lhs.lexicographicallyPrecedes(rhs)
        }
        return false
    }
}
