import Foundation

/// A diagnostic from `LsofParser` for a malformed, truncated, or invalid fragment.
/// `offset` is the byte offset in the input where the problem starts.
public enum ParseWarning: Equatable, Hashable, Sendable {
    /// A pid field that is not an integer from 1 to 4,294,967,295.
    case invalidPid(offset: Int)
    /// Input ended inside a field or record; the incomplete record was dropped.
    case truncatedTail(offset: Int)
    /// A backslash escape that is not a valid octal, hex, or `\\` sequence; kept literally.
    case malformedEscape(offset: Int)

    public var offset: Int {
        switch self {
        case .invalidPid(let offset), .truncatedTail(let offset), .malformedEscape(let offset):
            return offset
        }
    }
}
