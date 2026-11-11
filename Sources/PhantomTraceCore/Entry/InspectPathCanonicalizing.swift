import Foundation

/// Minimal file system seam for inspect URL handling, so tests never touch the real disk.
public protocol InspectPathCanonicalizing: Sendable {
    /// Returns the canonical absolute path (symlinks, `.`, `..`, redundant separators resolved),
    /// or nil when the path does not exist.
    func canonicalPath(for path: String) -> String?
}
