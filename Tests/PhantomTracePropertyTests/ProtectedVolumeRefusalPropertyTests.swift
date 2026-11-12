import Foundation
import PhantomTraceTestSupport
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 10: Protected volume refusal.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct ProtectedVolumeRefusalPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 2.1**
    @Test func protectedPathsAreRefusedWhateverTheMountTableHolds() async {
        let input = zip(protectedPathGenerator(), userMountsGenerator())
        await propertyCheck(count: Self.iterations, input: input) { path, userMounts in
            let target = URL(fileURLWithPath: path)
            let resolver = makeResolver(target: target, canonical: target, mounts: userMounts)
            #expect(isProtectedVolumeError { try resolver.resolve(target) }, "Not refused: \(path)")
        }
    }

    /// **Validates: Requirements 2.1**
    @Test func userPathCanonicalizingIntoProtectedLocationIsRefused() async {
        let input = zip(userPathGenerator(), protectedPathGenerator())
        await propertyCheck(count: Self.iterations, input: input) { path, protectedPath in
            let target = URL(fileURLWithPath: path)
            let canonical = URL(fileURLWithPath: protectedPath)
            let resolver = makeResolver(target: target, canonical: canonical, mounts: [])
            #expect(isProtectedVolumeError { try resolver.resolve(target) }, "Not refused: \(path) -> \(protectedPath)")
        }
    }

    /// **Validates: Requirements 2.1**
    @Test func pathWhoseOwningMountIsProtectedIsRefused() async {
        let input = zip(userPathGenerator(), protectedPathGenerator())
        await propertyCheck(count: Self.iterations, input: input) { path, mountPath in
            let target = URL(fileURLWithPath: path)
            // The only mount that owns the target is `/`, so the owning mount is protected.
            let root = makeMount(URL(fileURLWithPath: "/"), index: 0)
            let resolver = makeResolver(target: target, canonical: target, mounts: [root])
            #expect(isProtectedVolumeError { try resolver.resolve(target) }, "Not refused: \(path) via \(mountPath)")
        }
    }

    /// **Validates: Requirements 2.1**
    @Test func refusalNeverReturnsAMountForProtectedPaths() async {
        await propertyCheck(count: Self.iterations, input: protectedPathGenerator()) { path in
            let target = URL(fileURLWithPath: path)
            let resolver = makeResolver(target: target, canonical: target, mounts: [makeMount(target, index: 0)])
            let resolved = try? resolver.resolve(target)
            #expect(resolved == nil)
        }
    }
}

private func isProtectedVolumeError(_ body: () throws -> MountInfo) -> Bool {
    do {
        _ = try body()
        return false
    } catch PhantomTraceError.protectedVolume {
        return true
    } catch {
        return false
    }
}

private func makeMount(_ point: URL, index: Int) -> MountInfo {
    MountInfo(
        mountPoint: point,
        volumeName: point.lastPathComponent.isEmpty ? "Root" : point.lastPathComponent,
        deviceNode: "/dev/disk\(index)s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: false
    )
}

private func makeResolver(target: URL, canonical: URL, mounts: [MountInfo]) -> MountResolver {
    let urls: Set<URL> = [target, canonical]
    let probe = MockFileSystemProbe(
        existing: urls,
        directories: urls,
        canonical: [target: canonical]
    )
    return MountResolver(fileSystem: probe, mountTable: MockMountTableProvider(mounts: mounts))
}

private let segmentNames = ["A", "AB", "Data", "x y", "é", "日本"]

private func segmentsGenerator(_ length: ClosedRange<Int>) -> Generator<String, some SendableSequenceType> {
    Gen.int(in: 0..<segmentNames.count).array(of: length).map { indices in
        indices.map { segmentNames[$0] }.joined(separator: "/")
    }
}

/// `/` itself, anything under `/System/Volumes`, and `/private/var/vm` (with optional descendants).
/// Descendants of `/` are not protected by path; they are protected only through their owning mount.
private func protectedPathGenerator() -> Generator<String, some SendableSequenceType> {
    zip(Gen.int(in: 0...2), segmentsGenerator(0...3)).map { kind, suffix in
        let base = ["/", "/System/Volumes", "/private/var/vm"][kind]
        if kind == 0 || suffix.isEmpty { return base }
        return base + "/" + suffix
    }
}

private func userPathGenerator() -> Generator<String, some SendableSequenceType> {
    segmentsGenerator(1...4).map { "/Volumes/" + $0 }
}

private func userMountsGenerator() -> Generator<[MountInfo], some SendableSequenceType> {
    segmentsGenerator(1...2).array(of: 0...3).map { names in
        var seen = Set<URL>()
        return names.map { URL(fileURLWithPath: "/Volumes/" + $0) }
            .filter { seen.insert($0).inserted }
            .enumerated()
            .map { makeMount($1, index: $0) }
    }
}
