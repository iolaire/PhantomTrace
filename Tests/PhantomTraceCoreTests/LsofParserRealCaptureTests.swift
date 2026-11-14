import Foundation
import Testing
@testable import PhantomTraceCore

/// Parses a real `/usr/sbin/lsof -F pcLnftau0 -w +f -- <mountpoint>` capture
/// (`Tests/Fixtures/real_capture_macos.lsof`, macOS 27.2.1, 2026-11-14).
///
/// The capture came from a throwaway 10 MB APFS disk image with three `tail -f` helpers
/// (file names with a space, non-ASCII characters, and a newline) and one process whose
/// cwd was the volume root. Process ids are those of that run; the assertions do not depend on them.
struct LsofParserRealCaptureTests {
    private static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/real_capture_macos.lsof")

    private func parse() throws -> ParseResult {
        LsofParser.parse(try Data(contentsOf: Self.fixture))
    }

    @Test func realCaptureYieldsAllFourRecords() throws {
        #expect(try parse().records.count == 4)
    }

    /// Real finding (2026-11-14): lsof writes a newline in a name as the two bytes backslash and `n`
    /// (it also uses `\b`, `\t`, `\f`, `\r`). Requirement 4.4 lists only octal, `\x` and `\\` escapes, so
    /// the parser reports a malformed escape and keeps the two bytes. Marked as a known issue until the
    /// owner decides on a spec change; remove `withKnownIssue` when the parser decodes the short escapes.
    @Test func realCaptureShortEscapeForNewlineIsDecodedWithoutWarning() throws {
        let result = try parse()
        withKnownIssue("lsof short escapes (\\n, \\t, \\r, \\b, \\f) are not in Requirement 4.4") {
            #expect(result.warnings.isEmpty)
            #expect(result.records.map(\.path).contains("/Volumes/PTFIX/a\nb.txt"))
        }
    }

    @Test func realCaptureKeepsShortEscapeBytesAndWarnsOnce() throws {
        let result = try parse()
        #expect(result.warnings.count == 1)
        #expect(result.records.map(\.path).contains("/Volumes/PTFIX/a\\nb.txt"))
    }

    @Test func realCaptureKeepsSpaceAndUnicodeFileNames() throws {
        let paths = try parse().records.map(\.path)
        #expect(paths.contains("/Volumes/PTFIX/my file.txt"))
        #expect(paths.contains("/Volumes/PTFIX/caf\u{00E9} \u{65E5}\u{672C}.txt"))
    }

    @Test func realCaptureReportsCwdAndOpenFileDescriptors() throws {
        let records = try parse().records
        #expect(records.filter { $0.fileDescriptor == "cwd" }.map(\.command) == ["sleep"])
        #expect(records.filter { $0.command == "tail" }.allSatisfy { $0.fileDescriptor == "3" })
    }

    @Test func realCaptureRoundTripsThroughPrinter() throws {
        let first = try parse()
        let second = LsofParser.parse(LsofPrinter.print(first.records))
        #expect(second.warnings.isEmpty)
        #expect(second.records == first.records)
    }
}
