import Foundation
import PhantomTraceCore
import Testing

struct LiveProcessRunnerTests {
    private let runner = LiveProcessRunner()

    @Test func runnerCapturesStdoutAndPassesArgumentsVerbatim() async throws {
        let output = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["a b", "$HOME;ls", "-n"],
            timeout: 5
        )
        #expect(output.exitStatus == 0)
        #expect(output.standardOutput == Data("a b $HOME;ls -n\n".utf8))
        #expect(output.standardError.isEmpty)
    }

    @Test func runnerReportsNonZeroExitStatusWithoutThrowing() async throws {
        let output = try await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            timeout: 5
        )
        #expect(output.exitStatus == 1)
    }

    @Test func runnerTerminatesSlowCommandAndNamesItInTheTimeoutError() async {
        let started = Date()
        await #expect(throws: PhantomTraceError.commandTimedOut(command: "/bin/sleep", seconds: 0.3)) {
            _ = try await runner.run(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                timeout: 0.3
            )
        }
        #expect(Date().timeIntervalSince(started) < 10)
    }

    @Test func runnerThrowsLaunchFailureForMissingExecutable() async {
        let missing = "/nonexistent/phantomtrace-tool"
        await #expect(throws: PhantomTraceError.commandLaunchFailed(command: missing)) {
            _ = try await runner.run(executable: URL(fileURLWithPath: missing), arguments: [], timeout: 5)
        }
    }

    @Test func runnerDrainsOutputLargerThanThePipeBuffer() async throws {
        let output = try await runner.run(
            executable: URL(fileURLWithPath: "/usr/bin/head"),
            arguments: ["-c", "1000000", "/dev/zero"],
            timeout: 10
        )
        #expect(output.standardOutput.count == 1_000_000)
    }
}
