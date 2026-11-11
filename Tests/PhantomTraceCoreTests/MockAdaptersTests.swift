import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct MockAdaptersTests {
    @Test func sleeperAdvancesInjectedClockWithoutWaiting() async throws {
        let sleeper = MockSleeper()
        let start = sleeper.now()
        try await sleeper.sleep(seconds: 500)
        #expect(sleeper.now().timeIntervalSince(start) == 500)
        #expect(sleeper.calls == [500])
    }

    @Test func processRunnerReplaysQueuedResultsThenFallbackAndRecordsCalls() async throws {
        let runner = MockProcessRunner()
        runner.enqueueTimeout(seconds: 15)
        let exe = URL(fileURLWithPath: "/usr/sbin/lsof")
        await #expect(throws: PhantomTraceError.lsofTimedOut(seconds: 15)) {
            _ = try await runner.run(executable: exe, arguments: ["-w"], timeout: 15)
        }
        let output = try await runner.run(executable: exe, arguments: [], timeout: 10)
        #expect(output.exitStatus == 0)
        #expect(runner.calls.map(\.arguments) == [["-w"], []])
    }

    @Test func signalSenderAndUnmounterThrowScriptedFailures() async throws {
        let sender = MockSignalSender()
        sender.script.enqueue(.permissionDenied(pid: 7))
        #expect(throws: PhantomTraceError.permissionDenied(pid: 7)) { try sender.send(.terminate, to: 7) }
        try sender.send(.kill, to: 7)
        #expect(sender.calls.map(\.signal) == [.terminate, .kill])
    }

    @Test func canonicalizerReturnsNilForUnknownPath() {
        let canonicalizer = MockInspectPathCanonicalizer(results: ["/a": "/b"])
        #expect(canonicalizer.canonicalPath(for: "/a") == "/b")
        #expect(canonicalizer.canonicalPath(for: "/x") == nil)
        #expect(canonicalizer.calls == ["/a", "/x"])
    }
}
