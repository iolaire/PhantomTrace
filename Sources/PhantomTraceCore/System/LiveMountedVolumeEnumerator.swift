import Foundation

/// Live `MountedVolumeEnumerating`: the kernel mount table (device node, file system type) overlaid with
/// Foundation's removable/ejectable flags so the "Removable" indicator works (Requirements 19.3, 19.9).
public struct LiveMountedVolumeEnumerator: MountedVolumeEnumerating {
    /// Reported when the system cannot list mounted volumes at all.
    private static let failureCommand = "FileManager.mountedVolumeURLs"

    private let mountTable: any MountTableProviding

    public init(mountTable: any MountTableProviding) {
        self.mountTable = mountTable
    }

    public func enumerate() throws -> [MountInfo] {
        let mounts: [MountInfo]
        do {
            mounts = try mountTable.currentMounts()
        } catch let error as PhantomTraceError {
            throw error
        } catch {
            throw PhantomTraceError.commandLaunchFailed(command: Self.failureCommand)
        }
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) else {
            throw PhantomTraceError.commandLaunchFailed(command: Self.failureCommand)
        }
        var removableByPath: [String: Bool] = [:]
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])
            let removable = (values?.volumeIsRemovable ?? false) || (values?.volumeIsEjectable ?? false)
            removableByPath[url.standardizedFileURL.path] = removable
        }
        return mounts.map { mount in
            guard removableByPath[mount.mountPoint.standardizedFileURL.path] == true, !mount.isRemovable else {
                return mount
            }
            return MountInfo(
                mountPoint: mount.mountPoint,
                volumeName: mount.volumeName,
                deviceNode: mount.deviceNode,
                fileSystemType: mount.fileSystemType,
                isInternal: mount.isInternal,
                isRemovable: true,
                isDiskImage: mount.isDiskImage
            )
        }
    }
}
