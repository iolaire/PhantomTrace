import Foundation
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

/// Table-driven canonicalizer; unknown paths do not exist. Local so the UI tests need no shared mocks.
private struct TableCanonicalizer: InspectPathCanonicalizing {
    let table: [String: String]

    func canonicalPath(for path: String) -> String? {
        table[path]
    }
}

@MainActor
private final class RouterRecorder {
    var accepted: [String] = []
    var rejected: [InspectURLError] = []

    func router(table: [String: String]) -> InspectRequestRouter {
        InspectRequestRouter(
            parser: InspectURLParser(canonicalizer: TableCanonicalizer(table: table)),
            onAccepted: { [self] in accepted.append($0) },
            onRejected: { [self] in rejected.append($0) }
        )
    }
}

@MainActor
struct InspectRequestRouterTests {
    private let table = [
        "/Volumes/My Disk": "/Volumes/My Disk",
        "/Volumes/Link": "/Volumes/Real"
    ]

    @Test
    func validURLDeliversTheCanonicalPath() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(url: URL(string: "phantomtrace://inspect?path=/Volumes/Link") ?? URL(fileURLWithPath: "/"))
        #expect(recorder.accepted == ["/Volumes/Real"])
        #expect(recorder.rejected.isEmpty)
    }

    @Test
    func percentEncodedPathIsDecoded() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        let text = "phantomtrace://inspect?path=%2FVolumes%2FMy%20Disk"
        router.handle(url: URL(string: text) ?? URL(fileURLWithPath: "/"))
        #expect(recorder.accepted == ["/Volumes/My Disk"])
    }

    @Test
    func fileURLIsTreatedAsAPath() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(url: URL(fileURLWithPath: "/Volumes/Link"))
        #expect(recorder.accepted == ["/Volumes/Real"])
    }

    @Test
    func plainPathWithSpacesAndSpecialCharactersGoesThroughTheSameCheck() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(path: "/Volumes/My Disk")
        #expect(recorder.accepted == ["/Volumes/My Disk"])
    }

    @Test
    func nonexistentPathIsRejectedWithoutAccepting() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(path: "/Volumes/Nope")
        #expect(recorder.accepted.isEmpty)
        #expect(recorder.rejected == [.pathDoesNotExist])
    }

    @Test
    func malformedAndMissingPathURLsAreRejected() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(url: URL(string: "https://example.com/?path=/Volumes/Link") ?? URL(fileURLWithPath: "/"))
        router.handle(url: URL(string: "phantomtrace://inspect") ?? URL(fileURLWithPath: "/"))
        router.handle(url: URL(string: "phantomtrace://inspect?path=") ?? URL(fileURLWithPath: "/"))
        #expect(recorder.accepted.isEmpty)
        #expect(recorder.rejected == [.malformedURL, .missingPath, .emptyPath])
    }

    @Test
    func relativeAndOverlongPathsAreRejected() {
        let recorder = RouterRecorder()
        let router = recorder.router(table: table)
        router.handle(path: "Volumes/Link")
        let long = "/" + String(repeating: "a", count: InspectURLParser.maxPathLength)
        router.handle(path: long)
        #expect(recorder.accepted.isEmpty)
        #expect(recorder.rejected == [.pathNotAbsolute, .pathTooLong(length: long.count)])
    }

    @Test
    func everyRejectionHasAReadableReason() {
        let errors: [InspectURLError] = [
            .malformedURL, .missingPath, .emptyPath, .pathTooLong(length: 2000), .pathNotAbsolute, .pathDoesNotExist
        ]
        for error in errors {
            #expect(!error.reason.isEmpty)
        }
    }
}
