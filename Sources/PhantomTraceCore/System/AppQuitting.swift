import Foundation

/// Asks a GUI application to quit. The live adapter lives in the app target because it needs AppKit
/// (`NSRunningApplication`); Core only sees this protocol (Requirement 15.4).
public protocol AppQuitting: Sendable {
    /// True when `pid` belongs to a GUI application that can be asked to quit.
    func isGUIApplication(pid: Int32) -> Bool

    /// Requests a graceful quit. Returns `false` when the request could not be delivered.
    func requestQuit(pid: Int32) async -> Bool
}
