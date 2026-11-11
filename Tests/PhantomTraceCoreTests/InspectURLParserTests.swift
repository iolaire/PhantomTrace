import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

struct InspectURLParserTests {
    private func makeParser(_ results: [String: String] = [:]) -> (InspectURLParser, MockInspectPathCanonicalizer) {
        let canonicalizer = MockInspectPathCanonicalizer(results: results)
        return (InspectURLParser(canonicalizer: canonicalizer), canonicalizer)
    }

    @Test func parserAcceptsEncodedPathAndReturnsCanonicalPath() {
        let (parser, _) = makeParser(["/Volumes/My Disk/a b": "/Volumes/My Disk/a b"])
        let result = parser.parse("phantomtrace://inspect?path=%2FVolumes%2FMy%20Disk%2Fa%20b")
        #expect(result == .success("/Volumes/My Disk/a b"))
    }

    @Test func parserReturnsCanonicalizerOutputNotRawPath() {
        let (parser, _) = makeParser(["/Volumes/A/../B": "/Volumes/B"])
        #expect(parser.parse("phantomtrace://inspect?path=/Volumes/A/../B") == .success("/Volumes/B"))
    }

    @Test(arguments: [
        "",
        "not a url",
        "https://inspect?path=/Volumes/A",
        "phantomtrace://other?path=/Volumes/A",
        "phantomtrace:///Volumes/A"
    ])
    func parserRejectsMalformedURLWithoutCanonicalizing(_ text: String) {
        let (parser, canonicalizer) = makeParser(["/Volumes/A": "/Volumes/A"])
        #expect(parser.parse(text) == .failure(.malformedURL))
        #expect(canonicalizer.calls.isEmpty)
    }

    // Foundation may either reject the bad escape or keep it literally; both must end in a rejection.
    @Test func parserRejectsInvalidPercentEscapeWithoutCanonicalizing() {
        let (parser, canonicalizer) = makeParser(["/Volumes/A": "/Volumes/A"])
        let result = parser.parse("phantomtrace://inspect?path=%ZZ")
        #expect(result == .failure(.malformedURL) || result == .failure(.pathNotAbsolute))
        #expect(canonicalizer.calls.isEmpty)
    }

    @Test(arguments: [
        "phantomtrace://inspect",
        "phantomtrace://inspect?other=%2FVolumes%2FA",
        "phantomtrace://inspect?path"
    ])
    func parserRejectsMissingPath(_ text: String) {
        let (parser, canonicalizer) = makeParser()
        #expect(parser.parse(text) == .failure(.missingPath))
        #expect(canonicalizer.calls.isEmpty)
    }

    @Test func parserRejectsEmptyPath() {
        let (parser, canonicalizer) = makeParser()
        #expect(parser.parse("phantomtrace://inspect?path=") == .failure(.emptyPath))
        #expect(canonicalizer.calls.isEmpty)
    }

    @Test func parserRejectsPathOverLimitButAcceptsExactlyTheLimit() {
        let limit = InspectURLParser.maxPathLength
        let atLimit = "/" + String(repeating: "a", count: limit - 1)
        let over = atLimit + "a"
        let (parser, canonicalizer) = makeParser([atLimit: atLimit])
        #expect(parser.parse("phantomtrace://inspect?path=\(atLimit)") == .success(atLimit))
        #expect(parser.parse("phantomtrace://inspect?path=\(over)") == .failure(.pathTooLong(length: limit + 1)))
        #expect(canonicalizer.calls == [atLimit])
    }

    @Test func parserRejectsRelativePath() {
        let (parser, canonicalizer) = makeParser()
        #expect(parser.parse("phantomtrace://inspect?path=Volumes%2FA") == .failure(.pathNotAbsolute))
        #expect(canonicalizer.calls.isEmpty)
    }

    @Test func parserRejectsNonexistentPath() {
        let (parser, canonicalizer) = makeParser()
        #expect(parser.parse("phantomtrace://inspect?path=%2FVolumes%2FGone") == .failure(.pathDoesNotExist))
        #expect(canonicalizer.calls == ["/Volumes/Gone"])
    }

    @Test func parserTreatsEmptyCanonicalResultAsNonexistent() {
        let (parser, _) = makeParser(["/Volumes/A": ""])
        #expect(parser.parse("phantomtrace://inspect?path=%2FVolumes%2FA") == .failure(.pathDoesNotExist))
    }

    @Test func everyRejectionHasANonEmptyReason() {
        let errors: [InspectURLError] = [
            .malformedURL, .missingPath, .emptyPath, .pathTooLong(length: 2000), .pathNotAbsolute, .pathDoesNotExist
        ]
        for error in errors {
            #expect(!error.reason.isEmpty)
        }
        #expect(InspectURLError.pathTooLong(length: 2000).reason.contains("2000"))
    }
}
