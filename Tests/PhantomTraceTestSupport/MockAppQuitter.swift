import Foundation
import PhantomTraceCore

/// Scripted `AppQuitting`. GUI-ness is a fixed set of pids; quit results are scripted.
public final class MockAppQuitter: AppQuitting {
    public enum Call: Equatable, Sendable {
        case isGUIApplication(pid: Int32)
        case requestQuit(pid: Int32)
    }

    public let guiPIDs: Set<Int32>
    public let quitScript: Script<Bool>
    public let log = CallLog<Call>()

    public init(guiPIDs: Set<Int32> = [], quitFallback: Bool = true) {
        self.guiPIDs = guiPIDs
        quitScript = Script(fallback: quitFallback)
    }

    public var calls: [Call] { log.calls }

    public func isGUIApplication(pid: Int32) -> Bool {
        log.record(.isGUIApplication(pid: pid))
        return guiPIDs.contains(pid)
    }

    public func requestQuit(pid: Int32) async -> Bool {
        log.record(.requestQuit(pid: pid))
        return quitScript.next()
    }
}
