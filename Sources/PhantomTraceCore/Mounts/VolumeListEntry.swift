import Foundation

/// One row of the volume picker. Requirement 19.3.
public struct VolumeListEntry: Equatable, Hashable, Sendable {
    /// Canonical (lexically normalized) absolute mount point.
    public let mountPoint: URL
    /// Volume name, or the last path component when the name is empty. Never empty.
    public let displayName: String
    /// Removable or ejectable.
    public let isRemovable: Bool
    public let isDiskImage: Bool

    public init(mountPoint: URL, displayName: String, isRemovable: Bool, isDiskImage: Bool) {
        self.mountPoint = mountPoint
        self.displayName = displayName
        self.isRemovable = isRemovable
        self.isDiskImage = isDiskImage
    }
}
