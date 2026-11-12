import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 6: Unknown-field tolerance.
/// **Validates: Requirements 4.8**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LsofParserUnknownFieldPropertyTests {
    private static let iterations = 500

    @Test func insertingUnknownTagFieldsDoesNotChangeRecordsOrWarnings() async {
        await propertyCheck(
            count: Self.iterations,
            input: recordSeedsGenerator, insertionPositionsGenerator, insertionFieldsGenerator
        ) { seeds, positions, fields in
            let original = LsofPrinter.print(makeRecords(seeds))
            let injected = insertUnknownFields(into: original, positions: positions, fields: fields)
            let baseline = LsofParser.parse(original)
            let result = LsofParser.parse(injected)
            #expect(result.records == baseline.records)
            #expect(result.warnings.isEmpty)
        }
    }

    @Test func unknownFieldsInsertedIntoEveryBoundaryLeaveRecordsUnchanged() async {
        await propertyCheck(
            count: Self.iterations,
            input: recordSeedsGenerator, insertionFieldsGenerator
        ) { seeds, fields in
            let original = LsofPrinter.print(makeRecords(seeds))
            let boundaryCount = fieldBoundaries(in: original).count
            let positions = Array(0..<boundaryCount)
            let injected = insertUnknownFields(into: original, positions: positions, fields: fields)
            #expect(LsofParser.parse(injected).records == LsofParser.parse(original).records)
        }
    }

    @Test func unknownFieldInsertedAtEveryBoundaryOfAFixedExampleIsIgnored() {
        let record = RawLsofRecord(
            pid: 42,
            commandBytes: Data("cat".utf8),
            user: "me",
            fileDescriptor: "3r",
            accessMode: nil,
            fileType: "REG",
            pathBytes: Data("/Volumes/A/file".utf8)
        )
        let original = LsofPrinter.print([record])
        let boundaryCount = fieldBoundaries(in: original).count
        for boundary in 0..<boundaryCount {
            let injected = insertUnknownFields(
                into: original, positions: [boundary], fields: [[Int(UInt8(ascii: "Z")), 0, 65, 66]]
            )
            #expect(LsofParser.parse(injected).records == [record])
        }
    }
}

// MARK: - Insertion

/// Tag bytes that are not NUL, LF, or a tag the parser understands.
private let unknownTagBytes: [UInt8] = {
    let known = Set("pfcLuatn".utf8)
    return (1...255).map { UInt8($0) }.filter { $0 != 10 && !known.contains($0) }
}()

/// Offsets where a new field may begin: the start of input and right after every NUL or LF.
private func fieldBoundaries(in data: Data) -> [Int] {
    var boundaries = [0]
    for (offset, byte) in data.enumerated() where byte == 0 || byte == 10 {
        boundaries.append(offset + 1)
    }
    return boundaries
}

/// Each `fields` entry is [tag selector, terminator selector, value bytes...]; `positions` choose boundaries.
private func insertUnknownFields(into data: Data, positions: [Int], fields: [[Int]]) -> Data {
    let boundaries = fieldBoundaries(in: data)
    var injections: [Int: Data] = [:]
    for (index, field) in fields.enumerated() where field.count >= 2 {
        let position = boundaries[(index < positions.count ? positions[index] : index) % boundaries.count]
        var bytes = Data([unknownTagBytes[field[0] % unknownTagBytes.count]])
        // Values may not contain the terminators; anything else is inert data.
        bytes.append(contentsOf: field.dropFirst(2).map { $0 == 0 || $0 == 10 ? UInt8(32) : UInt8($0) })
        bytes.append(field[1] % 2 == 0 ? 0 : 10)
        injections[position, default: Data()].append(bytes)
    }
    var output = Data()
    for (offset, byte) in data.enumerated() {
        if let extra = injections[offset] { output.append(extra) }
        output.append(byte)
    }
    if let extra = injections[data.count] { output.append(extra) }
    return output
}

// MARK: - Generators

/// Each seed becomes one record: [pid selector, command selector, path bytes...] with at least one path byte.
private var recordSeedsGenerator: Generator<[[Int]], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 3...12).array(of: 0...6)
}

private var insertionPositionsGenerator: Generator<[Int], some SendableSequenceType> {
    Gen.int(in: 0...10_000).array(of: 0...8)
}

private var insertionFieldsGenerator: Generator<[[Int]], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 2...10).array(of: 0...8)
}

private func makeRecords(_ seeds: [[Int]]) -> [RawLsofRecord] {
    let descriptors = ["cwd", "txt", "3r", "12u"]
    return seeds.map { seed in
        let pid = UInt32(1 + seed[0] % 4)
        let command = Data("cmd\(seed[1] % 3)".utf8)
        let path = Data(seed.dropFirst(2).map { UInt8($0) })
        return RawLsofRecord(
            pid: pid,
            commandBytes: command,
            user: "user\(pid)",
            fileDescriptor: descriptors[seed[1] % descriptors.count],
            accessMode: nil,
            fileType: "REG",
            pathBytes: path
        )
    }
}
