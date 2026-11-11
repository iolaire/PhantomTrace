import Darwin
import Foundation

/// Live `ProcessInspecting` built on `proc_pidinfo` and `proc_pidpath` (Requirements 5.4, 5.5, 5.9, 14.3).
///
/// Read-only. Returns `nil` when the process is gone or cannot be inspected, which callers treat as deny.
public struct LiveProcessInspector: ProcessInspecting {
    public init() {}

    public var currentProcessID: Int32 { getpid() }

    public var currentUserID: UInt32 { UInt32(getuid()) }

    public func inspect(pid: Int32) -> ProcessDetails? {
        guard pid > 0, let info = Self.bsdInfo(pid: pid) else { return nil }
        // A zero start time would make the identity guard meaningless, so treat it as unknown.
        guard info.pbi_start_tvsec > 0 else { return nil }
        let start = Date(
            timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        )
        return ProcessDetails(
            identity: ProcessIdentity(pid: UInt32(pid), startTime: start),
            ownerUserID: info.pbi_uid,
            terminalDevice: Self.terminalPath(device: info.e_tdev),
            processGroupID: Int32(clamping: info.pbi_pgid),
            foregroundProcessGroupID: Self.foregroundGroup(info),
            currentDirectory: Self.currentDirectory(pid: pid),
            executablePath: Self.executablePath(pid: pid)
        )
    }

    private static func bsdInfo(pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let written = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        return written == size ? info : nil
    }

    /// `e_tdev` is `NODEV` (all bits set) when there is no controlling terminal.
    private static func terminalPath(device: UInt32) -> String? {
        guard device != UInt32.max, device != 0,
              let name = devname(dev_t(bitPattern: device), mode_t(S_IFCHR)) else { return nil }
        return "/dev/" + String(cString: name)
    }

    /// `e_tpgid` is the terminal's foreground group; it is only meaningful with a controlling terminal.
    private static func foregroundGroup(_ info: proc_bsdinfo) -> Int32? {
        guard info.e_tdev != UInt32.max, info.e_tdev != 0, info.e_tpgid != 0 else { return nil }
        return Int32(clamping: info.e_tpgid)
    }

    private static func currentDirectory(pid: Int32) -> URL? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    private static func executablePath(pid: Int32) -> URL? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        guard let path = String(bytes: bytes, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
