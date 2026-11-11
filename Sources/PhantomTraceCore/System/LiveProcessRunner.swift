import Foundation
import Synchronization

/// Runs subprocesses with Foundation `Process`. Requirements 15.1, 15.6, 15.7.
///
/// The executable is launched directly from an absolute path with an argument array; no shell is involved.
/// Both pipes are drained as data arrives (readability handlers, no blocked threads), so a chatty child cannot
/// deadlock on a full pipe. On timeout or cancellation the child is terminated and reaped, partial output is
/// discarded, and an error naming the command is thrown.
public struct LiveProcessRunner: ProcessRunning {
    /// Default limit in seconds when a caller does not pass one.
    public static let defaultTimeout: TimeInterval = 10

    /// Time a child gets to exit after SIGTERM before SIGKILL.
    private static let terminationGrace: TimeInterval = 1

    public init() {}

    /// Runs with the 10 s default timeout.
    public func run(executable: URL, arguments: [String]) async throws -> ProcessOutput {
        try await run(executable: executable, arguments: arguments, timeout: Self.defaultTimeout)
    }

    public func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessOutput {
        let command = executable.path
        let isLsof = executable.lastPathComponent == "lsof"
        let capture = ProcessCapture()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        Self.drain(outPipe, into: capture, isStandardOutput: true)
        Self.drain(errPipe, into: capture, isStandardOutput: false)
        process.terminationHandler = { finished in capture.exited(status: finished.terminationStatus) }

        do {
            try process.run()
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw isLsof ? PhantomTraceError.lsofUnavailable : PhantomTraceError.commandLaunchFailed(command: command)
        }
        // The child holds its own copies of the write ends; close ours so EOF can arrive.
        try? outPipe.fileHandleForWriting.close()
        try? errPipe.fileHandleForWriting.close()

        let timer = Task {
            try await Task.sleep(for: .seconds(max(timeout, 0)))
            capture.finish(.timedOut)
        }
        let outcome = await withTaskCancellationHandler {
            await capture.wait()
        } onCancel: {
            capture.finish(.cancelled)
        }
        timer.cancel()

        switch outcome {
        case .finished(let output):
            return output
        case .timedOut:
            await Self.terminateAndReap(process)
            throw isLsof
                ? PhantomTraceError.lsofTimedOut(seconds: timeout)
                : PhantomTraceError.commandTimedOut(command: command, seconds: timeout)
        case .cancelled:
            await Self.terminateAndReap(process)
            throw CancellationError()
        }
    }

    private static func drain(_ pipe: Pipe, into capture: ProcessCapture, isStandardOutput: Bool) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                capture.endOfStream()
            } else {
                capture.append(data, isStandardOutput: isStandardOutput)
            }
        }
    }

    private static func terminateAndReap(_ process: Process) async {
        guard process.isRunning else { return }
        process.terminate()
        if await waitForExit(process, seconds: terminationGrace) { return }
        kill(process.processIdentifier, SIGKILL)
        _ = await waitForExit(process, seconds: terminationGrace)
    }

    private static func waitForExit(_ process: Process, seconds: TimeInterval) async -> Bool {
        let step = 0.02
        var waited = 0.0
        while process.isRunning, waited < seconds {
            try? await Task.sleep(for: .seconds(step))
            waited += step
        }
        return !process.isRunning
    }
}

/// How a run ended. Partial output is never carried by the failure cases.
private enum ProcessOutcome: Sendable {
    case finished(ProcessOutput)
    case timedOut
    case cancelled
}

/// Thread-safe collector for pipe bytes and the exit event. Completes once, when the process has exited and
/// both streams reached EOF, or earlier with a timeout or cancellation.
private final class ProcessCapture: Sendable {
    private struct State {
        var standardOutput = Data()
        var standardError = Data()
        var pendingEvents = 3  // exit, stdout EOF, stderr EOF
        var exitStatus: Int32 = 0
        var outcome: ProcessOutcome?
        var waiter: CheckedContinuation<ProcessOutcome, Never>?
    }

    private let state = Mutex(State())

    func append(_ data: Data, isStandardOutput: Bool) {
        state.withLock { current in
            if isStandardOutput {
                current.standardOutput.append(data)
            } else {
                current.standardError.append(data)
            }
        }
    }

    func endOfStream() {
        eventArrived { _ in }
    }

    func exited(status: Int32) {
        eventArrived { $0.exitStatus = status }
    }

    func finish(_ outcome: ProcessOutcome) {
        let waiter = state.withLock { current -> CheckedContinuation<ProcessOutcome, Never>? in
            guard current.outcome == nil else { return nil }
            current.outcome = outcome
            defer { current.waiter = nil }
            return current.waiter
        }
        waiter?.resume(returning: outcome)
    }

    func wait() async -> ProcessOutcome {
        await withCheckedContinuation { continuation in
            let ready = state.withLock { current -> ProcessOutcome? in
                if let outcome = current.outcome { return outcome }
                current.waiter = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }

    private func eventArrived(_ update: (inout State) -> Void) {
        let completed = state.withLock { current -> (CheckedContinuation<ProcessOutcome, Never>, ProcessOutcome)? in
            update(&current)
            current.pendingEvents -= 1
            guard current.pendingEvents == 0, current.outcome == nil else { return nil }
            let output = ProcessOutput(
                standardOutput: current.standardOutput,
                standardError: current.standardError,
                exitStatus: current.exitStatus
            )
            current.outcome = .finished(output)
            defer { current.waiter = nil }
            return current.waiter.map { ($0, .finished(output)) }
        }
        if let completed { completed.0.resume(returning: completed.1) }
    }
}
