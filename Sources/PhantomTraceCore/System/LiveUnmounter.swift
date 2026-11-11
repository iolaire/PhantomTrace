import DiskArbitration
import Darwin
import Dispatch
import Foundation

/// Live `Unmounting`: DiskArbitration first, one `diskutil` fallback (Requirements 10.2, 10.5-10.9, 15.1).
///
/// Non-forced unless `force` is true. A busy result (`kDAReturnBusy` or `EBUSY`) throws `unmountBusy` and never
/// triggers the fallback, so a busy volume goes back to Blocked for a rescan. Any other DiskArbitration failure
/// runs `/usr/sbin/diskutil unmount` exactly once through `ProcessRunning` with an argument array; if that fails
/// too, `unmountFailed(code:)` carries the `diskutil` exit status.
public struct LiveUnmounter: Unmounting {
    /// Performs the DiskArbitration unmount and returns its `DAReturn` status; 0 means success.
    /// Injectable so tests never touch a real volume.
    public typealias DiskArbitrationUnmount = @Sendable (_ mountPoint: URL, _ force: Bool) async -> Int32

    /// `kDAReturnBusy` (0xF8DA0009) as the signed value `DAReturn` uses.
    static let daBusyStatus = Int32(bitPattern: 0xF8DA_0009)
    /// DiskArbitration reports a POSIX errno as `0xC000 | errno`; observed on macOS 27.2.1 for a busy volume.
    static let daPOSIXBusyStatus = Int32(0xC000) | EBUSY
    /// Status used when no DiskArbitration session or disk could be created.
    static let daUnavailableStatus = Int32(bitPattern: 0xF8DA_0001)

    private static let diskutil = URL(fileURLWithPath: "/usr/sbin/diskutil")
    private static let diskutilTimeout: TimeInterval = 10

    private let runner: any ProcessRunning
    private let diskArbitrationUnmount: DiskArbitrationUnmount

    public init(
        runner: any ProcessRunning,
        diskArbitrationUnmount: @escaping DiskArbitrationUnmount = LiveUnmounter.unmountWithDiskArbitration
    ) {
        self.runner = runner
        self.diskArbitrationUnmount = diskArbitrationUnmount
    }

    public func unmount(_ volume: MountInfo, force: Bool) async throws {
        let status = await diskArbitrationUnmount(volume.mountPoint, force)
        if status == 0 { return }
        if [Self.daBusyStatus, Self.daPOSIXBusyStatus, EBUSY].contains(status) {
            throw PhantomTraceError.unmountBusy
        }

        var arguments = ["unmount"]
        if force { arguments.append("force") }
        arguments.append(volume.mountPoint.path)
        let output = try await runner.run(
            executable: Self.diskutil,
            arguments: arguments,
            timeout: Self.diskutilTimeout
        )
        guard output.exitStatus != 0 else { return }
        throw PhantomTraceError.unmountFailed(code: output.exitStatus)
    }

    // MARK: - DiskArbitration

    /// Bridges the one-shot `DADiskUnmount` callback with a checked continuation resumed exactly once.
    public static func unmountWithDiskArbitration(mountPoint: URL, force: Bool) async -> Int32 {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, mountPoint as CFURL) else {
            return daUnavailableStatus
        }
        let queue = DispatchQueue(label: "phantomtrace.unmount")
        DASessionSetDispatchQueue(session, queue)
        defer { DASessionSetDispatchQueue(session, nil) }

        let options = DADiskUnmountOptions(force ? kDADiskUnmountOptionForce : kDADiskUnmountOptionDefault)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            let box = Unmanaged.passRetained(UnmountCallbackBox(continuation))
            DADiskUnmount(disk, options, { _, dissenter, context in
                guard let context else { return }
                let box = Unmanaged<UnmountCallbackBox>.fromOpaque(context).takeRetainedValue()
                let status = dissenter.map { Int32(bitPattern: UInt32(DADissenterGetStatus($0))) } ?? 0
                box.continuation.resume(returning: status)
            }, box.toOpaque())
        }
    }
}

/// Holds the continuation across the C callback; consumed once by `takeRetainedValue`.
private final class UnmountCallbackBox: Sendable {
    let continuation: CheckedContinuation<Int32, Never>

    init(_ continuation: CheckedContinuation<Int32, Never>) {
        self.continuation = continuation
    }
}
