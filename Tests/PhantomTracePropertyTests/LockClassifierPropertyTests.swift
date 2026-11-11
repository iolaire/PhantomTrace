import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Testing

/// Property 7: Classification consistency.
/// **Validates: Requirements 5.1, 5.2, 5.3, 5.6, 5.8**
struct LockClassifierPropertyTests {
    private static let iterations = 500

    @Test func cwdDescriptorGivesCwdCategoryAndEverythingElseGivesOpenFileHandle() async {
        await propertyCheck(
            count: Self.iterations,
            input: descriptorSelectorGenerator, pathSelectorGenerator, commandSelectorGenerator
        ) { descriptorSelector, pathSelector, commandSelector in
            let descriptor = descriptor(for: descriptorSelector)
            let raw = makeRaw(descriptor: descriptor, path: insidePath(pathSelector), command: command(commandSelector))
            let record = makeClassifier().classify(raw, volume: volume)
            #expect(record?.category == (descriptor == "cwd" ? .cwd : .openFileHandle))
        }
    }

    @Test func allowlistedCommandsAlwaysGetSystemDaemonRole() async {
        await propertyCheck(
            count: Self.iterations,
            input: descriptorSelectorGenerator, pathSelectorGenerator, allowlistSelectorGenerator
        ) { descriptorSelector, pathSelector, allowlistSelector in
            let names = LockClassifier.daemonAllowlist.sorted()
            let raw = makeRaw(
                descriptor: descriptor(for: descriptorSelector),
                path: insidePath(pathSelector),
                command: names[allowlistSelector % names.count]
            )
            #expect(makeClassifier().classify(raw, volume: volume)?.role == .systemDaemon)
        }
    }

    @Test func pathsUnderTheMountGiveExactlyOneRecordAndPathsOutsideGiveNil() async {
        await propertyCheck(
            count: Self.iterations,
            input: pathSelectorGenerator, commandSelectorGenerator
        ) { pathSelector, commandSelector in
            let classifier = makeClassifier()
            let inside = makeRaw(descriptor: "3r", path: insidePath(pathSelector), command: command(commandSelector))
            let outside = makeRaw(descriptor: "3r", path: outsidePath(pathSelector), command: command(commandSelector))
            let insideRecord = classifier.classify(inside, volume: volume)
            #expect(insideRecord != nil)
            #expect(insideRecord?.pathBytes == inside.pathBytes)
            #expect(classifier.classify(outside, volume: volume) == nil)
        }
    }

    @Test func everyClassifiedRecordHasExactlyOneRoleAndIsStable() async {
        await propertyCheck(
            count: Self.iterations,
            input: descriptorSelectorGenerator, pathSelectorGenerator, commandSelectorGenerator
        ) { descriptorSelector, pathSelector, commandSelector in
            let raw = makeRaw(
                descriptor: descriptor(for: descriptorSelector),
                path: insidePath(pathSelector),
                command: command(commandSelector)
            )
            let classifier = makeClassifier()
            let record = classifier.classify(raw, volume: volume)
            let roles = ProcessRole.allCases.filter { $0 == record?.role }
            #expect(roles.count == 1)
            #expect(classifier.classify(raw, volume: volume) == record)
        }
    }
}

// MARK: - Fixtures

private let volume = MountInfo(
    mountPoint: URL(fileURLWithPath: "/Volumes/A"),
    volumeName: "A",
    deviceNode: "/dev/disk4s1",
    fileSystemType: "apfs",
    isInternal: false,
    isRemovable: true,
    isDiskImage: false
)

private let descriptors = ["cwd", "txt", "3r", "12u", "rtd", "255w"]
private let components = ["x", "dir", "file.txt", "a b", "\u{00E9}t\u{00E9}", "..hidden"]
private let commands = ["cat", "zsh", "Finder", "node", "mds", "unknown-tool"]

private func makeClassifier() -> LockClassifier {
    LockClassifier(fileSystem: MockFileSystemProbe(), processes: MockProcessInspector())
}

private func makeRaw(descriptor: String, path: String, command: String) -> RawLsofRecord {
    RawLsofRecord(
        pid: 100,
        commandBytes: Data(command.utf8),
        user: "me",
        fileDescriptor: descriptor,
        fileType: "REG",
        pathBytes: Data(path.utf8)
    )
}

private func descriptor(for selector: Int) -> String { descriptors[selector % descriptors.count] }

private func command(_ selector: [Int]) -> String { commands[(selector.first ?? 0) % commands.count] }

/// `/Volumes/A` itself or a path of whole components below it.
private func insidePath(_ selector: [Int]) -> String {
    "/Volumes/A" + selector.map { "/" + components[$0 % components.count] }.joined()
}

/// Paths that share a byte prefix with the mount but are not under it, or are elsewhere entirely.
private func outsidePath(_ selector: [Int]) -> String {
    let tail = selector.map { "/" + components[$0 % components.count] }.joined()
    let roots = ["/Volumes/AB", "/Volumes/A2", "/Volumes/B", "/tmp", "/Volumes", "/Users/me"]
    return roots[(selector.first ?? 0) % roots.count] + tail
}

// MARK: - Generators

private var descriptorSelectorGenerator: Generator<Int, some SendableSequenceType> {
    Gen.int(in: 0...255)
}

private var allowlistSelectorGenerator: Generator<Int, some SendableSequenceType> {
    Gen.int(in: 0...255)
}

private var pathSelectorGenerator: Generator<[Int], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 0...5)
}

private var commandSelectorGenerator: Generator<[Int], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 1...1)
}
