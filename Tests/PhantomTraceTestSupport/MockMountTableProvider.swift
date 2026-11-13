import Foundation
import PhantomTraceCore

/// Scripted `MountTableProviding`. Never reads the machine's mounts.
public final class MockMountTableProvider: MountTableProviding {
    public enum Call: Equatable, Sendable {
        case currentMounts
        case mounts(forDiskImage: URL)
    }

    public let currentScript: Script<Result<[MountInfo], PhantomTraceError>>
    public let imageScript: Script<Result<[MountInfo], PhantomTraceError>>
    public let log = CallLog<Call>()

    public init(
        mounts: [MountInfo] = [],
        imageMounts: [MountInfo] = []
    ) {
        currentScript = Script(fallback: .success(mounts))
        imageScript = Script(fallback: .success(imageMounts))
    }

    public var calls: [Call] { log.calls }

    public func currentMounts() throws -> [MountInfo] {
        log.record(.currentMounts)
        return try currentScript.next().get()
    }

    public func mounts(forDiskImage image: URL) async throws -> [MountInfo] {
        log.record(.mounts(forDiskImage: image))
        return try imageScript.next().get()
    }
}
