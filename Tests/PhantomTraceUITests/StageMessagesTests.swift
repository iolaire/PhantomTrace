import Foundation
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

struct StageMessagesTests {
    @Test
    func warningTextNamesKindAndByteOffset() {
        #expect(StageMessages.describe(ParseWarning.invalidPid(offset: 12)).contains("12"))
        #expect(StageMessages.describe(ParseWarning.truncatedTail(offset: 345)).contains("345"))
        #expect(StageMessages.describe(ParseWarning.malformedEscape(offset: 6)).contains("6"))
        let texts = Set([
            StageMessages.describe(ParseWarning.invalidPid(offset: 1)),
            StageMessages.describe(ParseWarning.truncatedTail(offset: 1)),
            StageMessages.describe(ParseWarning.malformedEscape(offset: 1))
        ])
        #expect(texts.count == 3)
    }

    @Test
    func omittedCountsAreNilForZeroAndPluralizeWarnings() {
        #expect(StageMessages.omittedWarnings(0) == nil)
        #expect(StageMessages.omittedWarnings(1) == "and 1 more warning not shown")
        #expect(StageMessages.omittedWarnings(30) == "and 30 more warnings not shown")
        #expect(StageMessages.omittedActions(0) == nil)
        #expect(StageMessages.omittedActions(1) == "and 1 more failed action not shown")
        #expect(StageMessages.omittedActions(30) == "and 30 more failed actions not shown")
    }

    @Test
    func errorTextNeverIncludesPaths() {
        let url = URL(fileURLWithPath: "/Volumes/Secret Name")
        #expect(StageMessages.describe(PhantomTraceError.notAMountPoint(url)) == "not a mount point")
        #expect(StageMessages.describe(PhantomTraceError.protectedVolume(url)) == "protected volume")
        #expect(StageMessages.describe(PhantomTraceError.commandTimedOut(command: "/usr/sbin/diskutil", seconds: 10))
            == "diskutil timed out after 10 s")
        #expect(StageMessages.describe(PhantomTraceError.commandLaunchFailed(command: "/usr/bin/osascript"))
            == "osascript could not be started")
    }

    @Test
    func everyErrorKindHasDistinctNonEmptyText() {
        let url = URL(fileURLWithPath: "/Volumes/X")
        let errors: [PhantomTraceError] = [
            .notAMountPoint(url), .protectedVolume(url), .lsofUnavailable, .lsofTimedOut(seconds: 15),
            .commandTimedOut(command: "/bin/x", seconds: 1), .commandLaunchFailed(command: "/bin/x"),
            .permissionDenied(pid: 1), .processIdentityChanged(pid: 1), .unmountBusy, .unmountFailed(code: 5),
            .cancelled
        ]
        let texts = errors.map { StageMessages.describe($0) }
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == errors.count)
        #expect(StageMessages.describe(PhantomTraceError.unmountFailed(code: 5)).contains("5"))
    }

    @Test
    func everyActionKindHasDistinctText() {
        let texts = ProposedActionKind.allCases.map { StageMessages.describe($0) }
        #expect(Set(texts).count == ProposedActionKind.allCases.count)
        #expect(texts.allSatisfy { !$0.isEmpty })
    }

    @Test
    func failedActionLineIncludesPidWhenThereIsATarget() {
        let withPid = FailedAction(
            action: UITestData.action(.quitApplication, pid: 123),
            error: .permissionDenied(pid: 123)
        )
        #expect(StageMessages.describe(withPid) == "Quit application, pid 123: permission denied")
        let noPid = FailedAction(action: UITestData.action(.unmount, pid: nil), error: .unmountBusy)
        #expect(StageMessages.describe(noPid) == "Unmount: volume is busy")
    }

    @Test
    func fixedMessagesAreNotEmpty() {
        #expect(!StageMessages.noEligibleBanishProcesses.isEmpty)
        #expect(!StageMessages.scanFailedHint.isEmpty)
    }

    @Test
    func manualShellLineGivesTheReasonAndTheCdHomeInstruction() {
        let manual = ManualAction(
            action: UITestData.action(.resetShellCwd, pid: 5883),
            reason: .notScriptable,
            instruction: "In the terminal running the shell with pid 5883, type: cd ~"
        )
        #expect(StageMessages.describe(manual) == "Do it yourself (PhantomTrace could not type into its terminal): "
            + "In the terminal running the shell with pid 5883, type: cd ~")
    }

    @Test
    func everyManualReasonHasDistinctText() {
        let reasons: [EgressManualReason] = [.noTerminal, .foregroundJob, .notScriptable]
        let texts = reasons.map { StageMessages.describe($0) }
        #expect(Set(texts).count == reasons.count)
        #expect(texts.allSatisfy { !$0.isEmpty })
    }

    @Test
    func omittedManualActionCountUsesSingularAndPlural() {
        #expect(StageMessages.omittedManualActions(0) == nil)
        #expect(StageMessages.omittedManualActions(1) == "and 1 more shell to move by hand not shown")
        #expect(StageMessages.omittedManualActions(30) == "and 30 more shells to move by hand not shown")
    }

    @Test @MainActor
    func resultListShowsManualShellsBeforeFailedActions() {
        let manual = ManualActionList(capping: [ManualAction(
            action: UITestData.action(.resetShellCwd, pid: 7),
            reason: .foregroundJob,
            instruction: "In the terminal running the shell with pid 7, type: cd ~"
        )])
        let failed = FailedActionList(capping: [FailedAction(
            action: UITestData.action(.quitApplication, pid: 8), error: .permissionDenied(pid: 8)
        )])
        let lines = FailedActionListView.text(for: failed, manual: manual, noEligibleBanish: false)
            .components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("pid 7, type: cd ~"))
        #expect(lines[1] == "Quit application, pid 8: permission denied")
        #expect(FailedActionListView.text(for: FailedActionList(), noEligibleBanish: false).isEmpty)
        #expect(FailedActionListView.accessibilityLabel(failed: 1, manual: 1)
            == "Stage results. 1 shell to move by hand, 1 failed action")
        #expect(FailedActionListView.accessibilityLabel(failed: 0, manual: 0) == "No failed actions")
    }
}
