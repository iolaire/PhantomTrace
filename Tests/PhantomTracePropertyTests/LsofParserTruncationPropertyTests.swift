import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 5: Truncation safety.
/// **Validates: Requirements 4.7, 4.13**
struct LsofParserTruncationPropertyTests {
    private static let iterations = 500

    @Test func parsingAPrefixNeverInventsRecordsAndKeepsOrder() async {
        await propertyCheck(
            count: Self.iterations,
            input: recordSeedsGenerator, Gen.int(in: 0...10_000)
        ) { seeds, cutSeed in
            let full = LsofPrinter.print(makeRecords(seeds))
            let fullResult = LsofParser.parse(full)
            let cut = cutSeed % (full.count + 1)
            let prefixResult = LsofParser.parse(full.prefix(cut))

            let expected = Array(fullResult.records.prefix(prefixResult.records.count))
            #expect(prefixResult.records.count <= fullResult.records.count)
            #expect(prefixResult.records == expected)
        }
    }

    @Test func fullPrintedInputHasNoWarningsAndCompletePrefixHasNone() async {
        await propertyCheck(count: Self.iterations, input: recordSeedsGenerator) { seeds in
            let records = makeRecords(seeds)
            let full = LsofPrinter.print(records)
            let result = LsofParser.parse(full)
            #expect(result.warnings.isEmpty)
            #expect(result.records == records)
        }
    }

    @Test func cutInsideAFieldYieldsATruncatedTailWarning() async {
        await propertyCheck(
            count: Self.iterations,
            input: recordSeedsGenerator, Gen.int(in: 0...10_000)
        ) { seeds, cutSeed in
            let full = LsofPrinter.print(makeRecords(seeds))
            guard full.count > 1 else { return }
            // Cut at 1...count-1 so the prefix is non-empty and strictly shorter than the input.
            let cut = 1 + cutSeed % (full.count - 1)
            let last = full[full.startIndex + cut - 1]
            let isMidField = last != 0 && last != 10
            let result = LsofParser.parse(full.prefix(cut))
            if isMidField {
                #expect(result.warnings.contains { warning in
                    if case .truncatedTail = warning { return true }
                    return false
                })
            }
        }
    }

    @Test func everyPrefixOfAPrintedInputIsAPrefixOfTheFullRecords() async {
        await propertyCheck(count: Self.iterations, input: recordSeedsGenerator) { seeds in
            let full = LsofPrinter.print(makeRecords(seeds))
            let fullRecords = LsofParser.parse(full).records
            var previousCount = 0
            for cut in 0...full.count {
                let records = LsofParser.parse(full.prefix(cut)).records
                #expect(records == Array(fullRecords.prefix(records.count)))
                #expect(records.count >= previousCount)
                previousCount = records.count
            }
        }
    }
}

// MARK: - Generators

/// Each seed becomes one record: [pid selector, command selector, path bytes...] with at least one path byte.
private var recordSeedsGenerator: Generator<[[Int]], some SendableSequenceType> {
    Gen.int(in: 0...255).array(of: 3...12).array(of: 0...6)
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
