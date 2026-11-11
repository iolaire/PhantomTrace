import Foundation
import PhantomTraceCore
import Testing

/// Local-only: attaches a throwaway 10 MB disk image and unmounts it for real. Skipped when `CI` is set or
/// `hdiutil` is missing. Only the image and helper processes created here are touched.
/// Requirements 3.1, 3.2, 10.2, 15.1.
struct DiskImageIntegrationTests {
    private static var canRun: Bool {
        ProcessInfo.processInfo.environment["CI"] == nil
            && FileManager.default.isExecutableFile(atPath: DiskImageFixture.hdiutil.path)
    }

    private func pollLocks(
        _ engine: LockDiscoveryEngine,
        _ volume: MountInfo,
        until done: ([LockRecord]) -> Bool
    ) async throws -> [LockRecord] {
        var latest: [LockRecord] = []
        for _ in 0..<50 {
            latest = try await engine.discover(in: volume).locks
            if done(latest) { return latest }
            try await Task.sleep(for: .milliseconds(100))
        }
        return latest
    }

    @Test(.enabled(if: DiskImageIntegrationTests.canRun))
    func discoverReportsHelpersThenUnmountSucceedsOnceTheyExit() async throws {
        let fixture = try await DiskImageFixture.make()
        // `defer` cannot await, so cleanup runs on both the success and the failure path.
        do {
            try await exercise(fixture)
        } catch {
            await fixture.cleanUp()
            throw error
        }
        await fixture.cleanUp()
    }

    private func exercise(_ fixture: DiskImageFixture) async throws {
        let runner = LiveProcessRunner()
        let probe = LiveFileSystemProbe()
        let inspector = LiveProcessInspector()
        let resolver = MountResolver(fileSystem: probe, mountTable: LiveMountTable(runner: runner, fileSystem: probe))
        let engine = LockDiscoveryEngine(
            runner: runner,
            classifier: LockClassifier(fileSystem: probe, processes: inspector),
            processes: inspector
        )

        // Resolve both from the mount point and from the .dmg file (Requirements 1.4, 3.1).
        let volume = try resolver.resolve(fixture.mountPoint)
        #expect(volume.mountPoint.path == fixture.mountPoint.path)
        #expect(try resolver.resolve(fixture.imageURL).mountPoint.path == fixture.mountPoint.path)

        let pids = try fixture.spawnHelpers()
        let locks = try await pollLocks(engine, volume) { found in
            Set(found.map(\.pid)).isSuperset(of: [pids.fileHolder, pids.cwdHolder])
        }
        #expect(locks.contains { $0.pid == pids.fileHolder && $0.category == .openFileHandle })
        #expect(locks.contains { $0.pid == pids.cwdHolder && $0.category == .cwd })

        // Non-forced unmount of a busy volume must report busy and leave it mounted (Requirement 10.5).
        let unmounter = LiveUnmounter(runner: runner)
        await #expect(throws: PhantomTraceError.unmountBusy) {
            try await unmounter.unmount(volume, force: false)
        }
        #expect(try resolver.allMounts().contains { $0.mountPoint.path == fixture.mountPoint.path })

        fixture.stopHelpers()
        let remaining = try await pollLocks(engine, volume) { $0.isEmpty }
        #expect(remaining.isEmpty)

        try await unmounter.unmount(volume, force: false)
        #expect(try !resolver.allMounts().contains { $0.mountPoint.path == fixture.mountPoint.path })
    }
}
