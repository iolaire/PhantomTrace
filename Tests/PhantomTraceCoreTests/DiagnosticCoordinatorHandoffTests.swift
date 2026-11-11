import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct DiagnosticCoordinatorHandoffTests: CoordinatorScenario {
    // MARK: - Handle myself (Requirement 18.16)

    @Test func handleMyselfWithLocksLeftStaysInPhantomTraceWithoutAnySignal() async {
        let (rig, discovery) = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        await rig.coordinator.select(.handleMyself)
        discovery.script.enqueue(.success(DiscoveryResult(locks: [lock(10), lock(11)])))
        await rig.coordinator.proceed()
        let model = await rig.coordinator.current
        #expect(model.window == .phantomTrace)
        #expect(model.locks.count == 2)
        #expect(rig.stages.log.calls.isEmpty)
    }

    // MARK: - Unmount (Requirements 18.24, 18.25)

    @Test func failedUnmountShowsPhantomTraceWithBannerAndOnlyRescan() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.inspect(input)
        rig.stages.handoffs.enqueue(.failed(.unmountFailed(code: 16)))
        await rig.coordinator.eject()
        let model = await rig.coordinator.current
        #expect(rig.stages.log.calls == [.cleanHandoff(force: false)])
        #expect(model.window == .phantomTrace)
        #expect(model.ghost == .red)
        #expect(model.banner?.message.contains("unmount failed") == true)
        #expect(model.volumeStillMounted)
        #expect(!model.isUnmounting)
        #expect(model.controls.rescanEnabled)
        #expect(!model.controls.proceedEnabled)
        #expect(!model.controls.ejectVisible)
    }

    @Test func rescanAfterFailedUnmountWithNoLocksReleasesTheVolumeAgain() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.inspect(input)
        rig.stages.handoffs.enqueue(.failed(.unmountFailed(code: 16)))
        await rig.coordinator.eject()
        await rig.coordinator.rescan()
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(model.banner == nil)
        #expect(model.controls.ejectVisible)
    }

    @Test func forcedEjectPassesForceThroughAndSuccessHidesEject() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.eject(force: true)
        let model = await rig.coordinator.current
        #expect(rig.stages.log.calls == [.cleanHandoff(force: true)])
        #expect(model.window == .volumeReleased)
        #expect(!model.volumeStillMounted)
        #expect(!model.controls.ejectVisible)
    }

    @Test func ejectOutsideVolumeReleasedDoesNothing() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.eject()
        #expect(rig.stages.log.calls.isEmpty)
        #expect(await rig.coordinator.current.window == .cannotPutAway)
    }

    // MARK: - Volume vanishing (Requirement 18.9)

    @Test func volumeVanishingInPhantomTraceSelectsVolumeReleased() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        rig.resolver.setMounts([])
        await rig.coordinator.mountTableChanged()
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(model.ghost == .green)
        #expect(!model.volumeStillMounted)
        #expect(model.locks.isEmpty)
        #expect(!model.controls.ejectVisible)
    }

    @Test func volumeVanishingDuringTheFirstScanIsReleasedWithNoLocks() async {
        let discovery = GatedDiscovery(result: .success(DiscoveryResult(locks: [lock(10)])), gated: true)
        let rig = rig(discovery: discovery)
        let scan = Task { await rig.coordinator.inspect(input) }
        let shown = await waitUntil { await rig.coordinator.current.isScanning }
        #expect(shown)
        rig.resolver.setMounts([])
        discovery.open()
        await scan.value
        let model = await rig.coordinator.current
        #expect(model.window == .volumeReleased)
        #expect(!model.volumeStillMounted)
        #expect(model.locks.isEmpty)
    }

    // MARK: - Observation

    @Test func updatesStreamYieldsTheCurrentModelFirst() async {
        let (rig, _) = rig(.success(DiscoveryResult(locks: [lock(10)])))
        await rig.coordinator.inspect(input)
        let expected = await rig.coordinator.current
        var iterator = await rig.coordinator.updates().makeAsyncIterator()
        #expect(await iterator.next() == expected)
    }
}
