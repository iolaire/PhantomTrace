import AppKit
import Foundation
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

enum UITestData {
    static let start = Date(timeIntervalSince1970: 1_000)

    static func lock(
        pid: UInt32,
        name: String = "proc",
        user: String = "me",
        category: LockCategory = .openFileHandle,
        role: ProcessRole = .userApplication,
        path: String = "/Volumes/X/file"
    ) -> LockRecord {
        LockRecord(
            pid: pid,
            processName: name,
            user: user,
            category: category,
            role: role,
            path: path,
            pathBytes: Data(path.utf8),
            processStart: start
        )
    }

    static func action(_ kind: ProposedActionKind, pid: UInt32?) -> ProposedAction {
        ProposedAction(
            kind: kind,
            target: pid.map { ProcessIdentity(pid: $0, startTime: start) },
            reason: "test"
        )
    }
}

struct StageDialogTextTests {
    @Test
    func everyDenialAndActionHasNonEmptyText() {
        for denial in SafetyDenial.allCases {
            #expect(!StageDialogText.denialText(denial).isEmpty)
        }
        for kind in ProposedActionKind.allCases {
            #expect(!StageDialogText.actionText(kind).isEmpty)
        }
    }

    @Test
    func emptyPlanSaysNothingWillHappen() {
        let plan = ResolutionPlan(stage: .gracefulRequest, actions: [], skipped: [])
        #expect(StageDialogText.planPreview(plan, locks: []) == "No actions will be taken.")
    }

    @Test
    func previewListsActionsByNameAndPidThenSkippedLocksWithReason() {
        let shell = UITestData.lock(pid: 100, name: "zsh", category: .cwd, role: .idleShell)
        let daemon = UITestData.lock(pid: 200, name: "mds", role: .systemDaemon)
        let plan = ResolutionPlan(
            stage: .egressShells,
            actions: [UITestData.action(.resetShellCwd, pid: 100)],
            skipped: [SkippedLock(lock: daemon, denial: .stageNotSelected)]
        )
        let text = StageDialogText.planPreview(plan, locks: [shell, daemon])
        #expect(text == """
            Will do:
              zsh (pid 100): move shell to home folder (cd ~)
            Will skip:
              mds (pid 200): not part of the selected stage
            """)
    }

    @Test
    func previewUsesVolumeForTargetlessActionAndGenericNameForUnknownPid() {
        let plan = ResolutionPlan(
            stage: .cleanHandoff,
            actions: [UITestData.action(.unmount, pid: nil), UITestData.action(.sendSIGTERM, pid: 9)],
            skipped: []
        )
        let text = StageDialogText.planPreview(plan, locks: [])
        #expect(text.contains("  volume: unmount"))
        #expect(text.contains("  process (pid 9): send SIGTERM"))
        #expect(!text.contains("Will skip:"))
    }

    @Test
    func previewCapsLongListsAndCountsTheRest() {
        let count = StageDialogText.maximumListed + 7
        let actions = (1...count).map { UITestData.action(.sendSIGTERM, pid: UInt32($0)) }
        let plan = ResolutionPlan(stage: .gracefulRequest, actions: actions, skipped: [])
        let lines = StageDialogText.planPreview(plan, locks: []).split(separator: "\n")
        // "Will do:" + 50 entries + the summary line.
        #expect(lines.count == 1 + StageDialogText.maximumListed + 1)
        #expect(lines.last == "  ...and 7 more")
    }

    @Test
    func banishTargetsListEachProcessOnceByNameAndPid() {
        let first = UITestData.lock(pid: 10, name: "Preview")
        let plan = ResolutionPlan(
            stage: .banishLocks,
            actions: [
                UITestData.action(.sendSIGKILL, pid: 10),
                UITestData.action(.sendSIGKILL, pid: 10),
                UITestData.action(.sendSIGKILL, pid: 11)
            ],
            skipped: []
        )
        let text = StageDialogText.banishTargets(plan, locks: [first])
        #expect(text == "  Preview (pid 10)\n  process (pid 11)")
    }

    @MainActor
    @Test
    func planPreviewAlertConfirmsFirstAndNamesTheStage() {
        let plan = ResolutionPlan(stage: .gracefulRequest, actions: [], skipped: [])
        let alert = StageDialogs.planPreview(plan, locks: [])
        #expect(alert.buttons.map(\.title) == ["Run Stage", "Cancel"])
        #expect(alert.messageText.contains("Graceful Request"))
    }

    @MainActor
    @Test
    func destructiveConfirmationsHaveCancelAsTheDefaultButton() {
        let plan = ResolutionPlan(
            stage: .banishLocks,
            actions: [UITestData.action(.sendSIGKILL, pid: 5)],
            skipped: []
        )
        let banish = StageDialogs.banishConfirmation(plan, locks: [UITestData.lock(pid: 5, name: "Preview")])
        #expect(banish.buttons.map(\.title) == ["Cancel", "Banish Locks"])
        #expect(banish.informativeText.contains("Preview (pid 5)"))

        let force = StageDialogs.forceUnmountConfirmation(volumeName: "Backup")
        #expect(force.buttons.map(\.title) == ["Cancel", "Force Unmount"])
        #expect(force.messageText.contains("Backup"))
    }
}
