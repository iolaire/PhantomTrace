import Foundation
import PhantomTraceCore
import Synchronization
/// `MountResolving` with a settable mount list. `resolve` returns the first mount, or throws `failure`.
public final class MockMountResolver: MountResolving {
    private let mounts: Mutex<[MountInfo]>
    private let failure: Mutex<PhantomTraceError?>
    public init(mounts: [MountInfo], failure: PhantomTraceError? = nil) {
        self.mounts = Mutex(mounts)
        self.failure = Mutex(failure)
    }
    public func setMounts(_ value: [MountInfo]) {
        mounts.withLock { $0 = value }
    }
    public func resolve(_ input: URL) throws -> MountInfo {
        if let error = failure.withLock({ $0 }) { throw error }
        guard let first = mounts.withLock({ $0.first }) else { throw PhantomTraceError.notAMountPoint(input) }
        return first
    }
    public func allMounts() throws -> [MountInfo] {
        mounts.withLock { $0 }
    }
}
