import Foundation
import Testing
@testable import PhantomTraceCore

/// Fixture-driven parser tests (Requirements 4.3, 4.4, 4.6, 4.7, 4.9, 4.14, 15.2).
///
/// The fixtures in `Tests/Fixtures/*.lsof` are representative `lsof -F pcLnftau0` outputs generated
/// deterministically (a real capture would depend on this machine's processes and mounts).
struct LsofParserFixtureTests {
    private static let fixturesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)

    private func load(_ name: String) throws -> Data {
        try Data(contentsOf: Self.fixturesDirectory.appendingPathComponent("\(name).lsof"))
    }

    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    @Test func parserKeepsSpacesInCommandAndPath() throws {
        let result = LsofParser.parse(try load("spaces"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.count == 1)
        #expect(result.records.first?.pid == 100)
        #expect(result.records.first?.command == "My App")
        #expect(result.records.first?.user == "alice")
        #expect(result.records.first?.fileDescriptor == "cwd")
        #expect(result.records.first?.pathBytes == bytes("/Volumes/My Disk/a b/c  d"))
    }

    @Test func parserDecodesOctalNewlineInPath() throws {
        let result = LsofParser.parse(try load("newline"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.first?.pathBytes == bytes("/Volumes/A/line1\nline2"))
    }

    @Test func parserKeepsUnicodePathBytesExactly() throws {
        let result = LsofParser.parse(try load("unicode"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.first?.command == "caf\u{00E9}")
        #expect(result.records.first?.pathBytes == bytes("/Volumes/A/\u{00E9} \u{65E5}\u{672C}\u{8A9E} \u{1F47B}.txt"))
        #expect(result.records.first?.path == "/Volumes/A/\u{00E9} \u{65E5}\u{672C}\u{8A9E} \u{1F47B}.txt")
    }

    @Test func parserDecodesHexAndBackslashEscapes() throws {
        let result = LsofParser.parse(try load("hex_escape"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.first?.command == "my cmd")
        #expect(result.records.first?.pathBytes == bytes("/Volumes/A/x y\\z\\w"))
    }

    @Test func parserKeepsNonUTF8BytesRawAndEscaped() throws {
        let result = LsofParser.parse(try load("non_utf8"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.count == 2)
        var expected = bytes("/Volumes/A/")
        expected.append(contentsOf: [0xFF, 0xFE])
        expected.append(contentsOf: bytes(".bin"))
        #expect(result.records.map(\.pathBytes) == [expected, expected])
        #expect(result.records.first?.path.contains("\u{FFFD}") == true)
    }

    @Test func parserSkipsInvalidPidSetsAndResumesAtNextValidPid() throws {
        let data = try load("bad_pid")
        let result = LsofParser.parse(data)
        #expect(result.records.map(\.pid) == [105])
        #expect(result.records.first?.path == "/Volumes/A/kept")
        #expect(result.warnings.count == 3)
        for warning in result.warnings {
            guard case .invalidPid = warning else {
                Issue.record("unexpected warning \(warning)")
                continue
            }
        }
    }

    @Test func parserWarnsOnEachMalformedEscapeAndKeepsBackslash() throws {
        let data = try load("malformed_escape")
        let result = LsofParser.parse(data)
        #expect(result.records.map(\.pathBytes) == [bytes("/Volumes/A/a\\q"), bytes("/Volumes/A/b\\x2")])
        let backslashOffsets = data.enumerated().filter { $0.element == UInt8(ascii: "\\") }.map(\.offset)
        #expect(result.warnings == backslashOffsets.map { .malformedEscape(offset: $0) })
    }

    @Test func parserDropsTruncatedTailAndKeepsCompleteRecords() throws {
        let data = try load("truncated_tail")
        let result = LsofParser.parse(data)
        #expect(result.records.map(\.path) == ["/Volumes/A/whole"])
        #expect(result.warnings.count == 1)
        guard case .truncatedTail(let offset) = result.warnings.first else {
            Issue.record("expected truncatedTail, got \(result.warnings)")
            return
        }
        #expect(offset > 0 && offset <= data.count)
    }

    @Test func parserKeepsDeletedFileMarkerInPath() throws {
        let result = LsofParser.parse(try load("deleted_file"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.first?.path == "/Volumes/A/gone.txt (deleted)")
    }

    @Test func parserKeepsFirmlinkAndVolumesPathsVerbatim() throws {
        let result = LsofParser.parse(try load("firmlink"))
        #expect(result.warnings.isEmpty)
        #expect(result.records.map(\.path) == ["/System/Volumes/Data/Volumes/A/work", "/Volumes/A/work/f"])
    }

    @Test func parserOutputRoundTripsThroughPrinterForEveryCleanFixture() throws {
        for name in ["spaces", "newline", "unicode", "hex_escape", "non_utf8", "deleted_file", "firmlink"] {
            let first = LsofParser.parse(try load(name))
            let second = LsofParser.parse(LsofPrinter.print(first.records))
            #expect(second.warnings.isEmpty, "fixture \(name)")
            #expect(second.records == first.records, "fixture \(name)")
        }
    }
}
