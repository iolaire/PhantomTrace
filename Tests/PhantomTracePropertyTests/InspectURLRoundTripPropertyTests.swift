import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 18: Inspect URL round-trip.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct InspectURLRoundTripPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 12.1, 12.3**
    @Test func percentEncodedAbsolutePathParsesBackToOriginal() async {
        let parser = InspectURLParser(canonicalizer: IdentityCanonicalizer())
        await propertyCheck(count: Self.iterations, input: absolutePathGenerator()) { path in
            let url = "phantomtrace://inspect?path=" + percentEncode(path)
            #expect(parser.parse(url) == .success(path))
        }
    }

    /// **Validates: Requirements 12.1, 12.3**
    @Test func urlValueParsesBackToOriginalPath() async {
        let parser = InspectURLParser(canonicalizer: IdentityCanonicalizer())
        await propertyCheck(count: Self.iterations, input: absolutePathGenerator()) { path in
            guard let url = URL(string: "phantomtrace://inspect?path=" + percentEncode(path)) else {
                Issue.record("Encoded URL was not valid for \(path)")
                return
            }
            #expect(parser.parse(url) == .success(path))
        }
    }
}

/// Returns the input unchanged, so the property isolates encoding and decoding.
private struct IdentityCanonicalizer: InspectPathCanonicalizing {
    func canonicalPath(for path: String) -> String? { path }
}

private func percentEncode(_ path: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~/")
    return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}

/// Characters include spaces, Unicode, and URL-reserved characters.
private let pathCharacters: [Character] = Array(
    "abcXYZ019 -_.~&#%?=+;:@!$'()*,[]\"<>\\|^`{}é日本語🙂ß\u{301}"
)

private func absolutePathGenerator() -> Generator<String, some SendableSequenceType> {
    let component = Gen.int(in: 0..<pathCharacters.count).array(of: 1...10).map { indices in
        String(indices.map { pathCharacters[$0] })
    }
    return component.array(of: 1...8).map { "/" + $0.joined(separator: "/") }
}
