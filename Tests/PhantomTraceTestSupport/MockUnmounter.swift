import Foundation
import PhantomTraceCore

/// Scripted `Unmounting`. Never unmounts anything.
public final class MockUnmounter: Unmounting {
    public struct Call: Equatable, Sendable {
        public let volume: MountInfo
        public let force: Bool
    }

    public let script: Script<PhantomTraceError?>
    public let log = CallLog<Call>()

    public init(fallback: PhantomTraceError? = nil) {
        script = Script(fallback: fallback)
    }

    public var calls: [Call] { log.calls }

    public func unmount(_ volume: MountInfo, force: Bool) async throws {
        log.record(Call(volume: volume, force: force))
        if let error = script.next() { throw error }
    }
}
