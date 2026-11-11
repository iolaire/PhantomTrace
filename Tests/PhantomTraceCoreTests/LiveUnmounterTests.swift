import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct LiveUnmounterTests {
    private let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    @Test(arguments: [Int32(bitPattern: 0xF8DA_0009), Int32(0xC000) | EBUSY, EBUSY])
    func busyStatusesThrowUnmountBusyWithoutRunningDiskutil(status: Int32) async {
        let runner = MockProcessRunner()
        let unmounter = LiveUnmounter(runner: runner) { _, _ in status }
        await #expect(throws: PhantomTraceError.unmountBusy) {
            try await unmounter.unmount(volume, force: false)
        }
        #expect(runner.calls.isEmpty)
    }
}
