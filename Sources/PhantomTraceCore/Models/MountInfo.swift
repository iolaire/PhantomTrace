import Foundation

/// A mounted volume, resolved to its canonical mount point.
public struct MountInfo: Equatable, Hashable, Sendable {
    /// Canonical absolute mount point, for example `/Volumes/BACKUP`.
    public let mountPoint: URL
    /// Display name. Falls back to the last path component of `mountPoint`.
    public let volumeName: String
    /// Device node, for example `/dev/disk4s1`.
    public let deviceNode: String
    /// File system type: `apfs`, `hfs`, `exfat`, `msdos`, and so on.
    public let fileSystemType: String
    public let isInternal: Bool
    public let isRemovable: Bool
    public let isDiskImage: Bool

    public init(
        mountPoint: URL,
        volumeName: String,
        deviceNode: String,
        fileSystemType: String,
        isInternal: Bool,
        isRemovable: Bool,
        isDiskImage: Bool
    ) {
        self.mountPoint = mountPoint
        self.volumeName = volumeName.isEmpty ? mountPoint.lastPathComponent : volumeName
        self.deviceNode = deviceNode
        self.fileSystemType = fileSystemType
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isDiskImage = isDiskImage
    }
}
