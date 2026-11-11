import Foundation

/// Pure mapping from Data-volume paths to their user-facing firmlinked paths (Requirement 1.1).
///
/// `realpath` does not cross firmlinks, so `/System/Volumes/Data/Users/me` and `/Users/me` stay different
/// strings. This maps the first form to the second, but only for real firmlink roots (from
/// `/usr/share/firmlinks`), so unrelated paths under the Data volume are left alone.
public struct FirmlinkMap: Equatable, Sendable {
    public static let dataVolumePrefix = "/System/Volumes/Data"

    /// Used when `/usr/share/firmlinks` cannot be read.
    public static let defaultRoots: [String] = [
        "/Applications", "/Library", "/Users", "/Volumes", "/cores", "/opt", "/private", "/usr/local"
    ]

    private let roots: [String]

    public init(roots: [String] = FirmlinkMap.defaultRoots) {
        self.roots = roots
    }

    /// Builds a map from the text of `/usr/share/firmlinks` (one `/Path<TAB>Path` pair per line).
    public init(firmlinksFileText text: String) {
        let parsed = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let first = line.split(separator: "\t", maxSplits: 1).first.map(String.init)
            guard let root = first, root.hasPrefix("/"), root.count > 1 else { return nil }
            return root
        }
        self.init(roots: parsed.isEmpty ? FirmlinkMap.defaultRoots : parsed)
    }

    /// Returns `path` without the Data volume prefix when the remainder starts at a firmlink root.
    public func userFacingPath(_ path: String) -> String {
        let prefix = Self.dataVolumePrefix
        guard path.hasPrefix(prefix + "/") else { return path }
        let remainder = String(path.dropFirst(prefix.count))
        let isFirmlinked = roots.contains { root in
            remainder == root || remainder.hasPrefix(root + "/")
        }
        return isFirmlinked ? remainder : path
    }
}
