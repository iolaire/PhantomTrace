import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

/// The diskutil fallback and `unmountFailed`. Requirements 10.5, 10.7, 15.1. No volume is touched.
@Suite(.tags(.live), .timeLimit(.minutes(1)))struct LiveUnmounterFallbackTests {
    private static let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )
    private static let daGenericFailure = Int32(bitPattern: 0xF8DA_0001)

    private struct Rig {
        let unmounter: LiveUnmounter
        let runner: MockProcessRunner
        let daCalls: CallLog<Bool>
    }

    private func rig(daStatus: Int32, runner: MockProcessRunner = MockProcessRunner()) -> Rig {
        let daCalls = CallLog<Bool>()
        let unmounter = LiveUnmounter(runner: runner) { _, force in
            daCalls.record(force)
            return daStatus
        }
        return Rig(unmounter: unmounter, runner: runner, daCalls: daCalls)
    }

    @Test func diskArbitrationSuccessNeverRunsDiskutil() async throws {
        let rig = rig(daStatus: 0)
        try await rig.unmounter.unmount(Self.volume, force: false)
        #expect(rig.daCalls.calls == [false])
        #expect(rig.runner.calls.isEmpty)
    }

    @Test func nonBusyFailureFallsBackToDiskutilExactlyOnce() async throws {
        let rig = rig(daStatus: Self.daGenericFailure)
        try await rig.unmounter.unmount(Self.volume, force: false)
        #expect(rig.runner.calls.map(\.executable) == [URL(fileURLWithPath: "/usr/sbin/diskutil")])
        #expect(rig.runner.calls.map(\.arguments) == [["unmount", "/Volumes/Test"]])
        #expect(rig.runner.calls.map(\.timeout) == [10])
    }

    @Test func forcedFallbackAddsTheForceVerbBeforeThePath() async throws {
        let rig = rig(daStatus: Self.daGenericFailure)
        try await rig.unmounter.unmount(Self.volume, force: true)
        #expect(rig.daCalls.calls == [true])
        #expect(rig.runner.calls.map(\.arguments) == [["unmount", "force", "/Volumes/Test"]])
    }

    @Test func failingDiskutilReportsUnmountFailedWithItsExitStatus() async {
        let runner = MockProcessRunner()
        runner.enqueueOutput(Data(), exitStatus: 1)
        let rig = rig(daStatus: Self.daGenericFailure, runner: runner)
        await #expect(throws: PhantomTraceError.unmountFailed(code: 1)) {
            try await rig.unmounter.unmount(Self.volume, force: false)
        }
        #expect(rig.runner.calls.count == 1)
    }

    @Test func diskutilLaunchErrorPropagatesWithoutASecondAttempt() async {
        let runner = MockProcessRunner(fallback: .failure(.commandLaunchFailed(command: "diskutil")))
        let rig = rig(daStatus: Self.daGenericFailure, runner: runner)
        await #expect(throws: PhantomTraceError.commandLaunchFailed(command: "diskutil")) {
            try await rig.unmounter.unmount(Self.volume, force: false)
        }
        #expect(rig.runner.calls.count == 1)
    }
}
