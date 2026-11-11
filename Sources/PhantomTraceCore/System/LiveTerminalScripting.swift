import Foundation

/// Live `TerminalScripting`: asks Terminal.app, then iTerm2, to type the fixed literal ` cd ~` plus a return
/// into the tab or session that owns a tty (Requirements 7.2, 7.5, 7.7, 15.1).
///
/// Safety shape:
/// - Each script is a compile-time constant. The only text typed is the constant `injectedText`; the tty is
///   passed as an `osascript` argument (read from `argv`), never interpolated into script source.
/// - The tty must look like `/dev/ttysNNN` before anything runs; anything else is `unsupportedTerminal`.
/// - `osascript` is launched through `ProcessRunning` with an absolute path and an argument array.
/// - An Automation (TCC) denial returns `automationDenied` immediately. There is no retry and no second
///   terminal is tried, so the user is never prompted in a loop (macos-platform.md).
/// - Any other failure (app not running, tty not found, timeout, launch error) is reported as
///   `unsupportedTerminal` ("not scriptable") rather than thrown.
///
/// Terminal's `do script` and iTerm's `write text` both append the return themselves, so the keystrokes
/// delivered are exactly ` cd ~\n`.
public struct LiveTerminalScripting: TerminalScripting {
    /// The only text this adapter can type. Kept here so tests can assert on it.
    public static let injectedText = " cd ~"

    static let osascriptURL = URL(fileURLWithPath: "/usr/bin/osascript")
    static let sentMarker = "sent"

    static let terminalScript = """
    on run argv
        set target to item 1 of argv
        if application "Terminal" is not running then return "notfound"
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is target then
                        do script "\(injectedText)" in t
                        return "\(sentMarker)"
                    end if
                end repeat
            end repeat
        end tell
        return "notfound"
    end run
    """

    static let iTermScript = """
    on run argv
        set target to item 1 of argv
        if application "iTerm" is not running then return "notfound"
        tell application "iTerm"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s is target then
                            tell s to write text "\(injectedText)"
                            return "\(sentMarker)"
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        return "notfound"
    end run
    """

    private let runner: any ProcessRunning
    private let timeout: TimeInterval

    public init(runner: any ProcessRunning, timeout: TimeInterval = 10) {
        self.runner = runner
        self.timeout = timeout
    }

    public func sendChangeDirectoryHome(toTerminalDevice device: String) async -> TerminalScriptOutcome {
        guard Self.isTerminalDevicePath(device) else { return .unsupportedTerminal }
        for script in [Self.terminalScript, Self.iTermScript] {
            switch await attempt(script: script, device: device) {
            case .sent: return .sent
            case .automationDenied: return .automationDenied
            case .unsupportedTerminal: continue
            }
        }
        return .unsupportedTerminal
    }

    /// Argument array for one `osascript` run: the constant script, then the tty as data.
    static func arguments(script: String, device: String) -> [String] {
        ["-e", script, device]
    }

    /// Accepts only `/dev/tty` followed by a nonempty run of ASCII letters and digits.
    static func isTerminalDevicePath(_ device: String) -> Bool {
        let prefix = "/dev/tty"
        guard device.hasPrefix(prefix) else { return false }
        let suffix = device.dropFirst(prefix.count)
        guard !suffix.isEmpty, suffix.count <= 16 else { return false }
        return suffix.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x61 && byte <= 0x7A) || (byte >= 0x41 && byte <= 0x5A)
        }
    }

    /// True when `osascript` stderr reports a missing Automation grant (error -1743, "Not authorized").
    static func indicatesAutomationDenial(_ standardError: Data) -> Bool {
        let text = String(bytes: standardError, encoding: .utf8) ?? ""
        return text.contains("-1743") || text.localizedCaseInsensitiveContains("not authorized")
    }

    private func attempt(script: String, device: String) async -> TerminalScriptOutcome {
        let output: ProcessOutput
        do {
            output = try await runner.run(
                executable: Self.osascriptURL,
                arguments: Self.arguments(script: script, device: device),
                timeout: timeout
            )
        } catch {
            return .unsupportedTerminal
        }
        if Self.indicatesAutomationDenial(output.standardError) { return .automationDenied }
        guard output.exitStatus == 0 else { return .unsupportedTerminal }
        let reply = (String(bytes: output.standardOutput, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return reply == Self.sentMarker ? .sent : .unsupportedTerminal
    }
}
