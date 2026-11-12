import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore
/// Examples for the volume picker's lister. Requirements 19.3-19.7, 19.11.
struct VolumeListerTests {
    private func mount(
        _ path: String, name: String = "", device: String = "/dev/disk4s1", type: String = "msdos",
        removable: Bool = false, diskImage: Bool = false
    ) -> MountInfo {
        MountInfo(
            mountPoint: URL(fileURLWithPath: path), volumeName: name, deviceNode: device, fileSystemType: type,
            isInternal: !removable, isRemovable: removable, isDiskImage: diskImage
        )
    }
    @Test func removableFlashDriveIsListedAsRemovable() {
        let entries = VolumeLister.list([mount("/Volumes/Flash1GB", name: "Flash1GB", removable: true)])
        #expect(entries == [VolumeListEntry(
            mountPoint: URL(fileURLWithPath: "/Volumes/Flash1GB"), displayName: "Flash1GB",
            isRemovable: true, isDiskImage: false
        )])
    }
    @Test func timeMachineLocalSnapshotIsNotListed() {
        let snapshot = mount("/Volumes/com.apple.TimeMachine.localsnapshots/Backups.backupdb/Mac", type: "apfs")
        #expect(VolumeLister.list([snapshot]).isEmpty)
    }
    @Test func networkShareWithoutADeviceNodeIsNotListed() {
        let smb = mount("/Volumes/share", name: "share", device: "//me@server/share", type: "smbfs")
        let nfs = mount("/Volumes/nfs", name: "nfs", device: "server:/export", type: "nfs")
        #expect(VolumeLister.list([smb, nfs]).isEmpty)
    }
    @Test func dotNamedMountIsNotListed() {
        #expect(VolumeLister.list([mount("/Volumes/.timemachine")]).isEmpty)
    }
    @Test func protectedVolumesAreNeverListed() {
        let protected = ["/", "/System/Volumes/Data", "/System/Volumes/Preboot", "/private/var/vm"]
        #expect(VolumeLister.list(protected.map { mount($0, type: "apfs") }).isEmpty)
    }
    @Test func systemFileSystemTypesAreNotListed() {
        let hidden = ["devfs", "autofs", "nullfs", "fdesc", "procfs"].map { mount("/Volumes/\($0)", type: $0) }
        #expect(VolumeLister.list(hidden).isEmpty)
    }
    @Test func emptyNameFallsBackToTheLastPathComponent() {
        #expect(VolumeLister.list([mount("/Volumes/Untitled 2")]).map(\.displayName) == ["Untitled 2"])
    }
    @Test func diskImageKeepsItsFlag() {
        let entries = VolumeLister.list([mount("/Volumes/Demo", name: "Demo", device: "/dev/disk9s1", diskImage: true)])
        #expect(entries.first?.isDiskImage == true)
    }
    @Test func trailingSlashSpellingsCollapseToOneEntry() {
        let entries = VolumeLister.list([mount("/Volumes/USB/", name: "USB"), mount("/Volumes/USB", name: "USB")])
        #expect(entries.map(\.mountPoint.path) == ["/Volumes/USB"])
    }
    @Test func listIsSortedByNameThenPathIgnoringCase() {
        let entries = VolumeLister.list([
            mount("/Volumes/b2", name: "beta"), mount("/Volumes/a", name: "Alpha"), mount("/Volumes/b1", name: "beta")
        ])
        #expect(entries.map(\.mountPoint.path) == ["/Volumes/a", "/Volumes/b1", "/Volumes/b2"])
    }
    @Test func enumeratorMockFeedsTheListerAndRecordsTheCall() throws {
        let enumerator = MockMountedVolumeEnumerator(mounts: [mount("/Volumes/Flash1GB", name: "Flash1GB")])
        let entries = VolumeLister.list(try enumerator.enumerate())
        #expect(entries.map(\.displayName) == ["Flash1GB"])
        #expect(enumerator.calls == [.enumerate])
    }
    @Test func enumeratorFailureIsThrownForTheCallerToKeepThePreviousList() {
        let enumerator = MockMountedVolumeEnumerator(failure: .commandLaunchFailed(command: "mount"))
        #expect(throws: PhantomTraceError.self) { try enumerator.enumerate() }
        #expect(enumerator.calls == [.enumerate])
    }
}
