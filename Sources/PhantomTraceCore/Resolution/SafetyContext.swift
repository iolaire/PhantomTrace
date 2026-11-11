import Foundation

/// Facts about the target of a `ProposedAction` that `SafetyPolicy` needs.
///
/// `nil` fields mean "could not be determined" and lead to a deny (Requirement 6.6).
public struct SafetyContext: Equatable, Sendable {
    public let processName: String?
    public let role: ProcessRole?
    public let ownerUserID: UInt32?
    /// Identities the user explicitly authorized despite another owner (Requirement 6.2).
    public let authorizedIdentities: Set<ProcessIdentity>
    /// `systemDaemon` identities the user explicitly confirmed for this run (Requirement 6.4).
    public let confirmedDaemons: Set<ProcessIdentity>
    /// Time spent gathering these facts, in milliseconds.
    public let determinationMilliseconds: Int

    public init(
        processName: String?,
        role: ProcessRole?,
        ownerUserID: UInt32?,
        authorizedIdentities: Set<ProcessIdentity> = [],
        confirmedDaemons: Set<ProcessIdentity> = [],
        determinationMilliseconds: Int = 0
    ) {
        self.processName = processName
        self.role = role
        self.ownerUserID = ownerUserID
        self.authorizedIdentities = authorizedIdentities
        self.confirmedDaemons = confirmedDaemons
        self.determinationMilliseconds = determinationMilliseconds
    }
}
