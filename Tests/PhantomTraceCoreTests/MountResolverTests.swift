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

    @Test func fileUnderLongerNamedSiblingVolumeResolvesToThatSibling() throws {
        let volumeA = mount("/Volumes/A")
        let volumeAB = mount("/Volumes/AB")
        let (sut, _) = resolver(existing: ["/Volumes/AB/file"], mounts: [volumeA, volumeAB])
        #expect(try sut.resolve(url("/Volumes/AB/file")) == volumeAB)
    }

    @Test func nameSharingOnlyACharacterPrefixDoesNotMatch() {
        let (sut, _) = resolver(existing: ["/Volumes/AB/file"], mounts: [mount("/Volumes/A")])
        #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/AB/file"))) {
            try sut.resolve(url("/Volumes/AB/file"))
        }
    }

    @Test func nestedMountWinsOverItsParent() throws {
        let parent = mount("/Volumes/A")
        let nested = mount("/Volumes/A/Inner")
        let (sut, _) = resolver(existing: ["/Volumes/A/Inner/x"], mounts: [parent, nested])
        #expect(try sut.resolve(url("/Volumes/A/Inner/x")) == nested)
    }

    @Test func nonexistentPathIsNotAMountPointAndReadsNoMounts() {
        let (sut, table) = resolver(existing: [], mounts: [mount("/Volumes/A")])
        #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/A/gone"))) {
            try sut.resolve(url("/Volumes/A/gone"))
        }
        #expect(table.calls.isEmpty)
    }

    @Test func attachedDiskImageResolvesToItsVolume() throws {
        let attached = mount("/Volumes/Disk", isDiskImage: true)
        let (sut, table) = resolver(existing: ["/Users/u/disk.dmg"], imageMounts: [attached])
        #expect(try sut.resolve(url("/Users/u/disk.dmg")) == attached)
        #expect(table.calls == [.mounts(forDiskImage: url("/Users/u/disk.dmg"))])
    }

    @Test func unattachedDiskImageIsNotAMountPoint() {
        let (sut, _) = resolver(existing: ["/Users/u/disk.dmg"], imageMounts: [])
        #expect(throws: PhantomTraceError.notAMountPoint(url("/Users/u/disk.dmg"))) {
            try sut.resolve(url("/Users/u/disk.dmg"))
        }
    }

    @Test func multiVolumeImageResolvesToFirstVolumeInTableOrder() throws {
        let first = mount("/Volumes/One", isDiskImage: true)
        let second = mount("/Volumes/Two", isDiskImage: true)
        let (sut, _) = resolver(existing: ["/Users/u/multi.DMG"], imageMounts: [first, second])
        #expect(try sut.resolve(url("/Users/u/multi.DMG")) == first)
    }

    @Test func directoryNamedLikeAnImageIsMatchedByMountPrefix() throws {
        let volume = mount("/Volumes/A")
        let (sut, table) = resolver(existing: [], directories: ["/Volumes/A/folder.dmg"], mounts: [volume])
        #expect(try sut.resolve(url("/Volumes/A/folder.dmg")) == volume)
        #expect(table.calls == [.currentMounts])
    }

    @Test func emptyVolumeNameFallsBackToMountPointName() throws {
        let (sut, _) = resolver(existing: ["/Volumes/Untitled/f"], mounts: [mount("/Volumes/Untitled", name: "")])
        #expect(try sut.resolve(url("/Volumes/Untitled/f")).volumeName == "Untitled")
    }

    @Test func unresolvablePathIsTreatedAsProtected() {
        let missingCanonical = url("/Volumes/A/odd")
        let probe = MockFileSystemProbe(existing: [missingCanonical], canonical: [:])
        let table = MockMountTableProvider(mounts: [mount("/Volumes/A")])
        let sut = MountResolver(fileSystem: probe, mountTable: table)
        #expect(throws: PhantomTraceError.protectedVolume(missingCanonical)) {
            try sut.resolve(missingCanonical)
        }
        #expect(table.calls.isEmpty)
    }

    @Test func owningMountThatIsProtectedIsRefused() {
        // The path itself is unprotected, but the only mount that owns it is the root volume (Req 2.2).
        let (sut, _) = resolver(existing: ["/Users/u/f"], mounts: [mount("/")])
        #expect(throws: PhantomTraceError.protectedVolume(url("/"))) {
            try sut.resolve(url("/Users/u/f"))
        }
    }

    @Test func mountTableFailureKeepsItsError() {
        let file = url("/Volumes/A/f")
        let probe = MockFileSystemProbe(existing: [file], canonical: [file: file])
        let table = MockMountTableProvider()
        table.currentScript.setFallback(.failure(.notAMountPoint(file)))
        let sut = MountResolver(fileSystem: probe, mountTable: table)
        #expect(throws: PhantomTraceError.notAMountPoint(url("/Volumes/A/f"))) {
            try sut.resolve(url("/Volumes/A/f"))
        }
    }
}
