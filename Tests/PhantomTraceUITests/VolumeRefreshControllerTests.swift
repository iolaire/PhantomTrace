import Foundation
import PhantomTraceCore
import Synchronization
import Testing
@testable import PhantomTraceUI

/// Enumerator that returns scripted results in order, repeating the last one.
private final class ScriptedEnumerator: MountedVolumeEnumerating {
    private let results: [Result<[MountInfo], PhantomTraceError>]
    private let count = Mutex(0)

    init(_ results: [Result<[MountInfo], PhantomTraceError>]) {
        self.results = results
    }

    var callCount: Int { count.withLock { $0 } }

    func enumerate() throws -> [MountInfo] {
        let index = count.withLock { value -> Int in
            defer { value += 1 }
            return value
        }
        return try results[min(index, results.count - 1)].get()
    }
}

/// Clock whose first `blockedSleeps` sleeps suspend until cancelled; later sleeps return at once.
private final class GatedSleeper: Sleeping {
    private let started = Mutex(0)
    private let requested = Mutex<[TimeInterval]>([])
    private let blockedSleeps: Int

    init(blockedSleeps: Int) {
        self.blockedSleeps = blockedSleeps
    }

    var durations: [TimeInterval] { requested.withLock { $0 } }

    func now() -> Date { Date(timeIntervalSince1970: 0) }

    func sleep(seconds: TimeInterval) async throws {
        requested.withLock { $0.append(seconds) }
        let index = started.withLock { value -> Int in
            defer { value += 1 }
            return value
        }
        if index < blockedSleeps {
            try await Task.sleep(for: .seconds(3600))
        }
    }
}

@MainActor
private final class FakeEventSource: VolumeEventSource {
    private var handler: (@MainActor () -> Void)?
    private(set) var stopCount = 0

    func start(handler: @escaping @MainActor () -> Void) { self.handler = handler }
    func stop() {
        handler = nil
        stopCount += 1
    }

    func fire() { handler?() }
}

private func mount(_ name: String) -> MountInfo {
    MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/\(name)"),
        volumeName: name,
        deviceNode: "/dev/disk9s1",
        fileSystemType: "exfat",
        isInternal: false,
        isRemovable: true,
        isDiskImage: false
    )
}

@MainActor
private final class StateRecorder {
    var states: [VolumeRefreshState] = []
}

@MainActor
@Suite("VolumeRefreshController")
struct VolumeRefreshControllerTests {
    @Test("a burst of events restarts the 500 ms debounce and refreshes once")
    func burstCausesSingleRefreshAfterDebounce() async {
        let enumerator = ScriptedEnumerator([.success([mount("A")])])
        let clock = GatedSleeper(blockedSleeps: 1)
        let recorder = StateRecorder()
        let controller = VolumeRefreshController(enumerator: enumerator, clock: clock) { recorder.states.append($0) }

        controller.volumeEventOccurred()
        controller.volumeEventOccurred()
        await controller.pending?.value

        #expect(clock.durations == [0.5, 0.5])
        #expect(enumerator.callCount == 1)
        #expect(recorder.states.map { $0.entries.map(\.displayName) } == [["A"]])
    }

    @Test("a cancelled debounce never enumerates")
    func stopCancelsPendingRefresh() async {
        let enumerator = ScriptedEnumerator([.success([])])
        let clock = GatedSleeper(blockedSleeps: 1)
        let controller = VolumeRefreshController(enumerator: enumerator, clock: clock) { _ in }

        controller.volumeEventOccurred()
        let task = controller.pending
        controller.stop()
        await task?.value

        #expect(enumerator.callCount == 0)
    }

    @Test("enumeration failure keeps the previous list and sets the failure flag")
    func failureKeepsPreviousList() async {
        let enumerator = ScriptedEnumerator([
            .success([mount("A")]), .failure(.lsofUnavailable), .success([mount("B")])
        ])
        let recorder = StateRecorder()
        let controller = VolumeRefreshController(
            enumerator: enumerator,
            clock: GatedSleeper(blockedSleeps: 0)
        ) { recorder.states.append($0) }

        for _ in 0..<3 {
            controller.refreshNow()
            await controller.pending?.value
        }

        #expect(recorder.states.map(\.enumerationFailed) == [false, true, false])
        #expect(recorder.states[1].entries.map(\.displayName) == ["A"])
        #expect(recorder.states[2].entries.map(\.displayName) == ["B"])
    }

    @Test("refreshNow skips the debounce")
    func refreshNowDoesNotSleep() async {
        let clock = GatedSleeper(blockedSleeps: 0)
        let controller = VolumeRefreshController(
            enumerator: ScriptedEnumerator([.success([])]),
            clock: clock
        ) { _ in }

        controller.refreshNow()
        await controller.pending?.value

        #expect(clock.durations.isEmpty)
    }

    @Test("events from the source trigger a refresh and stop detaches the source")
    func sourceEventsDriveRefresh() async {
        let source = FakeEventSource()
        let enumerator = ScriptedEnumerator([.success([mount("A")])])
        let controller = VolumeRefreshController(
            enumerator: enumerator,
            clock: GatedSleeper(blockedSleeps: 0),
            source: source
        ) { _ in }

        controller.start()
        source.fire()
        await controller.pending?.value
        #expect(enumerator.callCount == 1)

        controller.stop()
        #expect(source.stopCount == 1)
    }
}
