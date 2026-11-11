import Foundation

/// Live adapter: resolves symlinks, `.`, `..` and redundant separators; nil when the path is missing.
public struct LiveInspectPathCanonicalizer: InspectPathCanonicalizing {
    public init() {}

    public func canonicalPath(for path: String) -> String? {
        let canonical = URL(fileURLWithPath: path).standardized.resolvingSymlinksInPath().path
        guard FileManager.default.fileExists(atPath: canonical) else { return nil }
        return canonical
    }
}
