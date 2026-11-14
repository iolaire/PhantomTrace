import Foundation
import PhantomTraceCore
import PhantomTraceTestSupport
import Testing

/// Egress Shells actions the user must finish by hand reach the window model (Requirement 7.5).
struct DiagnosticCoordinatorManualActionTests: CoordinatorScenario {
    private func shell(_ pid: UInt32) -> LockRecord {
        LockRecord(
            pid: pid, processName: "zsh", user: "me", category: .cwd, role: .idleShell,
            path: "/Volumes/Test", pathBytes: Data("/Volumes/Test".utf8),
            processStart: Date(timeIntervalSince1970: 1)
        )
    }

    private func manualActions(_ count: Int, locked: LockRecord) -> [ManualAction] {
        (0..<count).map { index in
            ManualAction(
                action: ProposedAction(kind: .resetShellCwd, target: locked.identity, reason: "r"),
                reason: .notScriptable,
                instruction: "In the terminal running the shell with pid \(index + 1), type: cd ~"
            )
        }
    }

    /// Runs Egress Shells to completion with the given outcome and returns the resulting model.
    private func runEgressStage(_ rig: CoordinatorRig, locked: LockRecord, outcome: StageOutcome) async
        -> WindowModel {
        await rig.coordinator.inspect(input)
        await rig.coordinator.proceed()
        let action = ProposedAction(kind: .resetShellCwd, target: locked.identity, reason: "test")
        rig.stages.plans.enqueue(.success(ResolutionPlan(stage: .egressShells, actions: [action], skipped: [])))
        rig.stages.outcomes.enqueue(.success(outcome))
        await rig.coordinator.select(.letPhantomTraceAct(.egressShells))
        await rig.coordinator.proceed()
        return await rig.coordinator.current
    }

    @Test func manualShellInstructionReachesTheWindowModel() async {
        let locked = shell(5883)
        let manual = manualActions(1, locked: locked)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runEgressStage(rig, locked: locked, outcome: StageOutcome(
            stage: .egressShells, succeeded: [], failed: [], manual: manual, remainingLocks: [locked]
        ))
        #expect(rig.stages.log.calls.contains(.execute(.egressShells)))
        #expect(model.manualActions.entries == manual)
        #expect(model.manualActions.omittedCount == 0)
        #expect(model.failedActions == FailedActionList())
        #expect(model.window == .phantomTrace)  // the shell still holds the volume
    }

    @Test func manualActionsAreCappedAtFiveHundredWithAnOmittedCount() async {
        let locked = shell(10)
        let manual = manualActions(530, locked: locked)
        let (rig, _) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runEgressStage(rig, locked: locked, outcome: StageOutcome(
            stage: .egressShells, succeeded: [], failed: [], manual: manual, remainingLocks: [locked]
        ))
        #expect(model.manualActions.entries == Array(manual.prefix(500)))
        #expect(model.manualActions.omittedCount == 30)
    }

    @Test func newRunClearsTheManualActionsOfTheLastStage() async {
        let locked = shell(10)
        let (rig, discovery) = rig(.success(DiscoveryResult(locks: [locked])))
        let model = await runEgressStage(rig, locked: locked, outcome: StageOutcome(
            stage: .egressShells, succeeded: [], failed: [], manual: manualActions(2, locked: locked),
            remainingLocks: [locked]
        ))
        #expect(model.manualActions.entries.count == 2)
        discovery.script.enqueue(.success(DiscoveryResult(locks: [locked])))
        await rig.coordinator.rescan()
        #expect(await rig.coordinator.current.manualActions == ManualActionList())
    }
}
