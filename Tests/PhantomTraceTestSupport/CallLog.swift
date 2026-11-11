import Synchronization

/// Thread-safe, ordered record of calls made to a mock.
public final class CallLog<Call: Sendable>: Sendable {
    private let storage = Mutex<[Call]>([])

    public init() {}

    public var calls: [Call] { storage.withLock { $0 } }

    public func record(_ call: Call) {
        storage.withLock { $0.append(call) }
    }
}

/// Deterministic script: queued results are consumed in order, then the fallback repeats.
public final class Script<Value: Sendable>: Sendable {
    private struct State {
        var queue: [Value]
        var fallback: Value
    }

    private let state: Mutex<State>

    public init(fallback: Value, queue: [Value] = []) {
        state = Mutex(State(queue: queue, fallback: fallback))
    }

    public func setFallback(_ value: Value) {
        state.withLock { $0.fallback = value }
    }

    public func enqueue(_ values: Value...) {
        state.withLock { $0.queue.append(contentsOf: values) }
    }

    public func next() -> Value {
        state.withLock { state in
            state.queue.isEmpty ? state.fallback : state.queue.removeFirst()
        }
    }
}
