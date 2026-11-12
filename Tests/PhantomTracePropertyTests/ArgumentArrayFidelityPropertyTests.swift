import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import PropertyBased
import Testing

/// Property 21: Argument-array fidelity.
///
/// For any path, including spaces, quotes, and shell metacharacters, the subprocess argument handed to the
/// process runner equals the path verbatim as one argument. Only `MockProcessRunner` is used, so no process
/// is ever launched.
/// **Validates: Requirements 15.1**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct ArgumentArrayFidelityPropertyTests {
    private static let iterations = 500

    @Test func lsofReceivesMountPointVerbatimAsSingleArgumentAfterDoubleDash() async {
        await propertyCheck(count: Self.iterations, input: mountPathGenerator) { path in
            let runner = MockProcessRunner()
            _ = try? await makeEngine(runner).discover(in: makeVolume(path))
            let calls = runner.calls
            #expect(calls.count == 1)
            guard let call = calls.first else { return }
            #expect(call.executable == LockDiscoveryEngine.lsofURL)
            #expect(Array(call.arguments.suffix(2)) == ["--", path])
            #expect(call.arguments.filter { $0.contains(path) }.count == 1)
        }
    }

    @Test func fallbackCommandsReceiveMountPointVerbatimAsSingleArgument() async {
        await propertyCheck(count: Self.iterations, input: mountPathGenerator) { path in
            let runner = MockProcessRunner()
            runner.enqueueTimeout(seconds: 15)
            _ = try? await makeEngine(runner).discover(in: makeVolume(path))
            let calls = runner.calls
            #expect(calls.count == 3)
            guard calls.count == 3 else { return }
            #expect(calls[1].executable == LockDiscoveryEngine.lsofURL)
            #expect(Array(calls[1].arguments.suffix(2)) == ["+D", path])
            #expect(calls[2].executable == LockDiscoveryEngine.fuserURL)
            #expect(calls[2].arguments == ["-c", path])
        }
    }

    @Test func diskutilFallbackReceivesMountPointVerbatimAsSingleArgument() async {
        await propertyCheck(count: Self.iterations, input: mountPathGenerator, Gen.bool()) { path, force in
            let runner = MockProcessRunner()
            // A DiskArbitration failure that is not "busy" selects the single diskutil fallback.
            let unmounter = LiveUnmounter(runner: runner, diskArbitrationUnmount: { _, _ in 1 })
            try? await unmounter.unmount(makeVolume(path), force: force)
            let calls = runner.calls
            #expect(calls.count == 1)
            guard let call = calls.first else { return }
            #expect(call.executable.path == "/usr/sbin/diskutil")
            #expect(call.arguments == (force ? ["unmount", "force", path] : ["unmount", path]))
        }
    }

    @Test func osascriptReceivesConstantScriptAndTerminalDeviceAsSeparateArguments() async {
        await propertyCheck(count: Self.iterations, input: Gen.int(in: 0...999_999)) { number in
            let device = "/dev/ttys\(number)"
            let runner = MockProcessRunner()
            _ = await LiveTerminalScripting(runner: runner).sendChangeDirectoryHome(toTerminalDevice: device)
            let calls = runner.calls
            #expect(calls.count == 2)
            for call in calls {
                #expect(call.executable.path == "/usr/bin/osascript")
                #expect(call.arguments.count == 3)
                #expect(call.arguments.first == "-e")
                #expect(call.arguments.last == device)
                // The tty is data (argv), never part of the script source.
                #expect(call.arguments.dropFirst().first?.contains(device) == false)
            }
        }
    }
}

private let ownPID: Int32 = 4242

private func makeVolume(_ path: String) -> MountInfo {
    MountInfo(
        mountPoint: URL(fileURLWithPath: path),
        volumeName: "",
        deviceNode: "/dev/disk9s1",
        fileSystemType: "apfs",
        isInternal: false,
        isRemovable: true,
        isDiskImage: false
    )
}

private func makeEngine(_ runner: MockProcessRunner) -> LockDiscoveryEngine {
    let inspector = MockProcessInspector(currentProcessID: ownPID)
    return LockDiscoveryEngine(
        runner: runner,
        classifier: LockClassifier(fileSystem: MockFileSystemProbe(), processes: inspector),
        processes: inspector
    )
}

/// Characters that a shell, `lsof`, or a careless quoting layer could treat specially. No `/` or NUL.
private let hostileCharacters: [Character] = Array(
    "ab Z09 \t\n\"'`$&|;<>()*?[]{}!#~\\%=,:@^+-é日🙂"
)

/// `/Volumes/<component>/<component>...`. Each component starts with `v`, so it is never `.`, `..`, or empty,
/// and never ends with a separator, so `URL.path` returns the string unchanged.
private var mountPathGenerator: Generator<String, some SendableSequenceType> {
    let component = Gen.int(in: 0..<hostileCharacters.count).array(of: 0...10).map { indices in
        "v" + String(indices.map { hostileCharacters[$0] })
    }
    return component.array(of: 1...4).map { "/Volumes/" + $0.joined(separator: "/") }
}
