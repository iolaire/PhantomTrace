import Foundation
import PhantomTraceCore

/// A throwaway 10 MB APFS disk image attached under a private temp directory, plus the helper processes the
/// test itself spawns. Only used by the local-only integration test; it never names a real volume.
final class DiskImageFixture {
    enum FixtureError: Error {
        case hdiutilFailed(arguments: [String], status: Int32)
        case attachOutputUnreadable
    }

    static let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")

    /// Canonical (realpath) mount point, so it matches what `lsof` and the mount table report.
    let mountPoint: URL
    let heldFile: URL
    let imageURL: URL
    private let workDirectory: URL
    private let wholeDiskNode: String
    private let runner = LiveProcessRunner()
    private var helpers: [Process] = []

    private init(workDirectory: URL, imageURL: URL, mountPoint: URL, wholeDiskNode: String) {
        self.workDirectory = workDirectory
        self.imageURL = imageURL
        self.mountPoint = mountPoint
        self.heldFile = mountPoint.appendingPathComponent("held.txt")
        self.wholeDiskNode = wholeDiskNode
    }

    /// Creates and attaches the image. On any failure after the image exists, everything is cleaned up.
    static func make() async throws -> DiskImageFixture {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("phantomtrace-it-\(UUID().uuidString)", isDirectory: true)
        let mount = work.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        let image = work.appendingPathComponent("throwaway.dmg")
        let runner = LiveProcessRunner()
        var attachedDisk: String?
        do {
            try await expectSuccess(
                runner, ["create", "-size", "10m", "-fs", "APFS", "-volname", "PTThrowaway", image.path]
            )
            let output = try await expectSuccess(
                runner, ["attach", "-nobrowse", "-noverify", "-plist", "-mountpoint", mount.path, image.path]
            )
            let disk = try wholeDisk(fromAttachPlist: output.standardOutput)
            attachedDisk = disk
            let canonical = LiveFileSystemProbe().canonicalURL(for: mount) ?? mount
            let fixture = DiskImageFixture(
                workDirectory: work, imageURL: image, mountPoint: canonical, wholeDiskNode: disk
            )
            try Data("held by a helper\n".utf8).write(to: fixture.heldFile)
            return fixture
        } catch {
            if let attachedDisk {
                _ = try? await runner.run(
                    executable: hdiutil, arguments: ["detach", "-force", attachedDisk], timeout: 30
                )
            }
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    /// Spawns `tail -f` on the held file (an open file handle) and a `sh` whose cwd is the mount point.
    /// Returns the pids as `(fileHolder, cwdHolder)`.
    func spawnHelpers() throws -> (fileHolder: UInt32, cwdHolder: UInt32) {
        let tail = Process()
        tail.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        tail.arguments = ["-f", heldFile.path]
        tail.standardOutput = FileHandle.nullDevice
        tail.standardError = FileHandle.nullDevice
        try tail.run()
        helpers.append(tail)

        // A fixed literal script; nothing from the environment is interpolated. The shell blocks reading a pipe
        // that this test keeps open, so its working directory stays on the image until it is terminated.
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "read line"]
        shell.currentDirectoryURL = mountPoint
        shell.standardInput = Pipe()
        shell.standardOutput = FileHandle.nullDevice
        shell.standardError = FileHandle.nullDevice
        try shell.run()
        helpers.append(shell)
        return (UInt32(tail.processIdentifier), UInt32(shell.processIdentifier))
    }

    /// Terminates and reaps only the helpers this fixture spawned.
    ///
    /// Polls `isRunning` instead of calling `waitUntilExit()`: that call spins the current run loop for a
    /// termination notification, and on a Swift concurrency thread it can block forever after the child has
    /// already been reaped. A helper still alive after the SIGTERM grace gets SIGKILL.
    func stopHelpers() async {
        for helper in helpers where helper.isRunning {
            helper.terminate()
        }
        if await !waitForHelpersToExit(seconds: 5) {
            for helper in helpers where helper.isRunning {
                kill(helper.processIdentifier, SIGKILL)
            }
            _ = await waitForHelpersToExit(seconds: 5)
        }
        helpers.removeAll()
    }

    private func waitForHelpersToExit(seconds: Int) async -> Bool {
        for _ in 0..<(seconds * 20) {
            if !helpers.contains(where: \.isRunning) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !helpers.contains(where: \.isRunning)
    }

    /// Always safe to call: stops helpers, detaches the whole image device, deletes the temp directory.
    func cleanUp() async {
        await stopHelpers()
        _ = try? await runner.run(
            executable: Self.hdiutil, arguments: ["detach", "-force", wholeDiskNode], timeout: 30
        )
        try? FileManager.default.removeItem(at: workDirectory)
    }

    // MARK: - hdiutil

    @discardableResult
    private static func expectSuccess(
        _ runner: LiveProcessRunner,
        _ arguments: [String]
    ) async throws -> ProcessOutput {
        let output = try await runner.run(executable: hdiutil, arguments: arguments, timeout: 60)
        guard output.exitStatus == 0 else {
            throw FixtureError.hdiutilFailed(arguments: arguments, status: output.exitStatus)
        }
        return output
    }

    /// The whole-disk node is the shortest `dev-entry` (`/dev/disk5` rather than `/dev/disk5s1`).
    private static func wholeDisk(fromAttachPlist data: Data) throws -> String {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = root["system-entities"] as? [[String: Any]] else {
            throw FixtureError.attachOutputUnreadable
        }
        let nodes = entities.compactMap { $0["dev-entry"] as? String }
        guard let whole = nodes.min(by: { $0.count < $1.count }) else {
            throw FixtureError.attachOutputUnreadable
        }
        return whole
    }
}
