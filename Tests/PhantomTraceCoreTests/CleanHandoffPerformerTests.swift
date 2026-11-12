import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Clean Handoff (stage 4) against mock systems. Requirements 10.1 to 10.9.
@Suite(.timeLimit(.minutes(1)))struct CleanHandoffPerformerTests {
    private static let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Throwaway"),
        volumeName: "Throwaway",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    private static let lock = LockRecord(
        pid: 77, processName: "cat", user: "me", category: .openFileHandle, role: .cliTool,
        path: "/Volumes/Throwaway/f", pathBytes: Data("/Volumes/Throwaway/f".utf8),
        processStart: Date(timeIntervalSince1970: 77)
    )

    private static let clean = Result<DiscoveryResult, PhantomTraceError>.success(DiscoveryResult(locks: []))
    private static let blocked = Result<DiscoveryResult, PhantomTraceError>.success(
        DiscoveryResult(locks: [lock])
    )

    /// A clock whose sleeps only end on cancellation, so the scan always wins unless it hangs.
    private struct PendingClock: Sleeping {
        func now() -> Date { Date(timeIntervalSince1970: 0) }
        func sleep(seconds: TimeInterval) async throws {
            try await Task.sleep(for: .seconds(3600))
        }
    }

    /// A discovery that never answers until cancelled.
    private struct HangingDiscovery: LockDiscovering {
        func discover(in volume: MountInfo) async throws -> DiscoveryResult {
            try await Task.sleep(for: .seconds(3600))
            return DiscoveryResult(locks: [])
        }
    }

    private func performer(
        discovery: any LockDiscovering,
        unmounter: MockUnmounter,
        clock: any Sleeping = PendingClock()
    ) -> CleanHandoffPerformer {
        CleanHandoffPerformer(
            discovery: discovery,
            policy: SafetyPolicy(ownPID: 99, currentUserID: 501, history: AttemptHistory()),
            unmounter: unmounter,
            clock: clock
        )
    }

    @Test func zeroLocksUnmountsNonForcedByDefault() async {
        let unmounter = MockUnmounter()
        let discovery = MockLockDiscovery(fallback: Self.clean)
        let result = await performer(discovery: discovery, unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .unmounted)
        #expect(unmounter.calls.map(\.volume) == [Self.volume])
        #expect(unmounter.calls.map(\.force) == [false])
        #expect(discovery.log.calls.count == 1)
    }

    @Test func forceIsPassedOnlyWhenRequested() async {
        let unmounter = MockUnmounter()
        let result = await performer(discovery: MockLockDiscovery(fallback: Self.clean), unmounter: unmounter)
            .perform(on: Self.volume, force: true)
        #expect(result == .unmounted)
        #expect(unmounter.calls.map(\.force) == [true])
    }

    @Test func locksPresentReturnBlockedWithoutUnmounting() async {
        let unmounter = MockUnmounter()
        let result = await performer(discovery: MockLockDiscovery(fallback: Self.blocked), unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .blocked([Self.lock]))
        #expect(unmounter.calls.isEmpty)
    }

    @Test func busyUnmountRescansAndReturnsNewLocks() async {
        let unmounter = MockUnmounter(fallback: .unmountBusy)
        let discovery = MockLockDiscovery(fallback: Self.blocked)
        discovery.script.enqueue(Self.clean)
        let result = await performer(discovery: discovery, unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .blocked([Self.lock]))
        #expect(discovery.log.calls.count == 2)
        #expect(unmounter.calls.count == 1)
    }

    @Test func scanErrorMeansNoUnmountAndAnError() async {
        let unmounter = MockUnmounter()
        let discovery = MockLockDiscovery(fallback: .failure(.lsofUnavailable))
        let result = await performer(discovery: discovery, unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .failed(.lsofUnavailable))
        #expect(unmounter.calls.isEmpty)
    }

    @Test func partialCleanScanIsNotTrustedAndDoesNotUnmount() async {
        let unmounter = MockUnmounter()
        let partial = Result<DiscoveryResult, PhantomTraceError>.success(
            DiscoveryResult(locks: [], partial: true)
        )
        let result = await performer(discovery: MockLockDiscovery(fallback: partial), unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .failed(.lsofUnavailable))
        #expect(unmounter.calls.isEmpty)
    }

    @Test func scanTimeoutMeansNoUnmountAndATimeoutError() async {
        let unmounter = MockUnmounter()
        let result = await performer(discovery: HangingDiscovery(), unmounter: unmounter, clock: MockSleeper())
            .perform(on: Self.volume, force: false)
        #expect(result == .failed(.lsofTimedOut(seconds: CleanHandoffPerformer.scanTimeoutSeconds)))
        #expect(CleanHandoffPerformer.scanTimeoutSeconds == 10)
        #expect(unmounter.calls.isEmpty)
    }

    @Test func unmountFailureIsReportedWithItsCode() async {
        let unmounter = MockUnmounter(fallback: .unmountFailed(code: 1))
        let result = await performer(discovery: MockLockDiscovery(fallback: Self.clean), unmounter: unmounter)
            .perform(on: Self.volume, force: false)
        #expect(result == .failed(.unmountFailed(code: 1)))
        #expect(unmounter.calls.count == 1)
    }
}
