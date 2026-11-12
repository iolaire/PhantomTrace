import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 3: byte fidelity. The parser keeps path bytes exactly and derives the display path
/// by lossy UTF-8 decoding of those bytes.
///
/// **Validates: Requirements 4.2, 4.3**
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LsofParserByteFidelityPropertyTests {
    private static let iterations = 500

    @Test func parserKeepsPathBytesIdenticalWhenPrinterEscapes() async {
        await checkPaths(count: Self.iterations) { bytes in
            let record = makeRecord(pathBytes: Data(bytes))
            assertFidelity(parsing: LsofPrinter.print([record]), expecting: bytes)
        }
    }

    @Test func parserKeepsPathBytesIdenticalWhenEscapedAsHex() async {
        await checkPaths(count: Self.iterations) { bytes in
            assertFidelity(parsing: serialize(pathBytes: bytes), expecting: bytes)
        }
    }

    @Test func parserDecodesKnownHardPathsLossily() {
        let samples: [[UInt8]] = [
            Array("/Volumes/My Disk/a b.txt".utf8),
            Array("/Volumes/X/line\nbreak".utf8),
            Array("/Volumes/X/back\\slash".utf8),
            Array("/Volumes/X/caf\u{E9} \u{1F47B}".utf8),
            [0x2F, 0x56, 0x2F, 0xFF, 0xFE, 0xC0, 0x80, 0x41]
        ]
        for bytes in samples {
            assertFidelity(parsing: serialize(pathBytes: bytes), expecting: bytes)
        }
    }
}

// MARK: - Assertions

private func assertFidelity(
    parsing data: Data,
    expecting bytes: [UInt8],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let result = LsofParser.parse(data)
    #expect(result.warnings.isEmpty, sourceLocation: sourceLocation)
    #expect(result.records.count == 1, sourceLocation: sourceLocation)
    guard let parsed = result.records.first else { return }
    #expect([UInt8](parsed.pathBytes) == bytes, sourceLocation: sourceLocation)
    // Reason for the disable: the failable init returns nil on invalid UTF-8; the spec wants lossy U+FFFD.
    // swiftlint:disable:next optional_data_string_conversion
    let lossy = String(decoding: bytes, as: UTF8.self)
    #expect(parsed.path == lossy, sourceLocation: sourceLocation)
}

// MARK: - Builders

private func makeRecord(pathBytes: Data) -> RawLsofRecord {
    RawLsofRecord(
        pid: 4242,
        commandBytes: Data("cat".utf8),
        user: "tester",
        fileDescriptor: "3r",
        accessMode: .read,
        fileType: "REG",
        pathBytes: pathBytes
    )
}

/// Serializes one record the way lsof does: NUL-terminated fields, with backslash and control
/// bytes written as `\xHH` and every other byte (including invalid UTF-8) written raw.
private func serialize(pathBytes: [UInt8]) -> Data {
    var output = Data("p4242\0ccat\0\n".utf8)
    output.append(Data("f3\0tREG\0n".utf8))
    let hexDigits = Array("0123456789abcdef".utf8)
    for byte in pathBytes {
        if byte == 0x5C || byte < 0x20 || byte == 0x7F {
            output.append(contentsOf: [0x5C, UInt8(ascii: "x"), hexDigits[Int(byte >> 4)], hexDigits[Int(byte & 15)]])
        } else {
            output.append(byte)
        }
    }
    output.append(contentsOf: [0, 10])
    return output
}

// MARK: - Generators

private let unicodeSamples: [[UInt8]] = [
    Array("\u{E9}".utf8), Array("\u{4E16}\u{754C}".utf8), Array("\u{1F47B}".utf8), Array("e\u{301}".utf8)
]

/// Runs `body` on non-empty path bytes mixing spaces, newlines, backslashes, Unicode, controls and
/// arbitrary bytes. The generator is built inline because its inferred type cannot be a stored property.
private func checkPaths(count: Int, _ body: @escaping ([UInt8]) -> Void) async {
    let generator = zip(Gen.int(in: 0...7), Gen.uint8(), Gen.int(in: 0...3))
        .map { kind, byte, index -> [UInt8] in
            switch kind {
            case 0: return [0x20]
            case 1: return [0x0A]
            case 2: return [0x5C]
            case 3: return unicodeSamples[index]
            case 4: return [0x61 + byte % 26]
            case 5: return [0x80 | byte]
            case 6: return [byte % 0x20]
            default: return [byte]
            }
        }
        .array(of: 1...24)
        .map { chunks in [UInt8(ascii: "/")] + chunks.flatMap { $0 } }
    await propertyCheck(count: count, input: generator, perform: body)
}
