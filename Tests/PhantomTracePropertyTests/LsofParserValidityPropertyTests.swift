import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 4: Record validity and determinism.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LsofParserValidityPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 4.5, 4.10**
    @Test func parserEmitsOnlyValidRecordsForArbitraryBytes() async {
        await propertyCheck(count: Self.iterations, input: arbitraryDataGenerator()) { data in
            assertValid(LsofParser.parse(data))
        }
    }

    /// **Validates: Requirements 4.5, 4.10**
    @Test func parserEmitsOnlyValidRecordsForMutatedLsofLikeBytes() async {
        await propertyCheck(count: Self.iterations, input: mutatedLsofGenerator()) { data in
            assertValid(LsofParser.parse(data))
        }
    }

    /// **Validates: Requirements 4.10**
    @Test func parserIsDeterministicForArbitraryBytes() async {
        await propertyCheck(count: Self.iterations, input: arbitraryDataGenerator()) { data in
            assertDeterministic(data)
        }
    }

    /// **Validates: Requirements 4.10**
    @Test func parserIsDeterministicForMutatedLsofLikeBytes() async {
        await propertyCheck(count: Self.iterations, input: mutatedLsofGenerator()) { data in
            assertDeterministic(data)
        }
    }
}

private func assertValid(_ result: ParseResult, sourceLocation: SourceLocation = #_sourceLocation) {
    for record in result.records {
        #expect(record.pid >= 1 && record.pid <= UInt32.max, sourceLocation: sourceLocation)
        #expect(!record.pathBytes.isEmpty, sourceLocation: sourceLocation)
    }
}

private func assertDeterministic(_ data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
    let first = LsofParser.parse(data)
    let second = LsofParser.parse(data)
    #expect(first.records == second.records, sourceLocation: sourceLocation)
    #expect(first.warnings == second.warnings, sourceLocation: sourceLocation)
}

private func arbitraryDataGenerator() -> Generator<Data, some SendableSequenceType> {
    Gen.uint8().array(of: 0...512).map { Data($0) }
}

/// Fragments that look like `lsof -F` fields, including bad pids, escapes, and unknown tags.
private let lsofTokens: [[UInt8]] = [
    "p1\0", "p42\0", "p4294967295\0", "p4294967296\0", "p0\0", "p-5\0", "pabc\0", "p\0",
    "cfoo\0", "cname with space\0", "Lroot\0", "u501\0", "f3\0", "fcwd\0", "ftxt\0",
    "a r\0", "aw\0", "tREG\0", "tDIR\0", "n/Volumes/A/file\0", "n/Volumes/A/a b\\x20c\0",
    "n/Volumes/A/\\134\\\\\0", "n/x\\\0", "n\\x4\0", "n\\400\0", "n\0", "Zunknown\0", "\0", "\n", "\n\n",
    "p7\nfcwd\0n/Volumes/A\0\n"
].map { Array($0.utf8) }

private func mutatedLsofGenerator() -> Generator<Data, some SendableSequenceType> {
    let tokens = Gen.int(in: 0..<lsofTokens.count).array(of: 0...40)
    let mutations = zip(Gen.int(in: 0...3), zip(Gen.int(in: 0...10_000), Gen.int(in: 0...255)))
        .map { [$0, $1.0, $1.1] }
    return zip(tokens, mutations.array(of: 0...6)).map { indices, edits in
        var bytes = indices.flatMap { lsofTokens[$0] }
        for edit in edits {
            apply(edit, to: &bytes)
        }
        return Data(bytes)
    }
}

/// Edit is `[kind, position, byte]`: 0 flip bits, 1 drop, 2 duplicate, 3 truncate.
private func apply(_ edit: [Int], to bytes: inout [UInt8]) {
    guard !bytes.isEmpty else { return }
    let position = edit[1] % bytes.count
    switch edit[0] {
    case 0: bytes[position] ^= UInt8(truncatingIfNeeded: edit[2] | 1)
    case 1: bytes.remove(at: position)
    case 2: bytes.insert(bytes[position], at: position)
    default: bytes.removeSubrange(position...)
    }
}
