import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

/// Unit tests for process role assignment in `LockClassifier`.
/// **Validates: Requirements 5.3, 5.4, 5.5, 5.9, 5.10, 5.11**
struct LockClassifierRoleTests {
    private static let pid: UInt32 = 700
    private static let startTime = Date(timeIntervalSince1970: 1_700_000_000)
    private static let volume = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/A"),
        volumeName: "A",
        deviceNode: "/dev/disk4s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: false
    )

    private static func details(
        terminal: String? = nil,
        group: Int32 = 700,
        foreground: Int32? = nil,
        executable: String? = nil
    ) -> ProcessDetails {
        ProcessDetails(
            identity: ProcessIdentity(pid: pid, startTime: startTime),
            ownerUserID: 501,
            terminalDevice: terminal,
            processGroupID: group,
            foregroundProcessGroupID: foreground,
            currentDirectory: nil,
            executablePath: executable.map { URL(fileURLWithPath: $0) }
        )
    }

    private static func classify(command: String, details: ProcessDetails?) -> LockRecord? {
        let inspector = MockProcessInspector()
        inspector.setDetails(details, forPID: Int32(pid))
        let classifier = LockClassifier(fileSystem: MockFileSystemProbe(), processes: inspector)
        let raw = RawLsofRecord(
            pid: pid,
            commandBytes: Data(command.utf8),
            user: "me",
            fileDescriptor: "cwd",
            pathBytes: Data("/Volumes/A/work".utf8)
        )
        return classifier.classify(raw, volume: volume)
    }

    // MARK: - Daemon allowlist (5.3)

    @Test(arguments: LockClassifier.daemonAllowlist.sorted())
    func everyAllowlistedDaemonIsSystemDaemon(name: String) {
        #expect(Self.classify(command: name, details: Self.details())?.role == .systemDaemon)
    }

    @Test(arguments: LockClassifier.daemonAllowlist.sorted())
    func allowlistedDaemonStaysSystemDaemonWithTerminalAndForegroundGroup(name: String) {
        let busy = Self.details(terminal: "/dev/ttys001", group: 700, foreground: 700)
        #expect(Self.classify(command: name, details: busy)?.role == .systemDaemon)
    }

    @Test func allowlistedDaemonIsSystemDaemonEvenWhenProcessDetailsAreMissing() {
        #expect(Self.classify(command: "mds", details: nil)?.role == .systemDaemon)
    }

    @Test func daemonNameMatchIsExactNotPrefix() {
        #expect(Self.classify(command: "mds_extra", details: Self.details())?.role == .unknown)
    }

    // MARK: - Shells (5.4)

    @Test(arguments: LockClassifier.shellSet.sorted())
    func everyShellVariantIsIdleWhenItOwnsTheForeground(name: String) {
        let idle = Self.details(terminal: "/dev/ttys001", group: 700, foreground: 700)
        #expect(Self.classify(command: name, details: idle)?.role == .idleShell)
    }

    @Test(arguments: LockClassifier.shellSet.sorted())
    func everyShellVariantRunningAForegroundJobIsCliTool(name: String) {
        let busy = Self.details(terminal: "/dev/ttys001", group: 700, foreground: 912)
        #expect(Self.classify(command: name, details: busy)?.role == .cliTool)
    }

    @Test(arguments: LockClassifier.shellSet.sorted())
    func shellWithUndeterminableForegroundGroupIsNeverIdle(name: String) {
        let unknown = Self.details(terminal: "/dev/ttys001", group: 700, foreground: nil)
        #expect(Self.classify(command: name, details: unknown)?.role == .cliTool)
    }

    @Test func shellWithoutControllingTerminalIsNeverIdle() {
        let detached = Self.details(terminal: nil, group: 700, foreground: 700)
        #expect(Self.classify(command: "zsh", details: detached)?.role == .unknown)
    }

    @Test func shellWithoutProcessDetailsIsUnknown() {
        #expect(Self.classify(command: "bash", details: nil)?.role == .unknown)
    }

    @Test func nonShellProcessOwningTheForegroundIsCliToolNotIdleShell() {
        let foreground = Self.details(terminal: "/dev/ttys002", group: 700, foreground: 700)
        #expect(Self.classify(command: "vim", details: foreground)?.role == .cliTool)
    }

    // MARK: - Other roles (5.5)

    @Test func processInsideAnAppBundleWithoutTerminalIsUserApplication() {
        let app = Self.details(executable: "/Applications/Notes.app/Contents/MacOS/Notes")
        #expect(Self.classify(command: "Notes", details: app)?.role == .userApplication)
    }

    @Test func terminalTakesPrecedenceOverAppBundleExecutable() {
        let app = Self.details(
            terminal: "/dev/ttys003",
            executable: "/Applications/Notes.app/Contents/MacOS/Notes"
        )
        #expect(Self.classify(command: "Notes", details: app)?.role == .cliTool)
    }

    @Test func processWithNoTerminalAndNoAppBundleIsUnknown() {
        let plain = Self.details(executable: "/usr/local/bin/tool")
        #expect(Self.classify(command: "tool", details: plain)?.role == .unknown)
    }

    @Test func appSuffixOnTheExecutableNameAloneDoesNotCountAsBundle() {
        let plain = Self.details(executable: "/usr/local/bin/helper.app")
        #expect(Self.classify(command: "helper", details: plain)?.role == .unknown)
    }

    @Test func processWithNoKnownExecutableAndNoTerminalIsUnknown() {
        #expect(Self.classify(command: "mystery", details: Self.details())?.role == .unknown)
    }

    // MARK: - Start time (5.9, 5.10, 5.11)

    @Test func recordsProcessStartTimeWhenObtainable() {
        let record = Self.classify(command: "cat", details: Self.details(terminal: "/dev/ttys001"))
        #expect(record?.processStart == Self.startTime)
    }

    @Test func missingProcessDetailsKeepTheRecordWithAbsentStartTimeAndUnknownRole() {
        let record = Self.classify(command: "cat", details: nil)
        #expect(record != nil)
        #expect(record?.processStart == nil)
        #expect(record?.role == .unknown)
        #expect(record?.pid == Self.pid)
        #expect(record?.path == "/Volumes/A/work")
    }
}
