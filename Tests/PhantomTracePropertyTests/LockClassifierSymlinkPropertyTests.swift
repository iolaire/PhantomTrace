import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Testing

/// Property 8: Symlink containment.
/// **Validates: Requirements 5.7**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LockClassifierSymlinkPropertyTests {
    private static let iterations = 500

    @Test func pathUnderSymlinkResolvingOutsideTheVolumeIsNotReported() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { linkSelector, tailSelector, targetSelector in
            let path = linkPath(linkSelector, tailSelector)
            let target = outsideTargets[targetSelector.first.map { $0 % outsideTargets.count } ?? 0]
            let classifier = makeClassifier(path: path, resolvesTo: target + tailString(tailSelector))
            #expect(classifier.classify(makeRaw(path), volume: volume) == nil)
        }
    }

    @Test func pathUnderSymlinkResolvingInsideTheVolumeIsReported() async {
        await propertyCheck(
            count: Self.iterations,
            input: selectorGenerator, selectorGenerator, selectorGenerator
        ) { linkSelector, tailSelector, targetSelector in
            let path = linkPath(linkSelector, tailSelector)
            let target = "/Volumes/A/real" + tailString(targetSelector)
            let classifier = makeClassifier(path: path, resolvesTo: target)
            let record = classifier.classify(makeRaw(path), volume: volume)
            #expect(record != nil)
            #expect(record?.pathBytes == Data(path.utf8))
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

private let components = ["x", "dir", "file.txt", "a b", "\u{00E9}t\u{00E9}", "..hidden"]
/// Includes a sibling that shares a byte prefix with the mount, which must still count as outside.
private let outsideTargets = ["/tmp", "/Users/me", "/Volumes/AB", "/Volumes/B/data", "/private/tmp"]

private func tailString(_ selector: [Int]) -> String {
    selector.map { "/" + components[$0 % components.count] }.joined()
}

/// A path whose first component below the mount is a symlink named by `link`.
private func linkPath(_ link: [Int], _ tail: [Int]) -> String {
    "/Volumes/A/link" + tailString(link.prefix(1).map { $0 }) + tailString(tail)
}

private func makeClassifier(path: String, resolvesTo target: String) -> LockClassifier {
    let probe = MockFileSystemProbe(
        canonical: [URL(fileURLWithPath: path): URL(fileURLWithPath: target)]
    )
    return LockClassifier(fileSystem: probe, processes: MockProcessInspector())
}

private func makeRaw(_ path: String) -> RawLsofRecord {
    RawLsofRecord(
        pid: 100,
        commandBytes: Data("cat".utf8),
        user: "me",
        fileDescriptor: "3r",
        fileType: "REG",
        pathBytes: Data(path.utf8)
    )
}

// MARK: - Generators

private var selectorGenerator: Generator<[Int], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 0...4)
}
