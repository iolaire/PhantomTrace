import Foundation
import Synchronization
import PhantomTraceCore

/// Table-driven `FileSystemProbing`. Unknown paths do not exist and canonicalize to nil.
public final class MockFileSystemProbe: FileSystemProbing {
    public enum Call: Equatable, Sendable {
        case itemExists(URL)
        case canonicalURL(URL)
        case isDirectory(URL)
    }

    public struct State: Sendable {
        public var existing: Set<URL>
        public var directories: Set<URL>
        public var canonical: [URL: URL]
    }

    private let state: Mutex<State>
    public let log = CallLog<Call>()

    public init(existing: Set<URL> = [], directories: Set<URL> = [], canonical: [URL: URL] = [:]) {
        state = Mutex(State(existing: existing, directories: directories, canonical: canonical))
    }

    public var calls: [Call] { log.calls }

    public func update(_ change: @Sendable (inout State) -> Void) {
        state.withLock { change(&$0) }
    }

    public func itemExists(at url: URL) -> Bool {
        log.record(.itemExists(url))
        return state.withLock { $0.existing.contains(url) || $0.directories.contains(url) }
    }

    public func canonicalURL(for url: URL) -> URL? {
        log.record(.canonicalURL(url))
        return state.withLock { $0.canonical[url] }
    }

    public func isDirectory(at url: URL) -> Bool {
        log.record(.isDirectory(url))
        return state.withLock { $0.directories.contains(url) }
    }
}
