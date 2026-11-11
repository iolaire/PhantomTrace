import Foundation

/// Default `LockClassifying` implementation. Reads the system only through injected protocols.
public struct LockClassifier: LockClassifying {
    public static let daemonAllowlist: Set<String> = [
        "mds", "mds_stores", "mdworker_shared", "QuickLookSatellite",
        "fseventsd", "corespotlightd", "diskimages-helper"
    ]
    public static let shellSet: Set<String> = ["zsh", "bash", "fish", "sh", "dash", "tcsh"]

    private let fileSystem: any FileSystemProbing
    private let processes: any ProcessInspecting

    public init(fileSystem: any FileSystemProbing, processes: any ProcessInspecting) {
        self.fileSystem = fileSystem
        self.processes = processes
    }

    public func classify(_ raw: RawLsofRecord, volume: MountInfo) -> LockRecord? {
        guard isUnderMount(raw.pathBytes, mountPoint: volume.mountPoint),
              !escapesVolume(raw, volume: volume) else {
            return nil
        }
        let details = Int32(exactly: raw.pid).flatMap { processes.inspect(pid: $0) }
        let category: LockCategory = raw.fileDescriptor == "cwd" ? .cwd : .openFileHandle
        return LockRecord(
            id: Self.deterministicID(pid: raw.pid, pathBytes: raw.pathBytes),
            pid: raw.pid,
            processName: raw.command,
            user: raw.user ?? "",
            category: category,
            role: role(for: raw.command, details: details),
            path: raw.path,
            pathBytes: raw.pathBytes,
            accessMode: raw.accessMode,
            processStart: details?.identity.startTime
        )
    }

    // MARK: - Role

    private func role(for command: String, details: ProcessDetails?) -> ProcessRole {
        if Self.daemonAllowlist.contains(command) {
            return .systemDaemon
        }
        if Self.shellSet.contains(command), let details,
           details.terminalDevice != nil,
           let foreground = details.foregroundProcessGroupID,
           foreground == details.processGroupID {
            return .idleShell
        }
        guard let details else { return .unknown }
        if details.terminalDevice != nil {
            return .cliTool
        }
        if let executable = details.executablePath, Self.isInsideAppBundle(executable) {
            return .userApplication
        }
        return .unknown
    }

    private static func isInsideAppBundle(_ executable: URL) -> Bool {
        executable.pathComponents.dropLast().contains { $0.hasSuffix(".app") }
    }

    // MARK: - Containment

    /// Whole-component prefix test on raw bytes, so `/Volumes/A` never matches `/Volumes/AB/x`.
    private func isUnderMount(_ pathBytes: Data, mountPoint: URL) -> Bool {
        var mount = [UInt8](mountPoint.path.utf8)
        while mount.count > 1, mount.last == UInt8(ascii: "/") {
            mount.removeLast()
        }
        let path = [UInt8](pathBytes)
        guard path.starts(with: mount) else { return false }
        if path.count == mount.count || mount == [UInt8(ascii: "/")] { return true }
        return path[mount.count] == UInt8(ascii: "/")
    }

    /// True when resolving symlinks moves the path outside the volume.
    private func escapesVolume(_ raw: RawLsofRecord, volume: MountInfo) -> Bool {
        // Paths with non-UTF-8 bytes cannot be turned into a URL faithfully; trust the lexical check.
        guard let text = String(bytes: raw.pathBytes, encoding: .utf8) else { return false }
        // A path that no longer resolves (deleted file) cannot escape; the lexical check stands.
        guard let resolved = fileSystem.canonicalURL(for: URL(fileURLWithPath: text)) else { return false }
        return !isUnderMount(Data(resolved.path.utf8), mountPoint: volume.mountPoint)
    }

    // MARK: - Identity

    /// Stable UUID from pid and path bytes, so repeated discovery yields equal records (Requirement 3.5).
    static func deterministicID(pid: UInt32, pathBytes: Data) -> UUID {
        var input = [UInt8]()
        withUnsafeBytes(of: pid.bigEndian) { input.append(contentsOf: $0) }
        input.append(contentsOf: pathBytes)
        let high = fnv1a(input, seed: 0xcbf2_9ce4_8422_2325)
        let low = fnv1a(input, seed: 0x8422_2325_cbf2_9ce4)
        var bytes = [UInt8]()
        withUnsafeBytes(of: high.bigEndian) { bytes.append(contentsOf: $0) }
        withUnsafeBytes(of: low.bigEndian) { bytes.append(contentsOf: $0) }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a(_ bytes: [UInt8], seed: UInt64) -> UInt64 {
        bytes.reduce(seed) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
    }
}
