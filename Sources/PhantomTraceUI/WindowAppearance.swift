import Foundation
import PhantomTraceCore

/// Pure mapping from the window and ghost state to the plaque text, sprite names, and copy.
/// No AppKit, so the mapping is unit tested. Requirements 18.5, 18.10, 18.11, 18.13, 18.21, 18.23.
public struct WindowAppearance: Equatable, Sendable {
    public let title: String
    public let illustration: String
    public let ghost: String

    /// Title, illustration, and ghost sprite for `window`. The ghost follows `ghostFor` only.
    public static func appearance(for window: WindowState) -> WindowAppearance {
        WindowAppearance(
            title: title(for: window),
            illustration: illustrationName(for: window),
            ghost: ghostSpriteName(for: ghostFor(window))
        )
    }

    /// Sprite base name (without `.png` or `@2x`) of the left-facing ghost.
    public static func ghostSpriteName(for ghost: GhostState) -> String {
        switch ghost {
        case .yellow: return "ghost-looking-left-yellow"
        case .red: return "ghost-looking-left-red"
        case .green: return "ghost-looking-left-green"
        }
    }

    public static func illustrationName(for window: WindowState) -> String {
        switch window {
        case .cannotPutAway: return "shackled-volume-and-padlocks"
        case .phantomTrace: return "crt-diagnostic-portal"
        case .volumeReleased: return "shattered-chains-and-portullis"
        }
    }

    public static func title(for window: WindowState) -> String {
        switch window {
        case .cannotPutAway: return "CANNOT PUT AWAY"
        case .phantomTrace: return "PHANTOM TRACE"
        case .volumeReleased: return "VOLUME RELEASED"
        }
    }

    /// Body copy of a window. `volumeStillMounted` only matters for `volumeReleased` (Req 18.21, 18.23).
    public static func message(for window: WindowState, volumeStillMounted: Bool) -> String {
        switch window {
        case .cannotPutAway:
            return "Something still haunts this volume and will not let it go.\n\n"
                + "Run a Phantom Trace to see which programs are holding it?"
        case .phantomTrace:
            return "These programs are holding the volume. Choose how to proceed."
        case .volumeReleased:
            return volumeStillMounted
                ? "The haunting is over. Nothing is holding this volume now."
                : "The volume has been released."
        }
    }

    /// The note under the message in `volumeReleased`.
    public static func note(volumeStillMounted: Bool) -> String {
        volumeStillMounted
            ? "If Finder still refuses to eject, try Finder again in a moment."
            : "It is safe to unplug the drive. Finder no longer lists it."
    }

    /// Alert text for an input that could not be resolved (Requirement 2.4, 2.5).
    public static func resolveErrorText(_ error: PhantomTraceError) -> String {
        switch error {
        case .protectedVolume:
            return "This volume is protected. PhantomTrace never scans or changes it."
        case .notAMountPoint:
            return "That item is not on a mounted volume, or its volume could not be verified."
        default:
            return "That item could not be inspected."
        }
    }
}
