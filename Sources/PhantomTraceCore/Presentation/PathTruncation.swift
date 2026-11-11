import Foundation

/// Middle truncation for file paths shown in a fixed-width table column.
///
/// Pure and I/O free. The caller injects the width measure (for example a closure that
/// measures a string in the Table_Font), so Core stays AppKit-free and tests stay deterministic.
public enum PathTruncation {
    /// The marker that replaces the removed middle of a path.
    public static let ellipsis = "\u{2026}"

    /// Returns `path` unchanged when it fits `maxWidth`; otherwise a shortened form that fits
    /// and keeps the leading and trailing parts of the path visible.
    ///
    /// Whole components are kept when possible (`/Volumes/…/report.txt`). When even the first and
    /// last components do not fit, the result falls back to a leading and trailing slice of
    /// characters (`/Volu…port.txt`). If not even the ellipsis fits, the result is empty.
    ///
    /// - Parameters:
    ///   - path: The full path to display.
    ///   - maxWidth: The available width, in the units of `measure`.
    ///   - measure: Returns the display width of a string. Assumed to grow with string length.
    public static func truncate(
        _ path: String,
        maxWidth: Double,
        measure: (String) -> Double
    ) -> String {
        if measure(path) <= maxWidth { return path }
        if measure(ellipsis) > maxWidth { return "" }
        if let byComponent = truncateByComponents(path, maxWidth: maxWidth, measure: measure) {
            return byComponent
        }
        return truncateByCharacters(path, maxWidth: maxWidth, measure: measure)
    }

    private static func truncateByComponents(
        _ path: String,
        maxWidth: Double,
        measure: (String) -> Double
    ) -> String? {
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard components.count >= 3 else { return nil }
        let lead = path.hasPrefix("/") ? "/" : ""

        func build(head: Int, tail: Int) -> String {
            let first = components.prefix(head).joined(separator: "/")
            let last = components.suffix(tail).joined(separator: "/")
            return lead + first + "/" + ellipsis + "/" + last
        }

        var head = 1
        var tail = 1
        guard measure(build(head: head, tail: tail)) <= maxWidth else { return nil }
        // Grow alternately (tail first) while something stays omitted and the result fits.
        var growTail = true
        var stalled = 0
        while head + tail < components.count - 1, stalled < 2 {
            let nextHead = growTail ? head : head + 1
            let nextTail = growTail ? tail + 1 : tail
            if nextHead + nextTail < components.count,
               measure(build(head: nextHead, tail: nextTail)) <= maxWidth {
                head = nextHead
                tail = nextTail
                stalled = 0
            } else {
                stalled += 1
            }
            growTail.toggle()
        }
        return build(head: head, tail: tail)
    }

    private static func truncateByCharacters(
        _ path: String,
        maxWidth: Double,
        measure: (String) -> Double
    ) -> String {
        let characters = Array(path)
        var head = 0
        var tail = 0
        var growHead = true
        var stalled = 0
        func build(_ headCount: Int, _ tailCount: Int) -> String {
            String(characters.prefix(headCount)) + ellipsis + String(characters.suffix(tailCount))
        }
        // Grow alternately (head first) while characters remain omitted and the result fits.
        while stalled < 2 {
            let nextHead = growHead ? head + 1 : head
            let nextTail = growHead ? tail : tail + 1
            if nextHead + nextTail < characters.count,
               measure(build(nextHead, nextTail)) <= maxWidth {
                head = nextHead
                tail = nextTail
                stalled = 0
            } else {
                stalled += 1
            }
            growHead.toggle()
        }
        return build(head, tail)
    }
}
