import Foundation
import PhantomTraceCore

/// Scripted `TerminalScripting`. Never talks to a terminal.
public final class MockTerminalScripter: TerminalScripting {
    public let script: Script<TerminalScriptOutcome>
    public let log = CallLog<String>()

    public init(fallback: TerminalScriptOutcome = .sent) {
        script = Script(fallback: fallback)
    }

    /// Terminal devices passed to `sendChangeDirectoryHome`, in call order.
    public var calls: [String] { log.calls }

    public func sendChangeDirectoryHome(toTerminalDevice device: String) async -> TerminalScriptOutcome {
        log.record(device)
        return script.next()
    }
}
