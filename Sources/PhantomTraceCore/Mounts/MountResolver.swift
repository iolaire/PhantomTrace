import Foundation

/// Turns user input (file, folder, volume, or `.dmg`) into the owning `MountInfo`.
public protocol MountResolving: Sendable {
    func resolve(_ input: URL) throws -> MountInfo
    func allMounts() throws -> [MountInfo]
}

/// Pure resolver: every system question goes through `FileSystemProbing` and `MountTableProviding`.
///
/// Requirements 1.1-1.10, 2.1, 2.2, 2.3, 2.5. It only reads state, so an error never leads to a scan or mutation.
public struct MountResolver: MountResolving {
    private let fileSystem: any FileSystemProbing
    private let mountTable: any MountTableProviding

    public init(fileSystem: any FileSystemProbing, mountTable: any MountTableProviding) {
        self.fileSystem = fileSystem
        self.mountTable = mountTable
    }

    public func allMounts() throws -> [MountInfo] {
        try mountTable.currentMounts()
    }

    public func resolve(_ input: URL) throws -> MountInfo {
        // Requirement 1.6: a missing path is not a mount point.
        guard fileSystem.itemExists(at: input) else {
            throw PhantomTraceError.notAMountPoint(input)
        }
        // Requirement 2.5: an unresolvable path cannot be verified, so treat it as protected.
        guard let canonical = fileSystem.canonicalURL(for: input) else {
            throw PhantomTraceError.protectedVolume(input)
        }
        if Self.isProtected(canonical) {
            throw PhantomTraceError.protectedVolume(canonical)
        }

        let mount: MountInfo
        do {
            mount = try owningMount(of: canonical)
        } catch let error as PhantomTraceError {
            throw error
        } catch {
            // Requirement 2.5: mount table unreadable, status undetermined.
            throw PhantomTraceError.protectedVolume(canonical)
        }

        if Self.isProtected(mount.mountPoint) {
            throw PhantomTraceError.protectedVolume(mount.mountPoint)
        }
        return mount
    }

    // MARK: - Matching

    private func owningMount(of canonical: URL) throws -> MountInfo {
        if Self.isDiskImage(canonical), !fileSystem.isDirectory(at: canonical) {
            // Requirements 1.4, 1.5, 1.8: first attached volume in mount-table order.
            guard let first = try mountTable.mounts(forDiskImage: canonical).first else {
                throw PhantomTraceError.notAMountPoint(canonical)
            }
            return first
        }

        // Requirements 1.2, 1.3, 1.7: longest whole-component prefix; an exact match is the longest.
        let target = Self.components(of: canonical)
        var best: (mount: MountInfo, length: Int)?
        for mount in try mountTable.currentMounts() {
            let prefix = Self.components(of: mount.mountPoint)
            guard Self.isPrefix(prefix, of: target) else { continue }
            if best == nil || prefix.count > (best?.length ?? -1) {
                best = (mount, prefix.count)
            }
        }
        guard let found = best?.mount else {
            throw PhantomTraceError.notAMountPoint(canonical)
        }
        return found
    }

    private static func isDiskImage(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "dmg"
    }

    private static func components(of url: URL) -> [String] {
        url.standardizedFileURL.pathComponents.filter { $0 != "/" }
    }

    private static func isPrefix(_ prefix: [String], of path: [String]) -> Bool {
        prefix.count <= path.count && path.starts(with: prefix)
    }

    /// Requirement 2.1: `/`, anything under `/System/Volumes`, and `/private/var/vm`.
    ///
    /// Components are normalized lexically here (no `standardizedFileURL`, which rewrites `/private/var/vm`
    /// to `/var/vm`). Both spellings are refused, since `/var` is a symlink to `/private/var`.
    static func isProtected(_ url: URL) -> Bool {
        let parts = lexicalComponents(of: url)
        if parts.isEmpty { return true }
        if isPrefix(["System", "Volumes"], of: parts) { return true }
        return isPrefix(["private", "var", "vm"], of: parts) || isPrefix(["var", "vm"], of: parts)
    }

    /// Collapses `.` and `..` without touching `/private`; pure, no I/O.
    private static func lexicalComponents(of url: URL) -> [String] {
        var result: [String] = []
        for part in url.pathComponents where part != "/" && part != "." {
            if part == ".." {
                _ = result.popLast()
            } else {
                result.append(part)
            }
        }
        return result
    }
}
