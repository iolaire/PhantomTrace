import Foundation
import PhantomTraceCore

/// Single entry path for URL handler, Services entry, Dock drop, and drop window.
/// Every request is validated by Core `InspectURLParser`; a rejected request reports the reason
/// and starts no scan. Requirements 12.1, 12.2, 12.3, 12.4, 12.10.
@MainActor
public final class InspectRequestRouter {
    private let parser: InspectURLParser
    private let onAccepted: @MainActor (String) -> Void
    private let onRejected: @MainActor (InspectURLError) -> Void

    /// - Parameters:
    ///   - onAccepted: called synchronously with the canonical path; begins resolution.
    ///   - onRejected: called with the rejection reason; must show it to the user.
    public init(
        parser: InspectURLParser,
        onAccepted: @escaping @MainActor (String) -> Void,
        onRejected: @escaping @MainActor (InspectURLError) -> Void
    ) {
        self.parser = parser
        self.onAccepted = onAccepted
        self.onRejected = onRejected
    }

    /// Handles a URL: a `phantomtrace://` URL is parsed as is; a file URL is treated as a path.
    public func handle(url: URL) {
        if url.isFileURL {
            handle(path: url.path)
        } else {
            deliver(parser.parse(url))
        }
    }

    /// Handles a plain path through the same checks as the URL form.
    public func handle(path: String) {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        deliver(parser.parse("\(InspectURLParser.scheme)://\(InspectURLParser.host)?path=\(encoded)"))
    }

    private func deliver(_ result: Result<String, InspectURLError>) {
        switch result {
        case let .success(path):
            onAccepted(path)
        case let .failure(error):
            onRejected(error)
        }
    }
}
