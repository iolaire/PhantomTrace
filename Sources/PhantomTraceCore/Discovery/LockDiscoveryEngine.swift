import Foundation

/// Runs `lsof`, parses and classifies its output, and merges the result (Requirements 3.1-3.8).
///
/// Every system question goes through injected protocols. It is a stateless value type, so a scan runs on the
/// caller's executor (never the main actor unless the caller is on it) and repeated runs are deterministic.
public struct LockDiscoveryEngine: LockDiscovering {
    public static let lsofURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    public static let fuserURL = URL(fileURLWithPath: "/usr/bin/fuser")
    /// Requirement 3.6: limit for `lsof` and for each fallback command.
    public static let scanTimeout: TimeInterval = 15
    /// `+c 0` keeps full command names, so the daemon allowlist matches (names are cut at 9 characters otherwise).
    static let fieldArguments = ["-F", "pcLnftau0", "-w"]

    private let runner: any ProcessRunning
    private let classifier: any LockClassifying
    private let processes: any ProcessInspecting

    public init(
        runner: any ProcessRunning,
        classifier: any LockClassifying,
        processes: any ProcessInspecting
    ) {
        self.runner = runner
        self.classifier = classifier
        self.processes = processes
    }

    public func discover(in volume: MountInfo) async throws -> DiscoveryResult {
        // Requirement 2.1: a protected volume is never scanned. Checked before any subprocess runs.
        guard !MountResolver.isProtected(volume.mountPoint) else {
            throw PhantomTraceError.protectedVolume(volume.mountPoint)
        }
        let mountPath = volume.mountPoint.path
        var raws: [RawLsofRecord] = []
        var warnings: [ParseWarning] = []
        var partial = false
        var timedOut = false
        do {
            let output = try await runner.run(
                executable: Self.lsofURL,
                arguments: Self.fieldArguments + ["+f", "+c", "0", "--", mountPath],
                timeout: Self.scanTimeout
            )
            let parsed = LsofParser.parse(output.standardOutput)
            raws = parsed.records
            warnings = parsed.warnings
            // Requirement 3.6: a truncated tail means the scan is incomplete.
            partial = parsed.warnings.contains { if case .truncatedTail = $0 { true } else { false } }
        } catch PhantomTraceError.lsofTimedOut {
            timedOut = true
            partial = true
        }
        if partial {
            let extra = await fallbackFindings(mountPath: mountPath, known: raws)
            raws += extra.records
            warnings += extra.warnings
            // Requirement 3.8: a timeout with nothing from the fallback is an error.
            if timedOut, extra.records.isEmpty {
                throw PhantomTraceError.lsofTimedOut(seconds: Self.scanTimeout)
            }
        }
        let locks = raws.compactMap { classifier.classify($0, volume: volume) }
        return DiscoveryResult(locks: finalize(locks), partial: partial, warnings: warnings)
    }

    // MARK: - Fallback (Requirement 3.6)

    private struct Fallback {
        var records: [RawLsofRecord] = []
        var warnings: [ParseWarning] = []
    }

    /// Runs `lsof +D` and `fuser -c`, each limited to 15 s. A failure of either is swallowed, not fatal.
    private func fallbackFindings(mountPath: String, known: [RawLsofRecord]) async -> Fallback {
        var result = Fallback()
        if let output = try? await runner.run(
            executable: Self.lsofURL,
            arguments: Self.fieldArguments + ["+c", "0", "+D", mountPath],
            timeout: Self.scanTimeout
        ) {
            let parsed = LsofParser.parse(output.standardOutput)
            result.records = parsed.records
            result.warnings = parsed.warnings
        }
        if let output = try? await runner.run(
            executable: Self.fuserURL,
            arguments: ["-c", mountPath],
            timeout: Self.scanTimeout
        ) {
            let seen = Set((known + result.records).map(\.pid))
            let pids = Self.fuserPIDs(from: output).subtracting(seen)
            result.records += pids.sorted().map { fuserRecord(pid: $0, mountPath: mountPath) }
        }
        return result
    }

    /// `fuser` knows only pids, so its findings become open-handle records on the mount point itself.
    private func fuserRecord(pid: UInt32, mountPath: String) -> RawLsofRecord {
        let name = Int32(exactly: pid).flatMap { processes.inspect(pid: $0) }?
            .executablePath?.lastPathComponent ?? "unknown"
        return RawLsofRecord(
            pid: pid,
            commandBytes: Data(name.utf8),
            fileDescriptor: "fuser",
            pathBytes: Data(mountPath.utf8)
        )
    }

    /// Reads pid tokens such as `123` or `123c` from either stream; the `path:` header never matches.
    static func fuserPIDs(from output: ProcessOutput) -> Set<UInt32> {
        let text = RawLsofRecord.displayString(output.standardOutput + Data(" ".utf8) + output.standardError)
        var pids = Set<UInt32>()
        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            let digits = token.prefix { $0.isASCII && $0.isNumber }
            let flags = token.dropFirst(digits.count)
            guard !digits.isEmpty, flags.allSatisfy({ $0.isASCII && $0.isLetter }),
                  let pid = UInt32(digits), pid > 0 else { continue }
            pids.insert(pid)
        }
        return pids
    }

    // MARK: - Merge, exclude, order (Requirements 3.3, 3.4, 3.5)

    private func finalize(_ locks: [LockRecord]) -> [LockRecord] {
        let own = processes.currentProcessID
        var merged: [MergeKey: LockRecord] = [:]
        for lock in locks where Int32(exactly: lock.pid) != own {
            let key = MergeKey(pid: lock.pid, pathBytes: lock.pathBytes)
            if let existing = merged[key] {
                // A working-directory hold is the more telling one; otherwise the first record wins.
                if existing.category != .cwd, lock.category == .cwd { merged[key] = lock }
            } else {
                merged[key] = lock
            }
        }
        return merged.values.sorted { lhs, rhs in
            if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
            return lhs.pathBytes.lexicographicallyPrecedes(rhs.pathBytes)
        }
    }

    private struct MergeKey: Hashable {
        let pid: UInt32
        let pathBytes: Data
    }
}
