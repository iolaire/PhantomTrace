import Foundation

/// Types the fixed literal ` cd ~\n` into the terminal session that owns a tty.
///
/// The text is a constant inside the adapter. The protocol takes only a tty device path and has no text or
/// command parameter, so nothing derived from process data can be injected (Requirement 15.1, 15.6).
public protocol TerminalScripting: Sendable {
    func sendChangeDirectoryHome(toTerminalDevice device: String) async -> TerminalScriptOutcome
}
