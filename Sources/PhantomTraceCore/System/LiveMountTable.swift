import Darwin
import Dispatch
import Foundation
import Synchronization

/// Live `MountTableProviding`: reads the kernel mount table and maps `.dmg` files via `hdiutil`
/// (Requirements 1.1, 1.4, 1.5, 15.1).
public struct LiveMountTable: MountTableProviding {
    /// `statfs` names both a struct and a function; the qualified alias selects the struct.
    private typealias StatfsEntry = Darwin.statfs

    private static let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")
    private static let hdiutilTimeout: TimeInterval = 10

    private let runner: any ProcessRunning
    private let fileSystem: any FileSystemProbing

    public init(runner: any ProcessRunning, fileSystem: any FileSystemProbing = LiveFileSystemProbe()) {
        self.runner = runner
        self.fileSystem = fileSystem
    }

    public func currentMounts() throws -> [MountInfo] {
        try Self.readStatfsTable().map(mountInfo(from:))
    }

    public func mounts(forDiskImage image: URL) throws -> [MountInfo] {
        let output = try runHdiutilInfo()
        // A failing or unparseable `hdiutil` means no known attachment; the resolver reports notAMountPoint.
        guard output.exitStatus == 0, let images = HdiutilInfoParser.parse(output.standardOutput) else { return [] }
        let wanted = canonicalPath(of: image.path)
        let attached = images.filter { canonicalPath(of: $0.imagePath) == wanted }
        let mountPoints = Set(attached.flatMap(\.volumes).compactMap(\.mountPoint).map(canonicalPath(of:)))
        return try currentMounts()
            .filter { mountPoints.contains($0.mountPoint.path) }
            .map { mount in
                MountInfo(
                    mountPoint: mount.mountPoint,
                    volumeName: mount.volumeName,
                    deviceNode: mount.deviceNode,
                    fileSystemType: mount.fileSystemType,
                    isInternal: mount.isInternal,
                    isRemovable: mount.isRemovable,
                    isDiskImage: true
                )
            }
    }

    // MARK: - hdiutil

    /// `MountTableProviding` is synchronous but `ProcessRunning` is async, so block the calling thread on a
    /// semaphore while the runner works in its own task. Callers invoke this off the main actor.
    private func runHdiutilInfo() throws -> ProcessOutput {
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        let runner = runner
        Task.detached {
            let result: Result<ProcessOutput, any Error>
            do {
                result = .success(try await runner.run(
                    executable: Self.hdiutil,
                    arguments: ["info", "-plist"],
                    timeout: Self.hdiutilTimeout
                ))
            } catch {
                result = .failure(error)
            }
            box.state.withLock { $0 = result }
            semaphore.signal()
        }
        semaphore.wait()
        guard let result = box.state.withLock({ $0 }) else { throw POSIXError(.EIO) }
        return try result.get()
    }

    // MARK: - statfs

    private func canonicalPath(of path: String) -> String {
        fileSystem.canonicalURL(for: URL(fileURLWithPath: path))?.path
            ?? URL(fileURLWithPath: path).standardized.path
    }

    private func mountInfo(from entry: StatfsEntry) -> MountInfo {
        let mountPath = Self.string(from: entry.f_mntonname)
        let mountPoint = URL(fileURLWithPath: mountPath)
        let values = try? mountPoint.resourceValues(forKeys: [
            .volumeNameKey, .volumeIsInternalKey, .volumeIsRemovableKey
        ])
        return MountInfo(
            mountPoint: mountPoint,
            volumeName: values?.volumeName ?? "",
            deviceNode: Self.string(from: entry.f_mntfromname),
            fileSystemType: Self.string(from: entry.f_fstypename),
            // Unknown means internal and not removable, the conservative reading for safety checks.
            isInternal: values?.volumeIsInternal ?? true,
            isRemovable: values?.volumeIsRemovable ?? false,
            isDiskImage: false
        )
    }

    /// Uses `getfsstat`, the call behind `getmntinfo`, because it fills a caller-owned buffer instead of
    /// libc's shared static one.
    private static func readStatfsTable() throws -> [StatfsEntry] {
        let count = getfsstat(nil, 0, MNT_NOWAIT)
        guard count >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var failure: POSIXErrorCode?
        let table = [StatfsEntry](unsafeUninitializedCapacity: Int(count)) { buffer, initialized in
            let size = Int32(Int(count) * MemoryLayout<StatfsEntry>.stride)
            let filled = getfsstat(buffer.baseAddress, size, MNT_NOWAIT)
            if filled < 0 {
                failure = POSIXErrorCode(rawValue: errno) ?? .EIO
                initialized = 0
            } else {
                initialized = Int(filled)
            }
        }
        if let failure { throw POSIXError(failure) }
        return table
    }

    /// Decodes a fixed-size C char array (imported as a tuple) up to the first NUL.
    private static func string<T>(from field: T) -> String {
        withUnsafeBytes(of: field) { raw in
            let end = raw.firstIndex(of: 0) ?? raw.count
            // Reason for the disable below: lossy UTF-8 is wanted for display; the rule misfires on a byte buffer.
            // swiftlint:disable:next optional_data_string_conversion
            return String(decoding: UnsafeRawBufferPointer(rebasing: raw[..<end]), as: UTF8.self)
        }
    }
}

/// Holds the result of the detached task; `Mutex` makes the class `Sendable` without `@unchecked`.
private final class ResultBox: Sendable {
    let state = Mutex<Result<ProcessOutput, any Error>?>(nil)
}
