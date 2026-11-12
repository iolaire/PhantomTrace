import Darwin
import Foundation
import Testing
@testable import PhantomTraceCore

/// Records what the sender asked the injected `kill` to do. Nothing here signals a real process.
private final class KillRecorder: @unchecked Sendable { // Guarded by `lock`; test-only.
    private let lock = NSLock()
    private var recorded: [(pid: Int32, signal: Int32)] = []
    private let result: Int32

    init(result: Int32) { self.result = result }

    var calls: [(pid: Int32, signal: Int32)] { lock.withLock { recorded } }

    func call(_ pid: Int32, _ signal: Int32) -> Int32 {
        lock.withLock { recorded.append((pid, signal)) }
        return result
    }
}

@Suite(.tags(.live), .timeLimit(.minutes(1)))struct LiveSignalSenderTests {
    private func sender(returning result: Int32) -> (LiveSignalSender, KillRecorder) {
        let recorder = KillRecorder(result: result)
        return (LiveSignalSender(killCall: { recorder.call($0, $1) }), recorder)
    }

    @Test func terminateSendsSIGTERMToTheGivenPid() throws {
        let (live, recorder) = sender(returning: 0)
        try live.send(.terminate, to: 4_242)
        #expect(recorder.calls.count == 1)
        #expect(recorder.calls.first?.pid == 4_242)
        #expect(recorder.calls.first?.signal == SIGTERM)
    }

    @Test func killSendsSIGKILLToTheGivenPid() throws {
        let (live, recorder) = sender(returning: 0)
        try live.send(.kill, to: 77)
        #expect(recorder.calls.first?.signal == SIGKILL)
    }

    @Test func epermMapsToPermissionDeniedWithThePid() {
        let (live, _) = sender(returning: EPERM)
        #expect(throws: PhantomTraceError.permissionDenied(pid: 500)) {
            try live.send(.terminate, to: 500)
        }
    }

    @Test func esrchIsTreatedAsAlreadyGone() throws {
        let (live, recorder) = sender(returning: ESRCH)
        try live.send(.kill, to: 500)
        #expect(recorder.calls.count == 1)
    }

    @Test func otherErrnoValuesAreReportedAsFailure() {
        let (live, _) = sender(returning: EINVAL)
        #expect(throws: PhantomTraceError.commandLaunchFailed(command: "kill")) {
            try live.send(.terminate, to: 500)
        }
    }

    @Test(arguments: [Int32(-1), 0, 1, Int32.min])
    func groupAndInitTargetsNeverReachTheSyscall(pid: Int32) {
        let (live, recorder) = sender(returning: 0)
        #expect(throws: PhantomTraceError.self) { try live.send(.kill, to: pid) }
        #expect(recorder.calls.isEmpty)
    }
}
