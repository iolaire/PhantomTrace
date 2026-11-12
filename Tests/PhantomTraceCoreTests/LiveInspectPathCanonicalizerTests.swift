import Foundation
import PhantomTraceCore
import Testing

/// Works only inside a temporary directory this test creates and removes.
@Suite(.tags(.live), .timeLimit(.minutes(1)))
struct LiveInspectPathCanonicalizerTests {
    private let canonicalizer = LiveInspectPathCanonicalizer()

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("phantomtrace-canon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root.resolvingSymlinksInPath())
    }

    @Test func canonicalizerResolvesDotDotAndRedundantSeparators() throws {
        try withTemporaryDirectory { root in
            let child = root.appendingPathComponent("a")
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            let messy = root.path + "//a/../a/."
            #expect(canonicalizer.canonicalPath(for: messy) == child.path)
        }
    }

    @Test func canonicalizerFollowsSymlinksToTheirTarget() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target")
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let link = root.appendingPathComponent("link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            #expect(canonicalizer.canonicalPath(for: link.path) == target.path)
        }
    }

    @Test func canonicalizerReturnsNilForAMissingPath() throws {
        try withTemporaryDirectory { root in
            #expect(canonicalizer.canonicalPath(for: root.appendingPathComponent("missing").path) == nil)
        }
    }

    @Test func canonicalizerReturnsNilForABrokenSymlink() throws {
        try withTemporaryDirectory { root in
            let link = root.appendingPathComponent("dangling")
            try FileManager.default.createSymbolicLink(
                at: link,
                withDestinationURL: root.appendingPathComponent("gone")
            )
            #expect(canonicalizer.canonicalPath(for: link.path) == nil)
        }
    }
}
