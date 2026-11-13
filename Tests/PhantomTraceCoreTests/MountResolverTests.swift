import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Unit tests for `MountResolver` (Requirements 1.2, 1.4-1.8, 1.10, 2.2, 2.5). Protected-path
/// refusal (2.1) lives in `MountResolverProtectionTests`.
struct MountResolverTests {
    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    private func mount(_ path: String, name: String = "", isDiskImage: Bool = false) -> MountInfo {
        MountInfo(
            mountPoint: url(path),
            volumeName: name,
            deviceNode: "/dev/disk9s1",
            fileSystemType: "apfs",
            isInternal: false,
            isRemovable: true,
            isDiskImage: isDiskImage
        )
    }

    /// Every input is its own canonical form, so only the mount table decides the outcome.
    private func resolver(
        existing: [String],
        directories: [String] = [],
        mounts: [MountInfo] = [],
        imageMounts: [MountInfo] = []
    ) -> (resolver: MountResolver, table: MockMountTableProvider) {
        let files = Set(existing.map(url))
        let dirs = Set(directories.map(url))
        let canonical = Dictionary(uniqueKeysWithValues: files.union(dirs).map { ($0, $0) })
        let probe = MockFileSystemProbe(existing: files, directories: dirs, canonical: canonical)
        let table = MockMountTableProvider(mounts: mounts, imageMounts: imageMounts)
        return (MountResolver(fileSystem: probe, mountTable: table), table)
    }

    @Test func fileUnderLongerNamedSiblingVolumeResolvesToThatSibling() async throws {
        let volumeA = mount("/Volumes/A")
        let volumeAB = mount("/Volumes/AB")
        let (sut, _) = resolver(existing: ["/Volumes/AB/file"], mounts: [volumeA, volumeAB])
        #expect(try await sut.resolve(url("/Volumes/AB/file")) == volumeAB)
    }

    @Test func nameSharingOnlyACharacterPrefixDoesNotMatch() async {
        let (sut, _) = resolver(existing: ["/Volumes/AB/file"], mounts: [mount("/Volumes/A")])
        await #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/AB/file"))) {
            try await sut.resolve(url("/Volumes/AB/file"))
        }
    }

    @Test func nestedMountWinsOverItsParent() async throws {
        let parent = mount("/Volumes/A")
        let nested = mount("/Volumes/A/Inner")
        let (sut, _) = resolver(existing: ["/Volumes/A/Inner/x"], mounts: [parent, nested])
        #expect(try await sut.resolve(url("/Volumes/A/Inner/x")) == nested)
    }

    @Test func nonexistentPathIsNotAMountPointAndReadsNoMounts() async {
        let (sut, table) = resolver(existing: [], mounts: [mount("/Volumes/A")])
        await #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/A/gone"))) {
            try await sut.resolve(url("/Volumes/A/gone"))
        }
        #expect(table.calls.isEmpty)
    }

    @Test func attachedDiskImageResolvesToItsVolume() async throws {
        let attached = mount("/Volumes/Disk", isDiskImage: true)
        let (sut, table) = resolver(existing: ["/Users/u/disk.dmg"], imageMounts: [attached])
        #expect(try await sut.resolve(url("/Users/u/disk.dmg")) == attached)
        #expect(table.calls == [.mounts(forDiskImage: url("/Users/u/disk.dmg"))])
    }

    @Test func unattachedDiskImageIsNotAMountPoint() async {
        let (sut, _) = resolver(existing: ["/Users/u/disk.dmg"], imageMounts: [])
        await #expect(throws: PhantomTraceError.notAMountPoint(url("/Users/u/disk.dmg"))) {
            try await sut.resolve(url("/Users/u/disk.dmg"))
        }
    }

    @Test func multiVolumeImageResolvesToFirstVolumeInTableOrder() async throws {
        let first = mount("/Volumes/One", isDiskImage: true)
        let second = mount("/Volumes/Two", isDiskImage: true)
        let (sut, _) = resolver(existing: ["/Users/u/multi.DMG"], imageMounts: [first, second])
        #expect(try await sut.resolve(url("/Users/u/multi.DMG")) == first)
    }

    @Test func directoryNamedLikeAnImageIsMatchedByMountPrefix() async throws {
        let volume = mount("/Volumes/A")
        let (sut, table) = resolver(existing: [], directories: ["/Volumes/A/folder.dmg"], mounts: [volume])
        #expect(try await sut.resolve(url("/Volumes/A/folder.dmg")) == volume)
        #expect(table.calls == [.currentMounts])
    }

    @Test func emptyVolumeNameFallsBackToMountPointName() async throws {
        let (sut, _) = resolver(existing: ["/Volumes/Untitled/f"], mounts: [mount("/Volumes/Untitled", name: "")])
        #expect(try await sut.resolve(url("/Volumes/Untitled/f")).volumeName == "Untitled")
    }

    @Test func unresolvablePathIsTreatedAsProtected() async {
        let missingCanonical = url("/Volumes/A/odd")
        let probe = MockFileSystemProbe(existing: [missingCanonical], canonical: [:])
        let table = MockMountTableProvider(mounts: [mount("/Volumes/A")])
        let sut = MountResolver(fileSystem: probe, mountTable: table)
        await #expect(throws: PhantomTraceError.protectedVolume(missingCanonical)) {
            try await sut.resolve(missingCanonical)
        }
        #expect(table.calls.isEmpty)
    }

    @Test func owningMountThatIsProtectedIsRefused() async {
        // The path itself is unprotected, but the only mount that owns it is the root volume (Req 2.2).
        let (sut, _) = resolver(existing: ["/Users/u/f"], mounts: [mount("/")])
        await #expect(throws: PhantomTraceError.protectedVolume(url("/"))) {
            try await sut.resolve(url("/Users/u/f"))
        }
    }

    @Test func mountTableFailureKeepsItsError() async {
        let file = url("/Volumes/A/f")
        let probe = MockFileSystemProbe(existing: [file], canonical: [file: file])
        let table = MockMountTableProvider()
        table.currentScript.setFallback(.failure(.notAMountPoint(file)))
        let sut = MountResolver(fileSystem: probe, mountTable: table)
        await #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/A/f"))) {
            try await sut.resolve(url("/Volumes/A/f"))
        }
    }
}
