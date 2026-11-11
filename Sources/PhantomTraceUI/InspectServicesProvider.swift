import AppKit

/// Target of the `NSServices` entry "Inspect Volume Locks" (`NSMessage` = `inspectVolumeLocks`).
/// Passes the selected item to the same path as the URL handler. Requirement 12.1.
@MainActor
public final class InspectServicesProvider: NSObject {
    private let router: InspectRequestRouter

    public init(router: InspectRequestRouter) {
        self.router = router
        super.init()
    }

    /// Called by the Services machinery with the selected Finder item(s) on the pasteboard.
    @objc public func inspectVolumeLocks(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              let first = urls.first else {
            error.pointee = "No file or folder was selected."
            return
        }
        router.handle(url: first)
    }
}
