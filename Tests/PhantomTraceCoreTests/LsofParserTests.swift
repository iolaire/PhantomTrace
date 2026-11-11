import Foundation
import Testing
@testable import PhantomTraceCore

struct LsofParserTests {
    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    @Test func parserReadsRecordWithEscapesAndAllFields() {
        let input = bytes("p123\0cmy\\x20cmd\0Lalice\0\nfcwd\0a \0tDIR\0n/Volumes/A B\\\\x\\012z\0\n")
        let result = LsofParser.parse(input)
        #expect(result.warnings.isEmpty)
        #expect(result.records.count == 1)
        #expect(result.records.first?.pid == 123)
        #expect(result.records.first?.command == "my cmd")
        #expect(result.records.first?.user == "alice")
        #expect(result.records.first?.pathBytes == bytes("/Volumes/A B\\x\nz"))
    }

    @Test func parserKeepsNonUTF8PathBytes() {
        var input = bytes("p9\0cx\0\nf3\0n/v/")
        input.append(contentsOf: [0xFF, 0xFE])
        input.append(contentsOf: bytes("\0\n"))
        let result = LsofParser.parse(input)
        #expect(result.records.first?.pathBytes.suffix(2) == Data([0xFF, 0xFE]))
        #expect(result.records.first?.path.contains("\u{FFFD}") == true)
    }

    @Test func parserSkipsBadPidSetAndResumes() {
        let input = bytes("p0\0cbad\0\nf3\0n/a\0\np4294967296\0\nf3\0n/b\0\np7\0cok\0\nf3\0n/c\0\n")
        let result = LsofParser.parse(input)
        #expect(result.records.map(\.pid) == [7])
        #expect(result.warnings.count == 2)
    }

    @Test func parserWarnsOnMalformedEscapeAndKeepsBytes() {
        let result = LsofParser.parse(bytes("p5\0cx\0\nf3\0n/a\\q\0\n"))
        #expect(result.records.first?.pathBytes == bytes("/a\\q"))
        #expect(result.warnings == [.malformedEscape(offset: 13)])
    }

    @Test func parserDropsTruncatedTailAndKeepsEarlierRecords() {
        let result = LsofParser.parse(bytes("p5\0cx\0\nf3\0n/a\0\nf4\0n/b"))
        #expect(result.records.map(\.path) == ["/a"])
        #expect(result.warnings.count == 1)
    }

    @Test func parserIgnoresUnknownTags() {
        let withUnknown = LsofParser.parse(bytes("p5\0cx\0\nf3\0Zjunk\0n/a\0\n"))
        let without = LsofParser.parse(bytes("p5\0cx\0\nf3\0n/a\0\n"))
        #expect(withUnknown == without)
    }

    @Test func parserHandlesEmptyAndBinaryInput() {
        #expect(LsofParser.parse(Data()).records.isEmpty)
        #expect(LsofParser.parse(Data([0, 0, 10, 92, 92, 0xFF])).records.isEmpty)
    }
}
