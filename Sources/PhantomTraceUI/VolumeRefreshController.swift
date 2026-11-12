import Foundation
import PhantomTraceCore

/// What the list and submenu show after a refresh. Requirements 19.9, 19.11.
public struct VolumeRefreshState: Equatable, Sendable {
    public var entries: [VolumeListEntry]
    /// True when the latest enumeration failed; `entries` then still holds the previous list.
    public var enumerationFailed: Bool

    public init(entries: [VolumeListEntry] = [], enumerationFailed: Bool = false) {
        self.entries = entries
        self.enumerationFailed = enumerationFailed
    }
}

/// Source of "a volume was mounted, unmounted, or renamed" events. The live one wraps
/// `NSWorkspace`; tests drive a fake.
@MainActor
public protocol VolumeEventSource: AnyObject {
    /// Starts delivering events to `handler` on the main actor.
    func start(handler: @escaping @MainActor () -> Void)
    func stop()
}

/// Keeps the volume list current. Events are coalesced with a debounce that restarts on each event;
/// each refresh enumerates off the main actor, filters with `VolumeLister`, and publishes on the main
/// actor. On enumeration failure the previous list is kept and the failure flag is set.
/// Requirements 19.9, 19.11. Uses the injected clock, so tests never sleep.
@MainActor
public final class VolumeRefreshController {
    /// Debounce window; the refresh itself must finish within 1000 ms of the last event.
    public static let debounceSeconds: TimeInterval = 0.5

    public private(set) var state = VolumeRefreshState()
    /// The in-flight debounce or refresh, exposed so tests can await it.
    public private(set) var pending: Task<Void, Never>?

    private let enumerator: any MountedVolumeEnumerating
    private let clock: any Sleeping
    private let source: (any VolumeEventSource)?
    private let onChange: @MainActor (VolumeRefreshState) -> Void

    /// - Parameter onChange: called on the main actor after every completed refresh, success or failure.
    public init(
        enumerator: any MountedVolumeEnumerating,
        clock: any Sleeping,
        source: (any VolumeEventSource)? = nil,
        onChange: @escaping @MainActor (VolumeRefreshState) -> Void
    ) {
        self.enumerator = enumerator
        self.clock = clock
        self.source = source
        self.onChange = onChange
    }

    /// Begins observing the event source.
    public func start() {
        source?.start { [weak self] in self?.volumeEventOccurred() }
    }

    public func stop() {
        source?.stop()
        pending?.cancel()
        pending = nil
    }

    /// One mount, unmount, or rename event. Restarts the debounce window.
    public func volumeEventOccurred() {
        pending?.cancel()
        let clock = clock
        pending = Task { [weak self] in
            do {
                try await clock.sleep(seconds: Self.debounceSeconds)
            } catch {
                return
            }
            await self?.performRefresh()
        }
    }

    /// Refreshes immediately without debounce, for example when the drop window is shown.
    public func refreshNow() {
        pending?.cancel()
        pending = Task { [weak self] in
            await self?.performRefresh()
        }
    }

    private func performRefresh() async {
        let result = await Self.enumerateOffMain(using: enumerator)
        guard !Task.isCancelled else { return }
        switch result {
        case let .success(entries):
            state = VolumeRefreshState(entries: entries, enumerationFailed: false)
        case .failure:
            state = VolumeRefreshState(entries: state.entries, enumerationFailed: true)
        }
        onChange(state)
    }

    private nonisolated static func enumerateOffMain(
        using enumerator: any MountedVolumeEnumerating
    ) async -> Result<[VolumeListEntry], any Error> {
        await Task.detached(priority: .userInitiated) {
            Result { VolumeLister.list(try enumerator.enumerate()) }
        }.value
    }
}
