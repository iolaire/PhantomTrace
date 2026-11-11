import Foundation
import PhantomTraceCore

/// Pure VoiceOver text for the illustrations and the Ghost_Mascot, and the Reduce Motion policy.
/// No AppKit, so it is unit tested. Requirements 13.10, 13.11, 13.14.
public enum AccessibilityText {
    /// Description of the illustration shown in `window`. Never empty.
    public static func illustrationLabel(for window: WindowState) -> String {
        switch window {
        case .cannotPutAway: return "Illustration: a volume wrapped in chains and padlocks"
        case .phantomTrace: return "Illustration: a retro screen showing a diagnostic portal"
        case .volumeReleased: return "Illustration: broken chains and a raised portcullis"
        }
    }

    /// Description of the Ghost_Mascot for `ghost`. Never empty.
    public static func ghostLabel(for ghost: GhostState) -> String {
        switch ghost {
        case .yellow: return "Ghost mascot, yellow: the volume is held"
        case .red: return "Ghost mascot, red: programs are holding the volume"
        case .green: return "Ghost mascot, green: the volume is free"
        }
    }

    /// The Failure_Banner label: kind, then the message.
    public static func bannerLabel(kind: FailureBannerKind, message: String) -> String {
        let title = kind == .failed ? "Scan failed" : "Partial results"
        return "\(title). \(message)"
    }

    /// What to announce when the window changes. Includes the title so VoiceOver users hear the new sheet.
    public static func windowAnnouncement(for window: WindowState, volumeStillMounted: Bool) -> String {
        let title = WindowAppearance.title(for: window).capitalized
        return "\(title). \(WindowAppearance.message(for: window, volumeStillMounted: volumeStillMounted))"
    }
}

/// Reduce Motion policy (Requirement 13.14): with it on, every sprite and illustration is static
/// and no spinner or glow animates.
public struct MotionPolicy: Equatable, Sendable {
    public let reduceMotion: Bool

    public init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    /// Progress spinners animate only when motion is allowed. They stay visible when static.
    public var animatesSpinners: Bool { !reduceMotion }

    /// Glow on the Ghost_Mascot and illustrations; the app draws none when motion is reduced.
    public var animatesGlow: Bool { !reduceMotion }
}
