import Foundation

/// Source of the current mount table (`getmntinfo`/`statfs` in the live adapter) and disk-image lookups.
public protocol MountTableProviding: Sendable {
    /// All mounts in mount-table order.
    func currentMounts() throws -> [MountInfo]

    /// Mounts attached from the given `.dmg`, in mount-table order. Empty when the image is not attached.
    func mounts(forDiskImage image: URL) async throws -> [MountInfo]
}
