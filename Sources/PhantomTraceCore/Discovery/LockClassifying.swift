import Foundation

/// Turns one parsed `lsof` record into a classified lock (Requirement 5).
public protocol LockClassifying: Sendable {
    /// Returns `nil` when the path is not under the volume or escapes it through a symlink.
    func classify(_ raw: RawLsofRecord, volume: MountInfo) -> LockRecord?
}
