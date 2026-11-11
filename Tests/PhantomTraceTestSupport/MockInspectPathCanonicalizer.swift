import Foundation
import PhantomTraceCore
import Synchronization

/// Table-driven `InspectPathCanonicalizing`. Unknown paths canonicalize to nil (nonexistent).
public final class MockInspectPathCanonicalizer: InspectPathCanonicalizing {
    private let table: Mutex<[String: String]>
    public let log = CallLog<String>()

    public init(results: [String: String] = [:]) {
        table = Mutex(results)
    }

    public var calls: [String] { log.calls }

    public func setResult(_ canonical: String?, forPath path: String) {
        table.withLock { $0[path] = canonical }
    }

    public func canonicalPath(for path: String) -> String? {
        log.record(path)
        return table.withLock { $0[path] }
    }
}
