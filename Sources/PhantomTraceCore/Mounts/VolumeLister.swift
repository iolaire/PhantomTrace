import Foundation

/// Turns a mount table into the user-facing volume list. Pure: no I/O.
///
/// Requirements 19.3-19.7, 2.1, 2.5. Anything unknown or unverifiable is excluded.
public enum VolumeLister {
    private static let hiddenFileSystemTypes: Set<String> = ["devfs", "autofs", "nullfs", "fdesc", "procfs"]
    private static let snapshotDirectory = "com.apple.TimeMachine.localsnapshots"

    private struct Candidate {
        let path: String
        let mount: MountInfo
    }

    public static func list(_ mounts: [MountInfo]) -> [VolumeListEntry] {
        var winners: [String: Candidate] = [:]
        for mount in mounts {
            guard let parts = normalizedComponents(of: mount.mountPoint) else { continue }
            guard !MountResolver.isProtected(mount.mountPoint), !isHidden(mount, parts: parts) else { continue }
            let candidate = Candidate(path: "/" + parts.joined(separator: "/"), mount: mount)
            if let current = winners[candidate.path], !precedes(candidate.mount, current.mount) { continue }
            winners[candidate.path] = candidate
        }
        return winners.values.map(entry(for:)).sorted(by: entryPrecedes)
    }

    // MARK: - Filtering

    /// Lexical `.`/`..` collapse; nil for non-file or relative URLs (unverifiable).
    private static func normalizedComponents(of url: URL) -> [String]? {
        guard url.isFileURL, url.path.hasPrefix("/") else { return nil }
        var result: [String] = []
        for part in url.pathComponents where part != "/" && part != "." {
            if part == ".." {
                _ = result.popLast()
            } else {
                result.append(part)
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func isHidden(_ mount: MountInfo, parts: [String]) -> Bool {
        if hiddenFileSystemTypes.contains(mount.fileSystemType.lowercased()) { return true }
        if !mount.deviceNode.hasPrefix("/dev/") { return true }
        if parts.contains(snapshotDirectory) { return true }
        if parts.starts(with: ["private", "var"]) || parts.starts(with: ["var"]) { return true }
        return parts.last?.hasPrefix(".") ?? true
    }

    // MARK: - Ordering

    private static func bytes(_ text: String) -> [UInt8] {
        Array(text.precomposedStringWithCanonicalMapping.utf8)
    }

    /// Total order used to pick one mount among duplicates: `(volumeName, deviceNode)` first,
    /// then the remaining fields so the result never depends on input order.
    private static func precedes(_ lhs: MountInfo, _ rhs: MountInfo) -> Bool {
        let left = [bytes(lhs.volumeName), bytes(lhs.deviceNode), bytes(lhs.fileSystemType)]
        let right = [bytes(rhs.volumeName), bytes(rhs.deviceNode), bytes(rhs.fileSystemType)]
        for (lhsBytes, rhsBytes) in zip(left, right) where lhsBytes != rhsBytes {
            return lhsBytes.lexicographicallyPrecedes(rhsBytes)
        }
        let lhsFlags = [lhs.isInternal, lhs.isRemovable, lhs.isDiskImage].map { $0 ? 1 : 0 }
        let rhsFlags = [rhs.isInternal, rhs.isRemovable, rhs.isDiskImage].map { $0 ? 1 : 0 }
        return lhsFlags.lexicographicallyPrecedes(rhsFlags)
    }

    private static func entry(for candidate: Candidate) -> VolumeListEntry {
        let mount = candidate.mount
        let url = URL(fileURLWithPath: candidate.path)
        let name = mount.volumeName.isEmpty ? url.lastPathComponent : mount.volumeName
        return VolumeListEntry(
            mountPoint: url,
            displayName: name,
            isRemovable: mount.isRemovable,
            isDiskImage: mount.isDiskImage
        )
    }

    /// Case-insensitive, then case-sensitive, then path; all byte-wise on NFC, so locale never matters.
    private static func entryPrecedes(_ lhs: VolumeListEntry, _ rhs: VolumeListEntry) -> Bool {
        let keys: [([UInt8], [UInt8])] = [
            (bytes(lhs.displayName.lowercased()), bytes(rhs.displayName.lowercased())),
            (bytes(lhs.displayName), bytes(rhs.displayName)),
            (Array(lhs.mountPoint.path.utf8), Array(rhs.mountPoint.path.utf8))
        ]
        for (left, right) in keys where left != right {
            return left.lexicographicallyPrecedes(right)
        }
        return false
    }
}
