import Foundation

/// The three lock-forensics windows. Exactly one is on screen at a time (Requirement 18.1).
public enum WindowState: Equatable, Sendable {
    case cannotPutAway
    case phantomTrace
    case volumeReleased
}

/// The left-facing ghost sprite colour. Derived from the window, never set on its own (Requirement 18.5).
public enum GhostState: Equatable, Sendable {
    case yellow
    case red
    case green
}

/// The user's choice inside the PHANTOM TRACE window.
public enum PhantomChoice: Equatable, Sendable {
    /// Let PhantomTrace run this stage (egressShells, gracefulRequest, or banishLocks).
    case letPhantomTraceAct(ResolutionStage)
    case handleMyself
}

/// A failure or partial-result notice shown inside the PHANTOM TRACE window (Requirement 14).
public struct Banner: Equatable, Sendable {
    /// Whether the scan failed outright or returned partial results (Requirements 14.1, 18.26).
    public enum Kind: Equatable, Sendable {
        case failed
        case partial
    }

    public var kind: Kind
    public var message: String
    /// At most `maximumWarnings` warnings (Requirement 14.1).
    public var warnings: [ParseWarning]
    /// How many warnings were left out of `warnings`.
    public var omittedWarningCount: Int
    public static let maximumWarnings = 100

    public init(
        kind: Kind = .failed,
        message: String,
        warnings: [ParseWarning] = [],
        omittedWarningCount: Int = 0
    ) {
        self.kind = kind
        self.message = message
        self.warnings = warnings
        self.omittedWarningCount = omittedWarningCount
    }

    /// Builds a banner that shows at most `maximumWarnings` warnings and counts the rest.
    public static func capped(kind: Kind = .failed, message: String, warnings: [ParseWarning]) -> Banner {
        Banner(
            kind: kind,
            message: message,
            warnings: Array(warnings.prefix(maximumWarnings)),
            omittedWarningCount: max(0, warnings.count - maximumWarnings)
        )
    }
}
