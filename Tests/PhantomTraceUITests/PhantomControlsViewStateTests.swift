import AppKit
import PhantomTraceCore
import Testing
@testable import PhantomTraceUI

/// Button and choice state driven by `PhantomControls`/`WindowModel`. Views are created but never shown.
@MainActor
struct PhantomControlsViewStateTests {
    private func model(
        window: WindowState?,
        controls: PhantomControls = PhantomControls(),
        choice: PhantomChoice? = nil,
        stageRunning: Bool = false,
        unmounting: Bool = false,
        mounted: Bool = true
    ) -> WindowModel {
        WindowModel(
            window: window,
            volumeStillMounted: mounted,
            choice: choice,
            controls: controls,
            isStageRunning: stageRunning,
            isUnmounting: unmounting
        )
    }

    // MARK: ActionButton

    @Test
    func busyButtonIsNeverEnabledAndShowsProgressTitle() {
        let button = ActionButton.proceed(target: nil, action: nil)
        button.apply(enabled: true, busy: true)
        #expect(!button.isEnabled)
        #expect(button.title == ActionButton.proceedBusyTitle)
        #expect(button.accessibilityLabel() == ActionButton.proceedBusyTitle)
        button.apply(enabled: true, busy: false)
        #expect(button.isEnabled)
        #expect(button.title == ActionButton.summonTitle)
        #expect(button.accessibilityLabel() == ActionButton.summonTitle)
        button.apply(enabled: false, busy: false)
        #expect(!button.isEnabled)
    }

    @Test
    func ejectFactoryUsesEjectTitles() {
        let button = ActionButton.eject(target: nil, action: nil)
        #expect(button.title == "Eject")
        button.apply(enabled: true, busy: true)
        #expect(button.title == "Ejecting...")
    }

    @Test
    func proceedFollowsControlsAndStageRunningFromModel() {
        let button = ActionButton.proceed(target: nil, action: nil)
        let enabled = PhantomControls(proceedEnabled: true)
        button.updateProceed(from: model(window: .phantomTrace, controls: enabled))
        #expect(button.isEnabled && !button.isHidden)
        button.updateProceed(from: model(window: .phantomTrace, controls: enabled, stageRunning: true))
        #expect(!button.isEnabled && button.title == ActionButton.proceedBusyTitle)
        button.updateProceed(from: model(window: .cannotPutAway, controls: PhantomControls()))
        #expect(!button.isEnabled && !button.isHidden)
    }

    @Test
    func proceedTextFollowsTheWindowAndHelpSaysWhatItDoes() {
        let button = ActionButton.proceed(target: nil, action: nil)
        button.updateProceed(from: model(window: .cannotPutAway))
        #expect(button.title == ActionButton.summonTitle)
        #expect(button.accessibilityHelp()?.isEmpty == false)
        button.updateProceed(from: model(window: .phantomTrace))
        #expect(button.title == ActionButton.proceedTitle)
        #expect(button.accessibilityHelp()?.contains("scans the volume again") == true)
    }

    @Test
    func goBackShowsOnlyInPhantomTraceAndHidesWhileAStageRuns() {
        let button = ActionButton.goBack(target: nil, action: nil)
        #expect(button.title == ActionButton.goBackTitle)
        let enabled = PhantomControls(goBackEnabled: true)
        button.updateGoBack(from: model(window: .phantomTrace, controls: enabled))
        #expect(!button.isHidden && button.isEnabled)
        button.updateGoBack(from: model(window: .phantomTrace, controls: PhantomControls()))
        #expect(!button.isHidden && !button.isEnabled)
        button.updateGoBack(from: model(window: .phantomTrace, controls: enabled, stageRunning: true))
        #expect(button.isHidden)
        for window in [WindowState.cannotPutAway, .volumeReleased] {
            button.updateGoBack(from: model(window: window, controls: enabled))
            #expect(button.isHidden)
        }
    }

    @Test
    func proceedIsHiddenWhenNoWindowOrVolumeReleased() {
        let button = ActionButton.proceed(target: nil, action: nil)
        button.updateProceed(from: model(window: nil))
        #expect(button.isHidden)
        button.updateProceed(from: model(window: .volumeReleased))
        #expect(button.isHidden)
        button.updateProceed(from: model(window: .cannotPutAway))
        #expect(!button.isHidden)
    }

    @Test
    func ejectFollowsVisibilityEnabledAndUnmountingFromModel() {
        let button = ActionButton.eject(target: nil, action: nil)
        let controls = PhantomControls(ejectVisible: true, ejectEnabled: true)
        button.updateEject(from: model(window: .volumeReleased, controls: controls))
        #expect(!button.isHidden && button.isEnabled && button.title == "Eject")
        button.updateEject(from: model(window: .volumeReleased, controls: controls, unmounting: true))
        #expect(!button.isEnabled && button.title == "Ejecting...")
        button.updateEject(from: model(window: .volumeReleased, controls: PhantomControls(), mounted: false))
        #expect(button.isHidden)
    }

    // MARK: PhantomChoiceControl

