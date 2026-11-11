import Foundation

/// The only signals PhantomTrace may send.
public enum ProcessSignal: Equatable, Sendable {
    case terminate
    case kill
}
