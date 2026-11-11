import AppKit
import PhantomTraceCore

/// Live `AppQuitting` built on `NSRunningApplication`. It lives in the app target so Core stays
/// AppKit-free (Requirement 15.4). Only regular GUI applications are asked to quit; everything
/// else gets `SIGTERM` through the pipeline (Requirement 8.1).
struct AppQuitter: AppQuitting {
    func isGUIApplication(pid: Int32) -> Bool {
        guard pid > 1, let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return app.activationPolicy == .regular && !app.isTerminated
    }

    func requestQuit(pid: Int32) async -> Bool {
        guard isGUIApplication(pid: pid) else { return false }
        return await MainActor.run {
            guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
            return app.terminate()
        }
    }
}
