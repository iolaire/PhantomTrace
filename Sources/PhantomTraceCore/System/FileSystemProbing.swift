import Foundation

/// Read-only file system questions, so pure logic never touches the disk (Requirement 15.5).
public protocol FileSystemProbing: Sendable {
    /// True when something exists at `url`.
    func itemExists(at url: URL) -> Bool

    /// Resolves symlinks, firmlinks, `.` and `..`. Returns `nil` when the path cannot be resolved.
    func canonicalURL(for url: URL) -> URL?

    /// True when `url` is an existing directory.
    func isDirectory(at url: URL) -> Bool
}
