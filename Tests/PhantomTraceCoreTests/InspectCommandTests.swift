import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct InspectCommandTests {
    private let mount = MountInfo(
        mountPoint: URL(fileURLWithPath: "/Volumes/Test"),
        volumeName: "Test",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: true
    )

    private func lock(
        pid: UInt32 = 42,
        name: String = "cat",
        path: String = "/Volumes/Test/a.txt"
    ) -> LockRecord {
        LockRecord(
            pid: pid,
            processName: name,
            user: "me",
            category: .openFileHandle,
            role: .cliTool,
            path: path,
            pathBytes: Data(path.utf8)
        )
    }

    private func makeCommand(
        resolver: MockMountResolver? = nil,
        discovery: Result<DiscoveryResult, PhantomTraceError> = .success(DiscoveryResult(locks: []))
    ) -> (InspectCommand, MockLockDiscovery) {
        let canonicalizer = MockInspectPathCanonicalizer(results: ["/Volumes/Test": "/Volumes/Test"])
        let mock = MockLockDiscovery(fallback: discovery)
        let command = InspectCommand(
            urlParser: InspectURLParser(canonicalizer: canonicalizer),
            resolver: resolver ?? MockMountResolver(mounts: [mount]),
            discovery: mock
        )
        return (command, mock)
    }

    @Test func successPrintsOneTabSeparatedLinePerLockAndExitsZero() async {
        let (command, mock) = makeCommand(discovery: .success(DiscoveryResult(locks: [lock(), lock(pid: 7)])))
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.exitCode == 0)
        #expect(result.standardError.isEmpty)
        #expect(result.standardOutput == """
            42\tcat\tme\topenFileHandle\tcliTool\t/Volumes/Test/a.txt
            7\tcat\tme\topenFileHandle\tcliTool\t/Volumes/Test/a.txt

            """)
        #expect(mock.log.calls == [mount.mountPoint])
    }

    @Test func cleanVolumeExitsZeroWithEmptyOutput() async {
        let (command, _) = makeCommand()
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result == CommandResult(exitCode: 0))
    }

    @Test func urlFormIsAcceptedLikeAPlainPath() async {
        let (command, mock) = makeCommand()
        let result = await command.run(arguments: ["phantomtrace://inspect?path=%2FVolumes%2FTest"])
        #expect(result.exitCode == 0)
        #expect(mock.log.calls.count == 1)
    }

    @Test func partialScanAndWarningsGoToStandardErrorWithExitZero() async {
        let scan = DiscoveryResult(locks: [lock()], partial: true, warnings: [.invalidPid(offset: 3)])
        let (command, _) = makeCommand(discovery: .success(scan))
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.hasPrefix("42\t"))
        #expect(result.standardError.contains("incomplete"))
        #expect(result.standardError.contains("1 unreadable"))
    }

    @Test func controlCharactersInNamesAndPathsCannotForgeLinesOrColumns() async {
        let hostile = lock(name: "a\tb\nc", path: "/Volumes/Test/x\r\\y\u{01}")
        let (command, _) = makeCommand(discovery: .success(DiscoveryResult(locks: [hostile])))
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.standardOutput.split(separator: "\n", omittingEmptySubsequences: false).count == 2)
        #expect(result.standardOutput == "42\ta\\tb\\nc\tme\topenFileHandle\tcliTool\t/Volumes/Test/x\\r\\\\y\\x01\n")
    }

    @Test(arguments: [[], ["a", "b"], [""]])
    func badArgumentCountExitsNonZeroWithNoRecordsAndNoScan(_ arguments: [String]) async {
        let (command, mock) = makeCommand(discovery: .success(DiscoveryResult(locks: [lock()])))
        let result = await command.run(arguments: arguments)
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.hasPrefix("phantomtrace: "))
        #expect(result.standardError.contains(InspectCommand.usage))
        #expect(mock.log.calls.isEmpty)
    }

    @Test(arguments: [
        "relative/path",
        "/Volumes/Missing",
        "phantomtrace://inspect",
        "phantomtrace://inspect?path=",
        "phantomtrace://nope?path=%2FVolumes%2FTest"
    ])
    func invalidPathExitsNonZeroWithReasonAndNoScan(_ argument: String) async {
        let (command, mock) = makeCommand(discovery: .success(DiscoveryResult(locks: [lock()])))
        let result = await command.run(arguments: [argument])
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.contains("invalid path"))
        #expect(mock.log.calls.isEmpty)
    }

    @Test func oversizedPathIsRejectedWithItsLength() async {
        let (command, mock) = makeCommand()
        let long = "/" + String(repeating: "a", count: InspectURLParser.maxPathLength)
        let result = await command.run(arguments: [long])
        #expect(result.exitCode != 0)
        #expect(result.standardError.contains("\(long.count) characters"))
        #expect(mock.log.calls.isEmpty)
    }

    @Test func unresolvablePathExitsNonZeroWithoutScanning() async {
        let url = URL(fileURLWithPath: "/Volumes/Test")
        let resolver = MockMountResolver(mounts: [], failure: .notAMountPoint(url))
        let (command, mock) = makeCommand(resolver: resolver)
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.contains("not on a mounted volume"))
        #expect(mock.log.calls.isEmpty)
    }

    @Test func protectedVolumeIsRefusedWithoutScanning() async {
        let url = URL(fileURLWithPath: "/Volumes/Test")
        let resolver = MockMountResolver(mounts: [], failure: .protectedVolume(url))
        let (command, mock) = makeCommand(resolver: resolver)
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.exitCode != 0)
        #expect(result.standardError.contains("protected volume"))
        #expect(mock.log.calls.isEmpty)
    }

    @Test(arguments: [
        (PhantomTraceError.lsofUnavailable, "lsof is unavailable"),
        (PhantomTraceError.lsofTimedOut(seconds: 15), "timed out after 15 seconds"),
        (PhantomTraceError.commandLaunchFailed(command: "lsof"), "could not launch lsof")
    ])
    func discoveryFailureExitsNonZeroWithReasonAndNoRecords(_ error: PhantomTraceError, _ expected: String) async {
        let (command, _) = makeCommand(discovery: .failure(error))
        let result = await command.run(arguments: ["/Volumes/Test"])
        #expect(result.exitCode != 0)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.contains(expected))
    }
}
