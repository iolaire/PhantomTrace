import Foundation

/// Egress Shells actions of the last stage that the user must finish by hand, capped like
/// `FailedActionList` so a huge stage cannot flood the window (Requirements 7.5, 14.5).
public struct ManualActionList: Equatable, Sendable {
    public static let maximumEntries = FailedActionList.maximumEntries
    public let entries: [ManualAction]
    public let omittedCount: Int
    public init(entries: [ManualAction] = [], omittedCount: Int = 0) {
        self.entries = entries
        self.omittedCount = omittedCount
    }
    /// Caps `actions` at `maximumEntries`, keeping their order.
    public init(capping actions: [ManualAction]) {
        self.init(
            entries: Array(actions.prefix(Self.maximumEntries)),
            omittedCount: max(0, actions.count - Self.maximumEntries)
        )
    }
}
