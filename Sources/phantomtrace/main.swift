import Foundation
import PhantomTraceCore

// Composition root: the only place live adapters are wired together. The command itself lives in Core and
// is read-only, so this executable never signals a process or unmounts a volume.

/// Makes a relative argument absolute against the current directory; URLs and absolute paths pass through.
func absoluteArgument(_ argument: String) -> String {
    guard !argument.isEmpty, !argument.hasPrefix("/"), !argument.lowercased().hasPrefix("phantomtrace:") else {
        return argument
    }
    return URL(fileURLWithPath: argument, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        .path
}

func write(_ text: String, to handle: FileHandle) {
    if !text.isEmpty { handle.write(Data(text.utf8)) }
}

let runner = LiveProcessRunner()
let fileSystem = LiveFileSystemProbe()
let processes = LiveProcessInspector()
let command = InspectCommand(
    urlParser: InspectURLParser(canonicalizer: LiveInspectPathCanonicalizer()),
    resolver: MountResolver(fileSystem: fileSystem, mountTable: LiveMountTable(runner: runner, fileSystem: fileSystem)),
    discovery: LockDiscoveryEngine(
        runner: runner,
        classifier: LockClassifier(fileSystem: fileSystem, processes: processes),
        processes: processes
    )
)

let result = await command.run(arguments: CommandLine.arguments.dropFirst().map(absoluteArgument))
write(result.standardOutput, to: .standardOutput)
write(result.standardError, to: .standardError)
exit(result.exitCode)
