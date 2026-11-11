import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Regression tests for Requirement 2.1 (minimized from `ProtectedVolumeRefusalPropertyTests`).
struct MountResolverProtectionTests {
    private func resolver(target: String, canonical: String) -> MountResolver {
        let targetURL = URL(fileURLWithPath: target)
        let canonicalURL = URL(fileURLWithPath: canonical)
        let urls: Set<URL> = [targetURL, canonicalURL]
        let probe = MockFileSystemProbe(existing: urls, directories: urls, canonical: [targetURL: canonicalURL])
        return MountResolver(fileSystem: probe, mountTable: MockMountTableProvider(mounts: []))
    }

    @Test(arguments: ["/private/var/vm", "/private/var/vm/swapfile0", "/var/vm", "/System/Volumes/Data", "/"])
    func protectedPathsAreRefusedByTheirOwnSpelling(path: String) {
        #expect(throws: PhantomTraceError.protectedVolume(URL(fileURLWithPath: path))) {
            try resolver(target: path, canonical: path).resolve(URL(fileURLWithPath: path))
        }
    }

    @Test func userPathCanonicalizingToPrivateVarVmIsRefused() {
        let canonical = URL(fileURLWithPath: "/private/var/vm")
        #expect(throws: PhantomTraceError.protectedVolume(canonical)) {
            try resolver(target: "/Volumes/A", canonical: "/private/var/vm").resolve(URL(fileURLWithPath: "/Volumes/A"))
        }
    }

    @Test func siblingOfProtectedComponentIsNotProtected() {
        #expect(!MountResolver.isProtected(URL(fileURLWithPath: "/private/var/vmware")))
        #expect(!MountResolver.isProtected(URL(fileURLWithPath: "/Volumes/vm")))
    }
}
