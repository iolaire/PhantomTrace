import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

// Property 1: Parser totality.
// **Validates: Requirements 4.1**

private let iterations = 500

/// Well-formed `lsof -F pcLnftau0` output with a bad pid set, a malformed escape, and a path with
/// escapes, used as the seed for byte mutations and for the large size classes.
private let sampleInput: [UInt8] = {
    func field(_ text: String) -> [UInt8] { Array(text.utf8) + [0] }
    var bytes: [UInt8] = []
    bytes += field("p4242") + [10]
    bytes += field("cbash") + field("Lalice") + [10]
    bytes += field("fcwd") + field("a ") + field("tDIR") + field("n/Volumes/Gold/My\\040Dir") + [10]
    bytes += field("f3") + field("au") + field("tREG") + field("n/Volumes/Gold/file\\xZZ.txt") + [10]
    bytes += field("pnotapid") + [10]
    bytes += field("cignored") + field("f4") + field("n/Volumes/Gold/skipped") + [10]
    bytes += field("p17") + field("czsh") + field("f5") + field("Zunknown") + field("n/Volumes/Gold/\u{E9}") + [10]
    return bytes
}()

/// Bytes that steer the parser: terminators, escape syntax, and known field tags.
private let structuralBytes: [UInt8] =
    [0, 10, 13, 92, 120, 88] + Array("pcLnftau0123456789abcdefABCDEF-+ ".utf8)

private enum Mutation: CaseIterable {
    case flip
    case drop
    case duplicate
    case truncate
}

private func randomByte(_ rng: inout any SeededRandomNumberGenerator) -> UInt8 {
    UInt8.random(in: .min ... .max, using: &rng)
}

/// Arbitrary bytes: uniform noise mixed with structural bytes, including NUL.
private func arbitraryBytesGenerator(sizes: ClosedRange<Int>) -> Generator<Data, Shrink.None<Data>> {
    Generator { rng in
        let count = Int.random(in: sizes, using: &rng)
        let structuralRate = Double.random(in: 0 ... 1, using: &rng)
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0 ..< count {
            if Double.random(in: 0 ..< 1, using: &rng) < structuralRate,
               let byte = structuralBytes.randomElement(using: &rng) {
                bytes.append(byte)
            } else {
                bytes.append(randomByte(&rng))
            }
        }
        return Data(bytes)
    }
}

/// The sample input after several random flips, drops, duplicates, and a possible truncation.
private func mutatedInputGenerator() -> Generator<Data, Shrink.None<Data>> {
    Generator { rng in
        var bytes = sampleInput
        for _ in 0 ..< Int.random(in: 1 ... 12, using: &rng) {
            guard !bytes.isEmpty else { break }
            let index = Int.random(in: 0 ..< bytes.count, using: &rng)
            switch Mutation.allCases.randomElement(using: &rng) ?? .flip {
            case .flip:
                bytes[index] ^= UInt8(1) << UInt8.random(in: 0 ... 7, using: &rng)
            case .drop:
                bytes.remove(at: index)
            case .duplicate:
                bytes.insert(bytes[index], at: index)
            case .truncate:
                bytes.removeSubrange(index...)
            }
        }
        return Data(bytes)
    }
}

/// Input of `sizeInBytes` made from repeated copies of `sampleInput`, then `noiseCount` random bytes
/// overwritten in place, so size classes cover both clean and damaged data.
private func sizedInput(_ sizeInBytes: Int, noiseCount: Int, rng: inout any SeededRandomNumberGenerator) -> Data {
    var data = Data(capacity: sizeInBytes)
    while data.count + sampleInput.count <= sizeInBytes {
        data.append(contentsOf: sampleInput)
    }
    data.append(contentsOf: sampleInput.prefix(sizeInBytes - data.count))
    for _ in 0 ..< noiseCount where !data.isEmpty {
        data[Int.random(in: 0 ..< data.count, using: &rng)] = randomByte(&rng)
    }
    return data
}

private func sizeClassGenerator(_ sizes: [Int], noiseCount: Int) -> Generator<Data, Shrink.None<Data>> {
    Generator { rng in
        let size = sizes.randomElement(using: &rng) ?? 0
        return sizedInput(size, noiseCount: noiseCount, rng: &rng)
    }
}

/// Totality only promises a result; this also checks the emitted-record guarantees from Requirement 4.5.
private func expectWellFormedResult(_ data: Data) {
    let result = LsofParser.parse(data)
    #expect(result.records.allSatisfy { $0.pid >= 1 && !$0.pathBytes.isEmpty })
    if data.isEmpty {
        #expect(result.records.isEmpty)
    }
}

@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct LsofParserTotalityPropertyTests {
    @Test func parserReturnsForArbitraryBytesIncludingNul() async {
        await propertyCheck(count: iterations, input: arbitraryBytesGenerator(sizes: 0 ... 4096)) { data in
            expectWellFormedResult(data)
        }
    }

    @Test func parserReturnsForEmptyAndTinyInputs() async {
        await propertyCheck(count: iterations, input: arbitraryBytesGenerator(sizes: 0 ... 8)) { data in
            expectWellFormedResult(data)
        }
    }

    @Test func parserReturnsForAllNulAndAllNewlineInputs() async {
        let fill = Gen.int(in: 0 ... 8192)
        await propertyCheck(count: iterations, input: fill, Gen.element(of: [UInt8(0), 10, 92]).map { $0 ?? 0 }) {
            expectWellFormedResult(Data(repeating: $1, count: $0))
        }
    }

    @Test func parserReturnsForMutatedLsofOutput() async {
        await propertyCheck(count: iterations, input: mutatedInputGenerator()) { data in
            expectWellFormedResult(data)
        }
    }

    @Test func parserReturnsForEveryPrefixOfLsofOutput() async {
        await propertyCheck(count: iterations, input: Gen.int(in: 0 ... sampleInput.count)) { length in
            expectWellFormedResult(Data(sampleInput.prefix(length)))
        }
    }

    @Test func parserReturnsForKilobyteToMegabyteSizeClasses() async {
        let sizes = [1, 1_024, 65_536, 262_144, 1_048_576]
        await propertyCheck(count: iterations, input: sizeClassGenerator(sizes, noiseCount: 64)) { data in
            expectWellFormedResult(data)
        }
    }

    @Test func parserReturnsForTenMegabyteInputsWithNoise() async {
        // Few iterations only: each input is 10 MiB.
        await propertyCheck(count: 5, input: sizeClassGenerator([10_485_760], noiseCount: 1_000)) { data in
            expectWellFormedResult(data)
        }
    }

    @Test func parserReturnsForMaximumSpecifiedInputSize() {
        let size = LsofParser.maximumSpecifiedInputSize
        var generator: any SeededRandomNumberGenerator = Xoshiro(seed: (1, 2, 3, 4))
        let structured = sizedInput(size, noiseCount: 0, rng: &generator)
        #expect(structured.count == size)
        expectWellFormedResult(structured)

        // All-NUL bytes at the limit: the worst case for field splitting.
        expectWellFormedResult(Data(repeating: 0, count: size))
    }
}
