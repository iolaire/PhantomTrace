import AppKit
import PhantomTraceCore

/// A push button for Proceed and Eject with a busy state. Requirements 13.5, 18.14, 18.24.
///
/// While busy the button is disabled and shows a spinner and a progress title.
@MainActor
public final class ActionButton: NSButton {
    private let spinner = NSProgressIndicator()
    private let idleTitle: String
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

    /// Proceed in `cannotPutAway` and `phantomTrace`. Visible text stays "Proceed".
    public static func proceed(target: AnyObject?, action: Selector?) -> ActionButton {
        ActionButton(title: "Proceed", busyTitle: "Working...", target: target, action: action)
    }

    /// Eject in `volumeReleased`.
    public static func eject(target: AnyObject?, action: Selector?) -> ActionButton {
        ActionButton(title: "Eject", busyTitle: "Ejecting...", target: target, action: action)
    }

    /// Updates Proceed from the model (Requirements 13.5, 18.14).
    public func updateProceed(from model: WindowModel) {
        apply(enabled: model.controls.proceedEnabled, busy: model.isStageRunning)
        isHidden = model.window == nil || model.window == .volumeReleased
    }

    /// Updates Eject from the model (Requirements 18.21, 18.24).
    public func updateEject(from model: WindowModel) {
        apply(enabled: model.controls.ejectEnabled, busy: model.isUnmounting)
        isHidden = !model.controls.ejectVisible
    }
}
