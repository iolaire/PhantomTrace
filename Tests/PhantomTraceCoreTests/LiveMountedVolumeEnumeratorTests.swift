import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

/// The mount table is scripted; only Foundation's removable flags are read from the machine, and the mount
/// points used here do not exist, so the flags can never change the result.
@Suite(.tags(.live), .timeLimit(.minutes(1)))
struct LiveMountedVolumeEnumeratorTests {
    private static func mount(_ name: String, removable: Bool = false) -> MountInfo {
        MountInfo(
            mountPoint: URL(fileURLWithPath: "/Volumes/phantomtrace-test-\(name)-does-not-exist"),
            volumeName: name,
            deviceNode: "/dev/disk99s1",
            fileSystemType: "apfs",
            isInternal: false,
            isRemovable: removable,
            isDiskImage: false
        )
    }

    @Test func enumeratorReturnsTheScriptedMountsUnchangedWhenNoFlagApplies() throws {
        let mounts = [Self.mount("A"), Self.mount("B", removable: true)]
        let provider = MockMountTableProvider(mounts: mounts)
        let result = try LiveMountedVolumeEnumerator(mountTable: provider).enumerate()
        #expect(result == mounts)
        #expect(provider.calls == [.currentMounts])
    }

    @Test func enumeratorReturnsAnEmptyListForAnEmptyMountTable() throws {
        let result = try LiveMountedVolumeEnumerator(mountTable: MockMountTableProvider()).enumerate()
        #expect(result.isEmpty)
    }

    @Test func enumeratorPassesThroughTheMountTableError() {
        let provider = MockMountTableProvider()
        let failure = PhantomTraceError.commandLaunchFailed(command: "getmntinfo")
        provider.currentScript.setFallback(.failure(failure))
        #expect(throws: failure) {
            _ = try LiveMountedVolumeEnumerator(mountTable: provider).enumerate()
        }
    }
}
