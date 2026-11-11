import Foundation

/// Parses `phantomtrace://inspect?path=<percent-encoded>` into a canonical path.
/// Requirements 12.1, 12.3, 12.4. The path is inert data: it is never executed or evaluated.
public struct InspectURLParser: Sendable {
    public static let maxPathLength = 1024
    public static let scheme = "phantomtrace"
    public static let host = "inspect"

    private let canonicalizer: any InspectPathCanonicalizing

    public init(canonicalizer: any InspectPathCanonicalizing) {
        self.canonicalizer = canonicalizer
    }

    /// Parses the URL text, returning the canonical path or the rejection reason.
    public func parse(_ text: String) -> Result<String, InspectURLError> {
        guard let components = URLComponents(string: text),
              components.scheme?.lowercased() == Self.scheme,
              components.host?.lowercased() == Self.host else {
            return .failure(.malformedURL)
        }
        let items = (components.percentEncodedQueryItems ?? []).filter { $0.name == "path" }
        guard let item = items.first, let encoded = item.value else {
            return .failure(.missingPath)
        }
        guard let decoded = encoded.removingPercentEncoding else {
            return .failure(.malformedURL)
        }
        return canonicalize(decoded)
    }

    /// Parses a `URL` value; see `parse(_:)`.
    public func parse(_ url: URL) -> Result<String, InspectURLError> {
        parse(url.absoluteString)
    }

    private func canonicalize(_ path: String) -> Result<String, InspectURLError> {
        guard !path.isEmpty else { return .failure(.emptyPath) }
        guard path.count <= Self.maxPathLength else {
            return .failure(.pathTooLong(length: path.count))
        }
        guard path.hasPrefix("/") else { return .failure(.pathNotAbsolute) }
        guard let canonical = canonicalizer.canonicalPath(for: path), !canonical.isEmpty else {
            return .failure(.pathDoesNotExist)
        }
        return .success(canonical)
    }
}
