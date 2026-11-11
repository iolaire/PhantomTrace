import Foundation

/// Why `SafetyPolicy` refused an action. Shown to the user next to each skipped lock.
public enum SafetyDenial: String, Equatable, Hashable, Sendable, CaseIterable {
    /// PID 0 or 1.
    case protectedPid
    /// `launchd`, `kernel_task`, `WindowServer`, `loginwindow`, or `Finder`.
    case protectedProcessName
    /// PhantomTrace's own process.
    case ownProcess
    /// The process belongs to another user and no authorization exists.
    case ownedByOtherUser
    /// `sendSIGKILL` without a prior `quitApplication` or `sendSIGTERM` on the same identity.
    case noPriorGracefulAttempt
    /// The action targets a protected or unverifiable volume.
    case protectedVolume
    /// Owner, protection status, or attempt history could not be determined in time.
    case undeterminableState
    /// The action does not belong to the stage the user selected.
    case stageNotSelected
}
