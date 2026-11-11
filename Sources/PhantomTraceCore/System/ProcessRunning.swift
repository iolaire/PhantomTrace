import Foundation

/// Runs one subprocess and captures its output.
///
/// No protocol in `System/` accepts a shell command string (Requirement 15.1, 15.6). Callers pass an absolute
/// executable URL and an argument array, so file names and process names stay inert data and are never parsed
/// by a shell. Live implementations must never launch `/bin/sh -c`.
public protocol ProcessRunning: Sendable {
    /// Runs `executable` with `arguments` and returns the captured bytes.
    ///
    /// On timeout the implementation terminates and reaps the process, discards partial output, and throws
    /// `PhantomTraceError.lsofTimedOut` for `lsof` or another error naming the command. Cancellation also
    /// terminates the process.
    /// - Parameters:
    ///   - executable: absolute file URL of the tool, for example `/usr/sbin/lsof`.
    ///   - arguments: one array element per argument; no quoting, no shell syntax.
    ///   - timeout: seconds before the process is terminated.
    func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessOutput
}
