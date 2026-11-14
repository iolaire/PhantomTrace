import Foundation

/// What the CLI should write and how it should exit. Kept as data so tests never touch real streams.
public struct CommandResult: Equatable, Sendable {
    public let standardOutput: String
    public let standardError: String
    public let exitCode: Int32

    public init(standardOutput: String = "", standardError: String = "", exitCode: Int32) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
    }
}

/// The `phantomtrace <path>` command: resolve the volume, run discovery, print Lock_Records.
///
/// Requirements 12.5, 12.6, 12.7. It is read-only: it never signals a process or unmounts, and it reaches the
/// system only through the injected resolver and discovery protocols.
public struct InspectCommand: Sendable {
    public static let usage = "usage: phantomtrace <path | phantomtrace://inspect?path=...>"
    private let urlParser: InspectURLParser
    private let resolver: any MountResolving
    private let discovery: any LockDiscovering

    public init(urlParser: InspectURLParser, resolver: any MountResolving, discovery: any LockDiscovering) {
        self.urlParser = urlParser
        self.resolver = resolver
        self.discovery = discovery
    }

    /// `arguments` excludes the executable name.
    public func run(arguments: [String]) async -> CommandResult {
        guard arguments.count == 1, let argument = arguments.first, !argument.isEmpty else {
            return Self.failure(arguments.isEmpty ? "no path given" : "expected exactly one path")
        }
        let path: String
        switch inputPath(argument) {
        case let .success(value):
            path = value
        case let .failure(error):
            return Self.failure("invalid path: \(error.reason)")
        }
        do {
            let mount = try await resolver.resolve(URL(fileURLWithPath: path))
            let result = try await discovery.discover(in: mount)
            return Self.success(result)
        } catch let error as PhantomTraceError {
            return Self.failure(Self.message(for: error))
        } catch {
            return Self.failure("could not inspect the volume")
        }
    }

    private func inputPath(_ argument: String) -> Result<String, InspectURLError> {
        if argument.lowercased().hasPrefix("\(InspectURLParser.scheme):") {
            return urlParser.parse(argument)
        }
        // A plain path goes through the same checks as the URL form, via a percent-encoded URL.
        let encoded = argument.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return urlParser.parse("\(InspectURLParser.scheme)://\(InspectURLParser.host)?path=\(encoded)")
    }

    // MARK: - Output

    private static func success(_ result: DiscoveryResult) -> CommandResult {
        let lines = result.locks.map(line(for:))
        let output = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        var notes: [String] = []
        if result.partial {
            notes.append("warning: the scan was incomplete; results may be missing locks")
        }
        if !result.warnings.isEmpty {
            notes.append("warning: \(result.warnings.count) unreadable lsof entries were skipped")
        }
        return CommandResult(
            standardOutput: output,
            standardError: notes.isEmpty ? "" : notes.joined(separator: "\n") + "\n",
            exitCode: 0
        )
    }

    /// One tab-separated record: pid, name, user, category, role, path. Control characters are escaped so
    /// a hostile file name cannot forge extra lines or columns.
    static func line(for lock: LockRecord) -> String {
        [
            String(lock.pid),
            lock.processName,
            lock.user,
            lock.category.rawValue,
            lock.role.rawValue,
            lock.path
        ].map(escape).joined(separator: "\t")
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    result += "\\x" + String(format: "%02X", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result
    }

    private static func failure(_ reason: String) -> CommandResult {
        CommandResult(standardError: "phantomtrace: \(reason)\n\(usage)\n", exitCode: 1)
    }

    private static func message(for error: PhantomTraceError) -> String {
        switch error {
        case let .notAMountPoint(url):
            return "\(url.path) is not on a mounted volume"
        case let .protectedVolume(url):
            return "\(url.path) is on a protected volume and is never scanned"
        case .lsofUnavailable:
            return "lsof is unavailable"
        case let .lsofTimedOut(seconds):
            return "lsof timed out after \(Int(seconds)) seconds"
        case let .commandTimedOut(command, seconds):
            return "\(command) timed out after \(Int(seconds)) seconds"
        case let .commandLaunchFailed(command):
            return "could not launch \(command)"
        case .cancelled:
            return "cancelled"
        case .permissionDenied, .processIdentityChanged, .safetyDenied, .unmountBusy, .unmountFailed:
            return "could not inspect the volume"
        }
    }
}
