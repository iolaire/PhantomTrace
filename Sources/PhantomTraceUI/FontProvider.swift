import AppKit
import CoreText
import OSLog

/// Resolves the Title_Font and Table_Font. Requirements 17.2, 17.8, 17.16.
@MainActor
public struct FontProvider {
    /// Table_Font candidates in order, before the system monospaced fallback.
    public static let tableFontNames = ["Monaco", "Menlo"]
    private static let fontExtensions: Set<String> = ["ttf", "otf", "ttc"]

    private let lookup: (String, CGFloat) -> NSFont?
    private let titleFontName: String?
    private let logger = Logger(subsystem: "com.phantomtrace.ui", category: "FontProvider")

    /// - Parameters:
    ///   - resourceDirectory: where an optional Title_Font file may live; nil means none.
    ///   - lookup: finds an installed font by name; injectable so tests do not depend on the machine.
    public init(
        resourceDirectory: URL? = Bundle.main.resourceURL,
        lookup: @escaping (String, CGFloat) -> NSFont? = { NSFont(name: $0, size: $1) }
    ) {
        self.lookup = lookup
        self.titleFontName = resourceDirectory.flatMap { Self.registerTitleFont(in: $0) }
    }

    /// Monaco, then Menlo, then the system monospaced font.
    public func tableFont(size: CGFloat) -> NSFont {
        for name in Self.tableFontNames {
            if let font = lookup(name, size) { return font }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// The registered Title_Font, or the system font when none is present or registrable.
    public func titleFont(size: CGFloat) -> NSFont {
        if let name = titleFontName, let font = NSFont(name: name, size: size) { return font }
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }

    /// PostScript name of the registered Title_Font, nil when absent.
    public var registeredTitleFontName: String? { titleFontName }

    private static func registerTitleFont(in directory: URL) -> String? {
        let logger = Logger(subsystem: "com.phantomtrace.ui", category: "FontProvider")
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        let fontFiles = entries
            .filter { fontExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let file = fontFiles.first else { return nil }
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error) else {
            logger.error("Title font could not be registered: \(file.lastPathComponent, privacy: .public)")
            return nil
        }
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor]
        guard let descriptor = descriptors?.first,
              let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            return nil
        }
        return name
    }
}
