import Foundation

/// The kinds of action the pipeline may propose to the safety policy.
public enum ProposedActionKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case resetShellCwd
    case quitApplication
    case sendSIGTERM
    case sendSIGKILL
    case unmount
}
