import Foundation

/// What the system reports about one process at one moment.
public struct ProcessDetails: Equatable, Sendable {
    public let identity: ProcessIdentity
    public let ownerUserID: UInt32
    /// Controlling terminal device path such as `/dev/ttys003`, or `nil` when there is none.
    public let terminalDevice: String?
    public let processGroupID: Int32
    /// Foreground process group of the controlling terminal, or `nil` when unknown or no terminal.
    public let foregroundProcessGroupID: Int32?
    public let currentDirectory: URL?
    /// Path of the running executable, or `nil` when unknown. Used to spot app-bundle processes.
    public let executablePath: URL?

    public init(
        identity: ProcessIdentity,
        ownerUserID: UInt32,
        terminalDevice: String?,
        processGroupID: Int32,
        foregroundProcessGroupID: Int32?,
        currentDirectory: URL?,
        executablePath: URL? = nil
    ) {
        self.identity = identity
        self.ownerUserID = ownerUserID
        self.terminalDevice = terminalDevice
        self.processGroupID = processGroupID
        self.foregroundProcessGroupID = foregroundProcessGroupID
        self.currentDirectory = currentDirectory
        self.executablePath = executablePath
    }
}