    @Test
    func choiceOffersThreeStagesInOrderAndNoCleanHandoff() {
        #expect(PhantomChoiceControl.offeredStages == [.egressShells, .gracefulRequest, .banishLocks])
        let control = PhantomChoiceControl()
        #expect(control.optionButtons.keys.sorted() == PhantomChoiceControl.offeredStages)
        #expect(control.optionButtons[.cleanHandoff] == nil)
        #expect(control.handleMyselfOption.title == PhantomChoiceControl.handleMyselfTitle)
    }

    @Test
    func stageTitlesAreDistinctAndNonEmpty() {
        let titles = ResolutionStage.allCases.map { PhantomChoiceControl.title(for: $0) }
        #expect(Set(titles).count == titles.count)
        #expect(PhantomChoiceControl.title(for: .banishLocks) == "Banish Locks")
    }

    @Test
    func newControlStartsWithEverythingDisabledAndNothingSelected() {
        let control = PhantomChoiceControl()
        for button in control.optionButtons.values {
            #expect(!button.isEnabled)
            #expect(button.state == .off)
        }
        #expect(!control.handleMyselfOption.isEnabled)
    }

    @Test
    func onlyApplicableStagesAreEnabledAndInapplicableOnesSayUnavailable() {
        let control = PhantomChoiceControl()
        control.apply(
            controls: PhantomControls(enabledStages: [.gracefulRequest, .banishLocks], handleMyselfEnabled: true),
            choice: nil,
            isStageRunning: false
        )
        #expect(control.optionButtons[.egressShells]?.isEnabled == false)
        #expect(control.optionButtons[.gracefulRequest]?.isEnabled == true)
        #expect(control.optionButtons[.banishLocks]?.isEnabled == true)
        #expect(control.handleMyselfOption.isEnabled)
        #expect(control.optionButtons[.egressShells]?.accessibilityLabel() == "Egress Shells, unavailable")
        #expect(control.optionButtons[.gracefulRequest]?.accessibilityLabel() == "Graceful Request")
        #expect(control.optionButtons[.egressShells]?.accessibilityHelp() != nil)
        #expect(control.optionButtons[.gracefulRequest]?.accessibilityHelp() == nil)
        #expect(control.optionButtons[.banishLocks]?.accessibilityHelp() == PhantomChoiceControl.banishWarning)
    }

    @Test
    func banishWarningNamesFileLossInWordsNotColorAlone() {
        #expect(PhantomChoiceControl.banishWarning.hasPrefix("Beware:"))
        #expect(PhantomChoiceControl.banishWarning.contains("Unsaved changes to open files may be lost"))
    }

    @Test
    func selectionIsDrawnFromTheChoiceAndOnlyOneOptionIsOn() {
        let control = PhantomChoiceControl()
        let controls = PhantomControls(enabledStages: [.egressShells, .gracefulRequest], handleMyselfEnabled: true)
        control.apply(controls: controls, choice: .letPhantomTraceAct(.gracefulRequest), isStageRunning: false)
        #expect(control.optionButtons[.gracefulRequest]?.state == .on)
        #expect(control.optionButtons[.egressShells]?.state == .off)
        #expect(control.handleMyselfOption.state == .off)
        control.apply(controls: controls, choice: .handleMyself, isStageRunning: false)
        #expect(control.handleMyselfOption.state == .on)
        #expect(control.optionButtons.values.allSatisfy { $0.state == .off })
        control.apply(controls: controls, choice: nil, isStageRunning: false)
        #expect(control.handleMyselfOption.state == .off)
    }

    @Test
    func runningStageDisablesEveryOption() {
        let control = PhantomChoiceControl()
        let controls = PhantomControls(enabledStages: [.egressShells, .gracefulRequest, .banishLocks],
                                       handleMyselfEnabled: true)
        control.update(from: model(window: .phantomTrace, controls: controls, stageRunning: true))
        #expect(control.optionButtons.values.allSatisfy { !$0.isEnabled })
        #expect(!control.handleMyselfOption.isEnabled)
        control.update(from: model(window: .phantomTrace, controls: controls))
        #expect(control.optionButtons.values.allSatisfy { $0.isEnabled })
        #expect(control.handleMyselfOption.isEnabled)
    }

    @Test
    func enabledOptionReportsItsChoiceAndDisabledOptionReportsNothing() throws {
        let control = PhantomChoiceControl()
        control.apply(
            controls: PhantomControls(enabledStages: [.banishLocks], handleMyselfEnabled: true),
            choice: nil,
            isStageRunning: false
        )
        var chosen: [PhantomChoice] = []
        control.onSelect = { chosen.append($0) }
        try #require(control.optionButtons[.banishLocks]).performClick(nil)
        control.handleMyselfOption.performClick(nil)
        // performClick does nothing on a disabled button, so the disabled stage reports nothing.
        try #require(control.optionButtons[.egressShells]).performClick(nil)
        #expect(chosen == [.letPhantomTraceAct(.banishLocks), .handleMyself])
    }

    @Test
    func choiceGroupHasAnAccessibilityRoleAndLabel() {
        let control = PhantomChoiceControl()
        #expect(control.accessibilityRole() == .radioGroup)
        #expect(control.accessibilityLabel() == "Phantom choice")
    }
}
