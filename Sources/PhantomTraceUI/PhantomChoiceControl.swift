import AppKit
import PhantomTraceCore

/// The Phantom_Choice radio group. Requirements 9.4, 13.3, 13.4, 13.5, 18.14.
///
/// It only draws the model: selection and enabled state come from `WindowModel`, and a click is
/// reported through `onSelect` so the coordinator stays the single owner of the choice.
@MainActor
public final class PhantomChoiceControl: NSView {
    /// Stage options offered, in escalation order. Clean Handoff is not offered (Requirement 9.4).
    public static let offeredStages: [ResolutionStage] = [.egressShells, .gracefulRequest, .banishLocks]
    public static let headerTitle = "Let PhantomTrace act"
    public static let handleMyselfTitle = "I'll deal with these processes myself"

    /// Called with the option the user clicked. Never called for a disabled option.
    public var onSelect: ((PhantomChoice) -> Void)?

    private let header = NSTextField(labelWithString: PhantomChoiceControl.headerTitle)
    private var stageButtons: [ResolutionStage: NSButton] = [:]
    private let handleMyselfButton: NSButton
    private let stack = NSStackView()

    public init() {
        handleMyselfButton = NSButton(radioButtonWithTitle: Self.handleMyselfTitle, target: nil, action: nil)
        super.init(frame: .zero)
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        for stage in Self.offeredStages {
            let button = NSButton(
                radioButtonWithTitle: Self.title(for: stage),
                target: self,
                action: #selector(stageClicked(_:))
            )
            button.tag = stage.rawValue
            stageButtons[stage] = button
            stack.addArrangedSubview(button)
            stack.setCustomSpacing(6, after: button)
        }
        handleMyselfButton.target = self
        handleMyselfButton.action = #selector(handleMyselfClicked(_:))
        stack.addArrangedSubview(handleMyselfButton)
        stack.setCustomSpacing(12, after: stageButtons[.banishLocks] ?? header)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setAccessibilityRole(.radioGroup)
        setAccessibilityLabel("Phantom choice")
        apply(controls: PhantomControls(), choice: nil, isStageRunning: false)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("PhantomChoiceControl is created in code only")
    }

    /// Title shown for a stage option.
    public static func title(for stage: ResolutionStage) -> String {
        switch stage {
        case .egressShells: return "Egress Shells"
        case .gracefulRequest: return "Graceful Request"
        case .banishLocks: return "Banish Locks"
        case .cleanHandoff: return "Clean Handoff"
        }
    }

    /// Redraws from the model. While a stage runs every option is disabled (Requirement 13.5).
    public func update(from model: WindowModel) {
        apply(controls: model.controls, choice: model.choice, isStageRunning: model.isStageRunning)
    }

    /// Redraws from explicit values; also used by tests.
    public func apply(controls: PhantomControls, choice: PhantomChoice?, isStageRunning: Bool) {
        for (stage, button) in stageButtons {
            let applicable = controls.enabledStages.contains(stage)
            button.isEnabled = applicable && !isStageRunning
            button.state = choice == .letPhantomTraceAct(stage) ? .on : .off
            button.setAccessibilityLabel(
                applicable ? Self.title(for: stage) : "\(Self.title(for: stage)), unavailable"
            )
            button.setAccessibilityHelp(
                applicable ? nil : "No process you own can be handled by this stage."
            )
            button.toolTip = applicable ? nil : "Not applicable to the current locks."
        }
        handleMyselfButton.isEnabled = controls.handleMyselfEnabled && !isStageRunning
        handleMyselfButton.state = choice == .handleMyself ? .on : .off
    }

    /// Option buttons keyed for tests and layout code.
    var optionButtons: [ResolutionStage: NSButton] { stageButtons }
    var handleMyselfOption: NSButton { handleMyselfButton }

    @objc private func stageClicked(_ sender: NSButton) {
        guard sender.isEnabled, let stage = ResolutionStage(rawValue: sender.tag) else { return }
        onSelect?(.letPhantomTraceAct(stage))
    }

    @objc private func handleMyselfClicked(_ sender: NSButton) {
        guard sender.isEnabled else { return }
        onSelect?(.handleMyself)
    }
}
