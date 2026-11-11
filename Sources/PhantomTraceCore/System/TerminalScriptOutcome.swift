import Foundation

/// Result of asking a terminal application to run the fixed `cd ~` literal.
public enum TerminalScriptOutcome: Equatable, Sendable {
    case sent
    /// The user has not granted Automation permission. The caller shows a manual instruction and never retries.
    case automationDenied
    /// No supported terminal owns that tty.
    case unsupportedTerminal
}
