import Foundation
import PropertyBased
import Testing
@testable import PhantomTraceCore

/// Property 19: Middle truncation.
///
/// The width measure is the character count, so every run is deterministic and needs no fonts.
@Suite(.tags(.property), .timeLimit(.minutes(5)))
struct PathTruncationPropertyTests {
    private static let iterations = 500

    /// **Validates: Requirements 13.2**
    @Test func pathThatFitsIsReturnedUnchanged() async {
        await propertyCheck(count: Self.iterations, input: pathGenerator(), Gen.int(in: 0...64)) { path, extra in
            let maxWidth = characterCount(path) + Double(extra)
            let result = PathTruncation.truncate(path, maxWidth: maxWidth, measure: characterCount)
            #expect(result == path)
        }
    }

    /// **Validates: Requirements 13.2**
    @Test func truncatedResultAlwaysFitsMaxWidth() async {
        await propertyCheck(count: Self.iterations, input: pathGenerator(), Gen.int(in: 0...10_000)) { path, seed in
            let maxWidth = Double(seed % (path.count + 3))
            let result = PathTruncation.truncate(path, maxWidth: maxWidth, measure: characterCount)
            #expect(characterCount(result) <= maxWidth)
            if result != path && !result.isEmpty {
                #expect(result.contains(PathTruncation.ellipsis))
            }
        }
    }

    /// **Validates: Requirements 13.2**
    @Test func firstAndLastComponentsStayVisibleWhenTheyFit() async {
        await propertyCheck(count: Self.iterations, input: pathGenerator(), Gen.int(in: 0...10_000)) { path, seed in
            let components = path.split(separator: "/").map(String.init)
            guard components.count >= 3, let first = components.first, let last = components.last else { return }
            let minimal = "/" + first + "/" + PathTruncation.ellipsis + "/" + last
            // Choose a width from the smallest that keeps both ends up to just below the full path.
            let span = max(path.count - minimal.count, 1)
            let maxWidth = Double(minimal.count + seed % span)
            guard maxWidth < characterCount(path) else { return }
            let result = PathTruncation.truncate(path, maxWidth: maxWidth, measure: characterCount)
            #expect(result.hasPrefix("/" + first + "/"))
            #expect(result.hasSuffix("/" + last))
            #expect(result.contains(PathTruncation.ellipsis))
            #expect(characterCount(result) <= maxWidth)
        }
    }

    /// **Validates: Requirements 13.2**
    @Test func truncationIsDeterministic() async {
        await propertyCheck(count: Self.iterations, input: pathGenerator(), Gen.int(in: 0...10_000)) { path, seed in
            let maxWidth = Double(seed % (path.count + 3))
            let first = PathTruncation.truncate(path, maxWidth: maxWidth, measure: characterCount)
            let second = PathTruncation.truncate(path, maxWidth: maxWidth, measure: characterCount)
            #expect(first == second)
        }
    }
}

private func characterCount(_ text: String) -> Double {
    Double(text.count)
}

/// No combining marks, so appending the ellipsis never merges graphemes and the count stays additive.
private let componentCharacters: [Character] = Array("abcXYZ019 -_.~&#%+@é日本語🙂ß")

private func pathGenerator() -> Generator<String, some SendableSequenceType> {
    let component = Gen.int(in: 0..<componentCharacters.count).array(of: 1...8).map { indices in
        String(indices.map { componentCharacters[$0] })
    }
    return component.array(of: 1...8).map { "/" + $0.joined(separator: "/") }
}
