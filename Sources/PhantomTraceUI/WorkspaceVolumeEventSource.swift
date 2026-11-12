import AppKit

/// Live `VolumeEventSource`: observes `NSWorkspace` mount, unmount, and rename notifications.
/// Only this file touches `NSWorkspace` for volume events; the refresh logic stays testable without it.
@MainActor
public final class WorkspaceVolumeEventSource: VolumeEventSource {
    private var tokens: [any NSObjectProtocol] = []

    public init() {}

    public func start(handler: @escaping @MainActor () -> Void) {
        stop()
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { handler() }
            }
        }
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for token in tokens { center.removeObserver(token) }
        tokens = []
    }
}
