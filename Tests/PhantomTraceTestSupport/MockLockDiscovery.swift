import Foundation
import PhantomTraceCore
/// Scripted `LockDiscovering`: each call consumes the next queued result, then repeats the fallback.
public final class MockLockDiscovery: LockDiscovering {
    public let script: Script<Result<DiscoveryResult, PhantomTraceError>>
    public let log = CallLog<URL>()
    public init(fallback: Result<DiscoveryResult, PhantomTraceError>) {
        script = Script(fallback: fallback)
    }
    public func discover(in volume: MountInfo) async throws -> DiscoveryResult {
        log.record(volume.mountPoint)
        return try script.next().get()
    }
}
