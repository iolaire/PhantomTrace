import Foundation
import PhantomTraceCore

/// Scripted `ProcessRunning`. Never launches a process.
public final class MockProcessRunner: ProcessRunning {
    public struct Call: Equatable, Sendable {
        public let executable: URL
        public let arguments: [String]
        public let timeout: TimeInterval
    }

    public let script: Script<Result<ProcessOutput, PhantomTraceError>>
    public let log = CallLog<Call>()

    public init(
        fallback: Result<ProcessOutput, PhantomTraceError> = .success(
            ProcessOutput(standardOutput: Data(), standardError: Data(), exitStatus: 0)
        )
    ) {
        script = Script(fallback: fallback)
    }

    public var calls: [Call] { log.calls }

    /// Queues a successful run with the given stdout.
    public func enqueueOutput(_ data: Data, exitStatus: Int32 = 0) {
        script.enqueue(.success(ProcessOutput(standardOutput: data, standardError: Data(), exitStatus: exitStatus)))
    }

    /// Queues a timeout as `lsofTimedOut`, matching how the live runner reports one.
    public func enqueueTimeout(seconds: Double) {
        script.enqueue(.failure(.lsofTimedOut(seconds: seconds)))
    }

    public func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessOutput {
        log.record(Call(executable: executable, arguments: arguments, timeout: timeout))
        return try script.next().get()
    }
}
