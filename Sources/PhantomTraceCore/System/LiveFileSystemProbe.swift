import Darwin
import Foundation

/// Live `FileSystemProbing`: read-only, `realpath`-based, with firmlink normalization (Requirement 1.1).
public struct LiveFileSystemProbe: FileSystemProbing {
    private let firmlinks: FirmlinkMap

    public init(firmlinks: FirmlinkMap = LiveFileSystemProbe.systemFirmlinks()) {
        self.firmlinks = firmlinks
    }

    public func itemExists(at url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    public func canonicalURL(for url: URL) -> URL? {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        let path = firmlinks.userFacingPath(String(cString: resolved))
        return URL(fileURLWithPath: path)
    }

    public func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Reads `/usr/share/firmlinks`; falls back to the built-in list when it is missing or unreadable.
    public static func systemFirmlinks() -> FirmlinkMap {
        guard let text = try? String(contentsOfFile: "/usr/share/firmlinks", encoding: .utf8) else {
            return FirmlinkMap()
        }
        return FirmlinkMap(firmlinksFileText: text)
    }
}
