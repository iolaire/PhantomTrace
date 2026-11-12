import Foundation
import PhantomTraceCore

/// Scripted `MountedVolumeEnumerating`. Never reads the machine's mounts.
public final class MockMountedVolumeEnumerator: MountedVolumeEnumerating {
    public enum Call: Equatable, Sendable {
        case enumerate
    }

    public let script: Script<Result<[MountInfo], PhantomTraceError>>
    public let log = CallLog<Call>()

    public init(mounts: [MountInfo] = []) {
        script = Script(fallback: .success(mounts))
    }

    public init(failure: PhantomTraceError) {
        script = Script(fallback: .failure(failure))
    }

    public var calls: [Call] { log.calls }

    public func enumerate() throws -> [MountInfo] {
        log.record(.enumerate)
        return try script.next().get()
    }
}
