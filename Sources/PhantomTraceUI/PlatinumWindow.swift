import AppKit
/// A borderless window that can take focus; the Platinum chrome draws the title bar and close box.
///
/// Borderless windows have no system close or minimize buttons, so `performClose(_:)` and
/// `performMiniaturize(_:)` would only beep. Both are mapped to the direct calls so Cmd-W and
/// Cmd-M work (Requirements 19.1, 19.15).
public final class PlatinumWindow: NSWindow {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
    override public func performClose(_ sender: Any?) {
        if let delegate, delegate.windowShouldClose?(self) == false { return }
        close()
    }
    override public func performMiniaturize(_ sender: Any?) {
        miniaturize(sender)
    }
    /// A clear, non-opaque, draggable borderless window, so art can hang past the frame.
    public static func make(size: NSSize) -> PlatinumWindow {
        let window = PlatinumWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        return window
    }
}
/// Builds the shared art chrome, falling back to plain Platinum chrome when the frame art or its
/// insets are missing (Requirements 17.4, 17.7).
@MainActor
enum ArtChrome {
    static func make(title: String, resourceDirectory: URL?, titleSize: CGFloat = 14) -> PlatinumWindowChromeView {
        let fonts = FontProvider(resourceDirectory: resourceDirectory)
        let frame = SpriteLoader(resourceDirectory: resourceDirectory).load(named: "window-frame")
        let insets = resourceDirectory.flatMap {
            NineSliceInsets.load(from: $0.appendingPathComponent("window-frame.insets.json"))
        }
        let useArt = !frame.isSubstitute && insets != nil
        return PlatinumWindowChromeView(
            title: title,
            frameArt: useArt ? frame.image : nil,
            insets: useArt ? insets : nil,
            titleFont: fonts.titleFont(size: titleSize)
        )
    }
}
