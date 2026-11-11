import Foundation
import PhantomTraceTestSupport
import Testing
@testable import PhantomTraceCore

/// Egress Shells against mock terminals and an injected clock. Requirements 7.2, 7.5, 7.6, 7.7, 15.1.
struct EgressShellPerformerTests {
    private typealias Fixtures = PipelineFixtures

    private static let tty = "/dev/ttys003"
    private static let inside = URL(fileURLWithPath: "/Volumes/Throwaway/project")
    private static let home = URL(fileURLWithPath: "/Users/me")

    private struct Rig {
        let performer: EgressShellPerformer
        let inspector: MockProcessInspector
        let terminal: MockTerminalScripter
        let clock: PipelineTestClock
    }

    private func rig(
        details: ProcessDetails?,
        terminalOutcome: TerminalScriptOutcome = .sent
    ) -> Rig {
        let inspector = MockProcessInspector(processes: details.map { [Int32(truncatingIfNeeded: 10): $0] } ?? [:])
        let terminal = MockTerminalScripter(fallback: terminalOutcome)
        let clock = PipelineTestClock()
        return Rig(
            performer: EgressShellPerformer(inspector: inspector, terminal: terminal, clock: clock),
            inspector: inspector, terminal: terminal, clock: clock
        )
    }

    private func shell(
        terminal: String? = EgressShellPerformerTests.tty,
        group: Int32 = 7,
        foreground: Int32? = 7,
        directory: URL? = EgressShellPerformerTests.inside
    ) -> ProcessDetails {
        Fixtures.details(10, terminal: terminal, group: group, foreground: foreground, directory: directory)
    }

    private var action: ProposedAction {
        ProposedAction(kind: .resetShellCwd, target: Fixtures.identity(10), reason: "idle shell")
    }

    private func perform(_ rig: Rig, _ action: ProposedAction? = nil) async -> EgressShellResult {
        await rig.performer.perform(action ?? self.action, volumeMountPoint: Fixtures.volume.mountPoint)
    }

    // MARK: - Literal text

    @Test func injectedTextIsTheFixedCdHomeLiteral() {
        #expect(LiveTerminalScripting.injectedText == " cd ~")
    }

    @Test func manualInstructionCarriesOnlyThePid() {
        let text = EgressShellPerformer.manualInstruction(pid: 10)
        #expect(text == "In the terminal running the shell with pid 10, type: cd ~")
    }

    // MARK: - Success and verification

    @Test func shellThatLeavesTheVolumeSucceedsAfterOneSendToItsTty() async {
        let rig = rig(details: shell())
        let inspector = rig.inspector
        rig.clock.onSleep { _ in inspector.setDetails(shell(directory: Self.home), forPID: 10) }
        let result = await perform(rig)
        #expect(result == .succeeded)
        #expect(rig.terminal.calls == [Self.tty])
    }

    @Test func shellThatNeverLeavesFailsAfterFiveSecondsWithoutResending() async {
        let rig = rig(details: shell())
        let result = await perform(rig)
        #expect(result == .failed(.stillOnVolume(pid: 10)))
        #expect(rig.terminal.calls.count == 1)
        let polls = rig.clock.sleeps.filter { $0 == EgressShellPerformer.pollIntervalSeconds }.count
        #expect(Double(polls) * EgressShellPerformer.pollIntervalSeconds == EgressShellPerformer.verificationSeconds)
    }

    @Test func unknownCurrentDirectoryIsNotTreatedAsLeftTheVolume() async {
        let rig = rig(details: shell(directory: nil))
        #expect(await perform(rig) == .failed(.stillOnVolume(pid: 10)))
    }

    @Test func shellThatExitsDuringVerificationIsReportedAsChangedIdentity() async {
        let rig = rig(details: shell())
        let inspector = rig.inspector
        rig.clock.onSleep { _ in inspector.setDetails(nil, forPID: 10) }
        #expect(await perform(rig) == .failed(.processIdentityChanged(pid: 10)))
    }

    // MARK: - Manual paths: nothing is sent

    @Test func shellWithoutTerminalNeedsManualCd() async {
        let rig = rig(details: shell(terminal: nil, foreground: nil))
        let result = await perform(rig)
        #expect(result == .manual(reason: .noTerminal, instruction: EgressShellPerformer.manualInstruction(pid: 10)))
        #expect(rig.terminal.calls.isEmpty)
    }

