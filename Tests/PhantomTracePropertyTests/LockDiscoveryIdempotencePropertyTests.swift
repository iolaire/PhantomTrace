import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Testing

/// Property 17: Discovery idempotence and merging.
/// **Validates: Requirements 3.3, 3.4, 3.5**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LockDiscoveryIdempotencePropertyTests {
    private static let iterations = 500

    @Test func repeatedDiscoveryWithUnchangedSystemGivesEqualResults() async throws {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let data = LsofPrinter.print(selectors.map(makeRaw))
            let runner = MockProcessRunner()
            runner.enqueueOutput(data)
            runner.enqueueOutput(data)
            let engine = makeEngine(runner)
            let first = try? await engine.discover(in: volume)
            let second = try? await engine.discover(in: volume)
            #expect(first != nil)
            #expect(first == second)
        }
    }

    @Test func resultHasAtMostOneLockPerPidAndPathAndNoneForOwnPid() async {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let locks = await discoverLocks(selectors)
            let keys = locks.map { Key(pid: $0.pid, path: $0.pathBytes) }
            #expect(Set(keys).count == keys.count)
            #expect(!locks.contains { Int32(exactly: $0.pid) == ownPID })
        }
    }

    @Test func mergingKeepsEveryDistinctNonOwnPidAndPathExactlyOnce() async {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let expected = Set(selectors.map(makeRaw).filter { Int32(exactly: $0.pid) != ownPID }
                .map { Key(pid: $0.pid, path: $0.pathBytes) })
            let locks = await discoverLocks(selectors)
            #expect(Set(locks.map { Key(pid: $0.pid, path: $0.pathBytes) }) == expected)
        }
    }

    @Test func mergedLockIsACwdLockWhenAnyDuplicateWasAWorkingDirectory() async {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let raws = selectors.map(makeRaw)
            let cwdKeys = Set(raws.filter { $0.fileDescriptor == "cwd" }.map { Key(pid: $0.pid, path: $0.pathBytes) })
            let locks = await discoverLocks(selectors)
            for lock in locks where cwdKeys.contains(Key(pid: lock.pid, path: lock.pathBytes)) {
                #expect(lock.category == .cwd)
            }
        }
    }

    @Test func resultOrderIsByPidThenPathBytes() async {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let locks = await discoverLocks(selectors)
            let ordered = locks.sorted { lhs, rhs in
                lhs.pid != rhs.pid ? lhs.pid < rhs.pid : lhs.pathBytes.lexicographicallyPrecedes(rhs.pathBytes)
            }
            #expect(locks == ordered)
        }
    }

    @Test func discoveryResultKeysDoNotDependOnInputOrder() async {
        await propertyCheck(count: Self.iterations, input: recordSelectorsGenerator) { selectors in
            let forward = await discoverLocks(selectors)
            let backward = await discoverLocks(selectors.reversed())
            #expect(forward.map(\.pid) == backward.map(\.pid))
            #expect(forward.map(\.pathBytes) == backward.map(\.pathBytes))
        }
    }
}

// MARK: - Helpers

private struct Key: Hashable {
    let pid: UInt32
    let path: Data
}

private let ownPID: Int32 = 4242

private let volume = MountInfo(
    mountPoint: URL(fileURLWithPath: "/Volumes/A"),
    volumeName: "A",
    deviceNode: "/dev/disk4s1",
    fileSystemType: "apfs",
    isInternal: false,
    isRemovable: true,
    isDiskImage: false
)

private let pids: [UInt32] = [20, 21, 30, 4242, 77, 5000]
private let descriptors = ["cwd", "txt", "3r", "12u", "rtd", "255w"]
private let components = ["x", "dir", "file.txt", "a b", "\u{00E9}t\u{00E9}", "..hidden"]

/// One selector decodes to a pid, a descriptor, and a path under the mount, so duplicates are common.
private func makeRaw(_ selector: Int) -> RawLsofRecord {
    let pid = pids[selector % pids.count]
    let descriptor = descriptors[(selector / pids.count) % descriptors.count]
    let component = components[(selector / (pids.count * descriptors.count)) % components.count]
    return RawLsofRecord(
        pid: pid,
        commandBytes: Data("cat".utf8),
        user: "me",
        fileDescriptor: descriptor,
        fileType: "REG",
        pathBytes: Data("/Volumes/A/\(component)".utf8)
    )
}

private func makeEngine(_ runner: MockProcessRunner) -> LockDiscoveryEngine {
    let inspector = MockProcessInspector(currentProcessID: ownPID)
    return LockDiscoveryEngine(
        runner: runner,
        classifier: LockClassifier(fileSystem: MockFileSystemProbe(), processes: inspector),
        processes: inspector
    )
}

private func discoverLocks(_ selectors: [Int]) async -> [LockRecord] {
    let runner = MockProcessRunner()
    runner.enqueueOutput(LsofPrinter.print(selectors.map(makeRaw)))
    return (try? await makeEngine(runner).discover(in: volume))?.locks ?? []
}

private var recordSelectorsGenerator: Generator<[Int], some SendableSequenceType> {
    Gen.int(in: 0...1295).array(of: 0...24)
}
