import Foundation
import PhantomTraceCore

/// Scripted `SignalSending`. Never signals a real process.
public final class MockSignalSender: SignalSending {
    public struct Call: Equatable, Sendable {
        public let signal: ProcessSignal
        public let pid: Int32
    }

    public let script: Script<PhantomTraceError?>
    public let log = CallLog<Call>()

    public init(fallback: PhantomTraceError? = nil) {
        script = Script(fallback: fallback)
    }

    public var calls: [Call] { log.calls }

    public func send(_ signal: ProcessSignal, to pid: Int32) throws {
        log.record(Call(signal: signal, pid: pid))
        if let error = script.next() { throw error }
    }
}