    @Test(arguments: [Int32?.some(99), nil])
    func shellWhoseTerminalBelongsToAnotherJobOrUnknownGroupNeedsManualCd(foreground: Int32?) async {
        let rig = rig(details: shell(foreground: foreground))
        let result = await perform(rig)
        #expect(result == .manual(reason: .foregroundJob, instruction: EgressShellPerformer.manualInstruction(pid: 10)))
        #expect(rig.terminal.calls.isEmpty)
    }

    @Test(arguments: [TerminalScriptOutcome.automationDenied, .unsupportedTerminal])
    func unscriptableTerminalNeedsManualCdAndIsNotRetried(outcome: TerminalScriptOutcome) async {
        let rig = rig(details: shell(), terminalOutcome: outcome)
        let result = await perform(rig)
        #expect(result == .manual(reason: .notScriptable, instruction: EgressShellPerformer.manualInstruction(pid: 10)))
        #expect(rig.terminal.calls.count == 1)
        #expect(rig.clock.sleeps.isEmpty)
    }

    // MARK: - Failed paths

    @Test func goneOrReusedPidFailsWithoutSending() async {
        let gone = rig(details: nil)
        #expect(await perform(gone) == .failed(.processIdentityChanged(pid: 10)))
        let reused = rig(details: ProcessDetails(
            identity: ProcessIdentity(pid: 10, startTime: Fixtures.start(10).addingTimeInterval(9)),
            ownerUserID: 501, terminalDevice: Self.tty, processGroupID: 7, foregroundProcessGroupID: 7,
            currentDirectory: Self.inside
        ))
        #expect(await perform(reused) == .failed(.processIdentityChanged(pid: 10)))
        #expect(gone.terminal.calls.isEmpty && reused.terminal.calls.isEmpty)
    }

    @Test func actionThatIsNotAShellResetIsInvalid() async {
        let rig = rig(details: shell())
        let sigterm = ProposedAction(kind: .sendSIGTERM, target: Fixtures.identity(10), reason: "x")
        let untargeted = ProposedAction(kind: .resetShellCwd, target: nil, reason: "x")
        #expect(await perform(rig, sigterm) == .failed(.invalidAction))
        #expect(await perform(rig, untargeted) == .failed(.invalidAction))
        #expect(rig.terminal.calls.isEmpty)
    }

    // MARK: - Path matching

    @Test func volumeMatchIsByWholePathComponent() {
        let mount = URL(fileURLWithPath: "/Volumes/A")
        #expect(EgressShellPerformer.isWithin(URL(fileURLWithPath: "/Volumes/A/x"), mountPoint: mount))
        #expect(EgressShellPerformer.isWithin(mount, mountPoint: mount))
        #expect(!EgressShellPerformer.isWithin(URL(fileURLWithPath: "/Volumes/AB/x"), mountPoint: mount))
        #expect(!EgressShellPerformer.isWithin(URL(fileURLWithPath: "/Volumes/A/../B"), mountPoint: mount))
    }

    // MARK: - Through the pipeline

    private func pipelineRun(shellDetails: ProcessDetails) async throws -> (Fixtures.Rig, StageOutcome) {
        let idle = Fixtures.lock(10, name: "zsh", category: .cwd, role: .idleShell)
        let rig = Fixtures.rig(locks: [idle], processes: [10: shellDetails])
        let plan = try await rig.pipeline.plan(.egressShells, on: Fixtures.volume)
        #expect(plan.actions.map(\.kind) == [.resetShellCwd])
        return (rig, try await rig.pipeline.execute(plan, on: Fixtures.volume))
    }

    @Test func pipelineTreatsAManualShellAsNeitherSuccessNorFailure() async throws {
        let (rig, outcome) = try await pipelineRun(shellDetails: shell(terminal: nil, foreground: nil))
        #expect(outcome.succeeded.isEmpty && outcome.failed.isEmpty)
        #expect(rig.terminal.calls.isEmpty && rig.signals.calls.isEmpty)
    }

    @Test func pipelineReportsAShellThatStaysOnTheVolumeAsFailed() async throws {
        let (rig, outcome) = try await pipelineRun(shellDetails: shell())
        #expect(outcome.succeeded.isEmpty)
        #expect(outcome.failed.map(\.error) == [.commandLaunchFailed(command: "resetShellCwd")])
        #expect(rig.terminal.calls == [Self.tty])
        #expect(rig.signals.calls.isEmpty)
    }
}
