import Foundation
/// What a PhantomTrace dialog shows and which buttons it offers. Pure data, so the wording and
/// the button order can be tested without presenting anything. `PhantomDialog` draws it.
public struct PhantomDialogSpec: Equatable, Sendable {
    public enum Severity: Equatable, Sendable {
        case informational
        /// Destructive confirmations: the default button is the safe one.
        case critical
    }
    /// Title plaque text, drawn in the frame art's plaque (upper case, as the other windows).
    public let plaque: String
    /// One bold line saying what the dialog is about.
    public let message: String
    /// Detail text, shown in a scrollable Table_Font area (plans can be long).
    public let detail: String
    /// Button titles, left to right in reading order of importance: index 0 is the rightmost.
    public let buttons: [String]
    /// The button that Return activates.
    public let defaultButton: Int
    /// The button that Escape and the close box activate.
    public let cancelButton: Int
    public let severity: Severity
    public init(
        plaque: String,
        message: String,
        detail: String,
        buttons: [String],
        defaultButton: Int,
        cancelButton: Int,
        severity: Severity = .informational
    ) {
        self.plaque = plaque
        self.message = message
        self.detail = detail
        self.buttons = buttons
        self.defaultButton = defaultButton
        self.cancelButton = cancelButton
        self.severity = severity
    }
}
