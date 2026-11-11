import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct LockDiscoveryEngineTests {
    private let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    private func raw(_ pid: UInt32, _ descriptor: String, _ path: String, command: String = "cat") -> RawLsofRecord {
        RawLsofRecord(
            pid: pid,
            commandBytes: Data(command.utf8),
            user: "me",
            fileDescriptor: descriptor,
            pathBytes: Data(path.utf8)
        )
    }

    private func makeEngine(_ runner: MockProcessRunner) -> LockDiscoveryEngine {
        let inspector = MockProcessInspector()
        return LockDiscoveryEngine(
            runner: runner,
            classifier: LockClassifier(fileSystem: MockFileSystemProbe(), processes: inspector),
            processes: inspector
        )
    }

    @Test func discoveryPassesMountPointVerbatimAfterDoubleDash() async throws {
        let runner = MockProcessRunner()
        runner.enqueueOutput(Data(), exitStatus: 1)
        let result = try await makeEngine(runner).discover(in: volume)
        #expect(result.locks.isEmpty)
        #expect(!result.partial)
        let call = try #require(runner.calls.first)
        #expect(call.executable.path == "/usr/sbin/lsof")
        #expect(call.arguments == ["-F", "pcLnftau0", "-w", "+f", "+c", "0", "--", "/Volumes/Test"])
        #expect(call.timeout == 15)
    }

    @Test func discoveryMergesDuplicatesExcludesOwnPidAndSorts() async throws {
        let runner = MockProcessRunner()
        let records = [
            raw(30, "txt", "/Volumes/Test/b"), raw(30, "cwd", "/Volumes/Test/b"),
            raw(4242, "3r", "/Volumes/Test/own"), raw(20, "3r", "/Volumes/Test/a")
        ]
        runner.enqueueOutput(LsofPrinter.print(records))
        let result = try await makeEngine(runner).discover(in: volume)
        #expect(result.locks.map(\.pid) == [20, 30])
        #expect(result.locks.last?.category == .cwd)
    }

    @Test func onlyOwnPidHoldingTheVolumeYieldsEmptyCompleteResult() async throws {
        let runner = MockProcessRunner()
        runner.enqueueOutput(LsofPrinter.print([raw(4242, "3r", "/Volumes/Test/own")]))
        let result = try await makeEngine(runner).discover(in: volume)
        #expect(result.locks.isEmpty)
        #expect(!result.partial)
        #expect(runner.calls.count == 1)
    }

    @Test func repeatedDiscoveryReturnsEqualResults() async throws {
        let data = LsofPrinter.print([raw(9, "3r", "/Volumes/Test/x"), raw(8, "cwd", "/Volumes/Test")])
        let runner = MockProcessRunner()
        runner.enqueueOutput(data)
        runner.enqueueOutput(data)
        let engine = makeEngine(runner)
        let first = try await engine.discover(in: volume)
        let second = try await engine.discover(in: volume)
        #expect(first == second)
    }

    @Test func protectedVolumeIsRefusedWithoutRunningAnything() async throws {
        let runner = MockProcessRunner()
        let protected = MountInfo(
            mountPoint: URL(fileURLWithPath: "/System/Volumes/Data"),
            volumeName: "Data",
            deviceNode: "/dev/disk1s1",
            fileSystemType: "apfs",
            isInternal: true,
            isRemovable: false,
            isDiskImage: false
        )
        await #expect(throws: PhantomTraceError.protectedVolume(protected.mountPoint)) {
            _ = try await makeEngine(runner).discover(in: protected)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test func timeoutFallsBackToPlusDAndFuserAndMarksPartial() async throws {
        let runner = MockProcessRunner()
        runner.enqueueTimeout(seconds: 15)
        runner.enqueueOutput(LsofPrinter.print([raw(50, "3r", "/Volumes/Test/f")]))
        runner.enqueueOutput(Data("/Volumes/Test: 50c 60c\n".utf8))
        let result = try await makeEngine(runner).discover(in: volume)
        #expect(result.partial)
        #expect(result.locks.map(\.pid) == [50, 60])
        #expect(runner.calls.map(\.executable.path) == ["/usr/sbin/lsof", "/usr/sbin/lsof", "/usr/bin/fuser"])
        #expect(runner.calls[1].arguments.suffix(2) == ["+D", "/Volumes/Test"])
        #expect(runner.calls[2].arguments == ["-c", "/Volumes/Test"])
    }

    @Test func timeoutWithUnusableFallbackReportsLsofTimedOut() async throws {
        let runner = MockProcessRunner()
        runner.enqueueTimeout(seconds: 15)
        runner.enqueueTimeout(seconds: 15)
        runner.enqueueOutput(Data(), exitStatus: 1)
        await #expect(throws: PhantomTraceError.lsofTimedOut(seconds: 15)) {
            _ = try await makeEngine(runner).discover(in: volume)
        }
    }

    @Test func truncatedOutputKeepsCompleteRecordsAndMarksPartial() async throws {
        let runner = MockProcessRunner()
        var data = LsofPrinter.print([raw(5, "3r", "/Volumes/Test/ok")])
        data.append(Data("p6\0cca".utf8))
        runner.enqueueOutput(data)
        let result = try await makeEngine(runner).discover(in: volume)
        #expect(result.partial)
        #expect(result.locks.map(\.pid) == [5])
        #expect(!result.warnings.isEmpty)
    }

    @Test func missingLsofReportsLsofUnavailable() async throws {
        let runner = MockProcessRunner(fallback: .failure(.lsofUnavailable))
        await #expect(throws: PhantomTraceError.lsofUnavailable) {
            _ = try await makeEngine(runner).discover(in: volume)
        }
    }
}
