import Foundation

/// One parsed open-file entry from `lsof -F` output.
///
/// `commandBytes` and `pathBytes` are the source of truth; `command` and `path`
/// are lossy UTF-8 display forms derived from them.
public struct RawLsofRecord: Equatable, Sendable {
    public var pid: UInt32
    public var command: String
    public var commandBytes: Data
    public var user: String?
    /// `cwd`, `txt`, `3r`, `12u`, and so on.
    public var fileDescriptor: String
    public var accessMode: AccessMode?
    /// `REG`, `DIR`, and so on.
    public var fileType: String?
    public var pathBytes: Data
    public var path: String

    public init(
        pid: UInt32,
        commandBytes: Data,
        user: String? = nil,
        fileDescriptor: String,
        accessMode: AccessMode? = nil,
        fileType: String? = nil,
        pathBytes: Data
    ) {
        self.pid = pid
        self.commandBytes = commandBytes
        self.command = Self.displayString(commandBytes)
        self.user = user
        self.fileDescriptor = fileDescriptor
        self.accessMode = accessMode
        self.fileType = fileType
        self.pathBytes = pathBytes
        self.path = Self.displayString(pathBytes)
    }
}

extension RawLsofRecord {
    /// Lossy UTF-8 display form: invalid sequences become U+FFFD. Never use for logic.
    static func displayString(_ bytes: Data) -> String {
        let octets = [UInt8](bytes)
        // Reason for the disable: the failable init returns nil on invalid UTF-8; we need lossy U+FFFD.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: octets, as: UTF8.self)
    }
}
