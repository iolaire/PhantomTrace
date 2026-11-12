import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 2: parser round-trip.
///
/// **Validates: Requirements 4.4, 4.9, 4.11, 4.12**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LsofParserRoundTripPropertyTests {
    /// Fields the generator controls: everything else on the record is fixed so records compare whole.
    fileprivate struct Seed: Sendable {
        var pid: UInt32
        var command: [UInt8]
        var path: [UInt8]
    }

    @Test func parsePrintRoundTripPreservesRecordsAndOrder() async {
        await Self.forAllRecordSets { seeds in
            let records = seeds.map(Self.record)
            let result = LsofParser.parse(LsofPrinter.print(records))
            #expect(result.warnings.isEmpty)
            #expect(result.records.map(\.pid) == records.map(\.pid))
            #expect(result.records.map(\.commandBytes) == records.map(\.commandBytes))
            #expect(result.records.map(\.pathBytes) == records.map(\.pathBytes))
            #expect(result.records == records)
        }
    }

    @Test func parsePrintParseEqualsFirstParse() async {
        await Self.forAllRecordSets { seeds in
            let first = LsofParser.parse(LsofPrinter.print(seeds.map(Self.record)))
            let second = LsofParser.parse(LsofPrinter.print(first.records))
            #expect(second.records == first.records)
            #expect(second.warnings.isEmpty)
        }
    }

    @Test func printerOutputKeepsSpacesNewlinesAndNonUTF8PathBytes() {
        let path = Data([0x2F, 0x20, 0x0A, 0x00, 0x5C, 0xFF, 0xC3, 0x28, 0x78, 0x41])
        let record = RawLsofRecord(
            pid: UInt32.max,
            commandBytes: Data([0x61, 0x20, 0x0A, 0xFF]),
            fileDescriptor: "cwd",
            pathBytes: path
        )
        let result = LsofParser.parse(LsofPrinter.print([record]))
        #expect(result.warnings.isEmpty)
        #expect(result.records == [record])
    }

    // MARK: Generators

    private static let interestingBytes: [UInt8] = [
        0x20, 0x0A, 0x00, 0x5C, 0x2F, 0x78, 0x30, 0x37, 0x7F, 0x80, 0xC3, 0xFF, 0x70, 0x66
    ]

    private static func forAllRecordSets(_ body: ([Seed]) -> Void) async {
        // Bias a quarter of the bytes towards escape-relevant values; the rest stay arbitrary.
        let special = interestingBytes
        let byte = Gen.uint8().map { value in
            value < 64 ? special[Int(value) % special.count] : value
        }
        // Small pids force same-process merging; the top of the range covers UInt32.max.
        let pid = Gen.uint32(in: 1...UInt32.max).map { value in
            value % 4 == 0 ? value % 3 + 1 : value
        }
        let seeds = zip(pid, byte.array(of: 0...12), byte.array(of: 1...40))
            .map { Seed(pid: $0, command: $1, path: $2) }
            .array(of: 0...12)
        await propertyCheck(count: 500, input: seeds, perform: body)
    }

    private static func record(_ seed: Seed) -> RawLsofRecord {
        RawLsofRecord(
            pid: seed.pid,
            commandBytes: Data(seed.command),
            fileDescriptor: "3r",
            accessMode: .read,
            fileType: "REG",
            pathBytes: Data(seed.path)
        )
    }
}
