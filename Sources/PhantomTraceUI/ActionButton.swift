import AppKit
import PhantomTraceCore

/// A push button for Proceed and Eject with a busy state. Requirements 13.5, 18.14, 18.24.
///
/// While busy the button is disabled and shows a spinner and a progress title.
@MainActor
public final class ActionButton: NSButton {
    private let spinner = NSProgressIndicator()
    private var idleTitle: String
    private let busyTitle: String

    public init(title: String, busyTitle: String, target: AnyObject?, action: Selector?) {
        idleTitle = title
        self.busyTitle = busyTitle
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        bezelStyle = .rounded
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityLabel(title)
        spinner.isHidden = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("ActionButton is created in code only")
    }

    /// Enabled flag and progress state. Busy always wins: a busy button is never enabled.
    public func apply(enabled: Bool, busy: Bool) {
        isEnabled = enabled && !busy
        title = busy ? busyTitle : idleTitle
        setAccessibilityLabel(busy ? busyTitle : idleTitle)
        isBusy = busy
        refreshSpinner()
    }

    /// Reduce Motion (Requirement 13.14): while busy the spinner is shown static, not animated.
    public var motion = MotionPolicy(reduceMotion: false) {
        didSet { refreshSpinner() }
    }

    private var isBusy = false

    private func refreshSpinner() {
        spinner.isDisplayedWhenStopped = true  // visibility is driven by isHidden below
        if isBusy && motion.animatesSpinners {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        spinner.isHidden = !isBusy
    }

    /// Proceed text in `cannotPutAway`: it opens the Phantom Trace.
    public static let summonTitle = "Summon the Phantom Trace"
    /// Proceed text in `phantomTrace`: it runs the chosen option, then rescans.
    public static let proceedTitle = "Proceed, if you dare"
    public static let proceedBusyTitle = "Conjuring..."
    public static let goBackTitle = "Retreat to the Shadows"

    /// Proceed in `cannotPutAway` and `phantomTrace`; the text follows the window (`updateProceed`).
    public static func proceed(target: AnyObject?, action: Selector?) -> ActionButton {
        ActionButton(title: summonTitle, busyTitle: proceedBusyTitle, target: target, action: action)
    }

    /// Go Back in `phantomTrace`, returning to `cannotPutAway`. It never runs a scan or a stage.
    public static func goBack(target: AnyObject?, action: Selector?) -> ActionButton {
        let button = ActionButton(title: goBackTitle, busyTitle: goBackTitle, target: target, action: action)
        button.setAccessibilityHelp("Returns to the Cannot Put Away window. Nothing is scanned or stopped.")
        return button
    }

    /// Eject in `volumeReleased`.
    public static func eject(target: AnyObject?, action: Selector?) -> ActionButton {
        ActionButton(title: "Eject", busyTitle: "Ejecting...", target: target, action: action)
    }

    /// Updates Proceed from the model (Requirements 13.5, 18.14). The spooky text is paired with
    /// help text that says plainly what the button does.
    public func updateProceed(from model: WindowModel) {
        if model.window == .phantomTrace {
            idleTitle = Self.proceedTitle
            setAccessibilityHelp("Runs the option you chose, then scans the volume again.")
        } else {
            idleTitle = Self.summonTitle
            setAccessibilityHelp("Shows which programs are holding the volume.")
        }
        apply(enabled: model.controls.proceedEnabled, busy: model.isStageRunning)
        isHidden = model.window == nil || model.window == .volumeReleased
    }

    /// Updates Go Back: shown only in `phantomTrace`, hidden while a stage runs.
    public func updateGoBack(from model: WindowModel) {
        apply(enabled: model.controls.goBackEnabled, busy: false)
        isHidden = model.window != .phantomTrace || model.isStageRunning
    }

    /// Updates Eject from the model (Requirements 18.21, 18.24).
    public func updateEject(from model: WindowModel) {
        apply(enabled: model.controls.ejectEnabled, busy: model.isUnmounting)
        isHidden = !model.controls.ejectVisible
    }
}
