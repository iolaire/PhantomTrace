import Foundation
/// The failed actions of a Stage_Outcome as the sheet shows them: at most 500 entries and a count
/// of the rest (Requirement 14.5).
public struct FailedActionList: Equatable, Sendable {
    public static let maximumEntries = 500
    public let entries: [FailedAction]
    public let omittedCount: Int
    public init(entries: [FailedAction] = [], omittedCount: Int = 0) {
        self.entries = entries
        self.omittedCount = omittedCount
    }
    /// Caps `actions` at `maximumEntries`, keeping their order.
    public init(capping actions: [FailedAction]) {
        self.init(
            entries: Array(actions.prefix(Self.maximumEntries)),
            omittedCount: max(0, actions.count - Self.maximumEntries)
        )
    }
}
