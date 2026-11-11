import Foundation
import PhantomTraceTestSupport
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 9: Mount resolution.
struct MountResolverPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 1.1, 1.2, 1.3, 1.9**
    @Test func resolvedMountIsLongestWholeComponentPrefix() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator()) { scenario in
            let resolver = scenario.makeResolver()
            let expected = scenario.expectedMount()
            do {
                let mount = try resolver.resolve(scenario.target)
                #expect(mount.mountPoint == expected)
            } catch {
                #expect(expected == nil, "Unexpected error \(error) for \(scenario.target.path)")
            }
        }
    }

    /// **Validates: Requirements 1.1, 1.2, 1.3, 1.9**
    @Test func exactMountPointMatchReturnsThatMount() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator()) { scenario in
            let resolver = scenario.makeResolver()
            for mount in scenario.mounts {
                let resolved = try? resolver.resolve(mount.mountPoint)
                #expect(resolved == mount)
            }
        }
    }

    /// **Validates: Requirements 1.1, 1.2, 1.3, 1.9**
    @Test func resolvedMountIsAbsoluteCanonicalInTableAndNamed() async {
        await propertyCheck(count: Self.iterations, input: scenarioGenerator()) { scenario in
            let resolver = scenario.makeResolver()
            guard let mount = try? resolver.resolve(scenario.target) else { return }
            #expect(mount.mountPoint.path.hasPrefix("/"))
            #expect(mount.mountPoint == mount.mountPoint.standardizedFileURL)
            #expect(scenario.mounts.contains(mount))
            #expect(!mount.volumeName.isEmpty)
        }
    }
}

private struct ResolutionScenario: Sendable {
    let mounts: [MountInfo]
    let target: URL

    func makeResolver() -> MountResolver {
        let urls = Set(mounts.map(\.mountPoint)).union([target])
        let probe = MockFileSystemProbe(
            existing: urls,
            directories: urls,
            canonical: Dictionary(uniqueKeysWithValues: urls.map { ($0, $0) })
        )
        return MountResolver(fileSystem: probe, mountTable: MockMountTableProvider(mounts: mounts))
    }

    /// Independent oracle: the deepest mount point whose components are a prefix of the target's.
    func expectedMount() -> URL? {
        let targetParts = target.pathComponents
        return mounts.map(\.mountPoint)
            .filter { targetParts.starts(with: $0.pathComponents) }
            .max { $0.pathComponents.count < $1.pathComponents.count }
    }
}

/// Names overlap on purpose (`A` vs `AB`) to catch string-prefix matching.
private let componentNames = ["A", "AB", "B", "A B", "é", "日本"]

private func componentsGenerator(_ length: ClosedRange<Int>) -> Generator<[String], some SendableSequenceType> {
    Gen.int(in: 0..<componentNames.count).array(of: length).map { $0.map { componentNames[$0] } }
}

private func url(_ components: [String]) -> URL {
    URL(fileURLWithPath: "/Volumes/" + components.joined(separator: "/"))
}

private func scenarioGenerator() -> Generator<ResolutionScenario, some SendableSequenceType> {
    let mounts = componentsGenerator(1...3).array(of: 1...5)
    let target = componentsGenerator(1...5)
    return zip(mounts, target).map { mountParts, targetParts in
        var seen = Set<URL>()
        let infos = mountParts.map(url).filter { seen.insert($0).inserted }.enumerated().map { index, point in
            MountInfo(
                mountPoint: point,
                volumeName: point.lastPathComponent,
                deviceNode: "/dev/disk\(index)s1",
                fileSystemType: "apfs",
                isInternal: false,
                isRemovable: true,
                isDiskImage: false
            )
        }
        return ResolutionScenario(mounts: infos, target: url(targetParts))
    }
}
