/// Reasons an inspect URL is rejected. Requirement 12.4.
public enum InspectURLError: Error, Equatable, Sendable {
    case malformedURL
    case missingPath
    case emptyPath
    case pathTooLong(length: Int)
    case pathNotAbsolute
    case pathDoesNotExist

    /// Plain-language reason shown to the user.
    public var reason: String {
        switch self {
        case .malformedURL:
            return "The URL is malformed."
        case .missingPath:
            return "The URL has no path parameter."
        case .emptyPath:
            return "The path parameter is empty."
        case let .pathTooLong(length):
            return "The path is \(length) characters long; the limit is \(InspectURLParser.maxPathLength)."
        case .pathNotAbsolute:
            return "The path is not absolute."
        case .pathDoesNotExist:
            return "The path does not exist."
        }
    }
}
