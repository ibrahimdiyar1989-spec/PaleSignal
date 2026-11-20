import UIKit

enum ControlAction {
    case left
    case right
    case jump
    case crouch
    case flashlight
    case push
}

protocol TouchControlDelegate: AnyObject {
    func controlStateChanged(action: ControlAction, isPressed: Bool)
    func controlTriggered(action: ControlAction)
}

final class MultiTouchButton: UIView {
    let action: ControlAction
    weak var delegate: TouchControlDelegate?
    private let titleLabel = UILabel()
    private var activeTouches = Set<UITouch>()

    init(title: String, action: ControlAction) {
        self.action = action
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        backgroundColor = UIColor(white: 0.12, alpha: 0.42)
        layer.cornerRadius = 14
        layer.borderWidth = 1.2
        layer.borderColor = UIColor(white: 0.65, alpha: 0.35).cgColor

        titleLabel.text = title
        titleLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = UIColor(white: 0.92, alpha: 0.85)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateVisualState() {
        let pressed = !activeTouches.isEmpty
        backgroundColor = pressed
            ? UIColor(red: 0.78, green: 0.84, blue: 0.92, alpha: 0.35)
            : UIColor(white: 0.12, alpha: 0.42)
        layer.borderColor = pressed
            ? UIColor(white: 0.95, alpha: 0.75).cgColor
            : UIColor(white: 0.65, alpha: 0.35).cgColor
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasEmpty = activeTouches.isEmpty
        activeTouches.formUnion(touches)
        updateVisualState()
        if wasEmpty {
            delegate?.controlStateChanged(action: action, isPressed: true)
            delegate?.controlTriggered(action: action)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        updateVisualState()
        if activeTouches.isEmpty {
            delegate?.controlStateChanged(action: action, isPressed: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        updateVisualState()
        if activeTouches.isEmpty {
            delegate?.controlStateChanged(action: action, isPressed: false)
        }
    }

    func reset() {
        activeTouches.removeAll()
        updateVisualState()
    }
}

final class TouchControlOverlay: UIView {
    weak var delegate: TouchControlDelegate? {
        didSet {
            buttons.forEach { $0.delegate = delegate }
        }
    }

    private var buttons: [MultiTouchButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        setupButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupButtons() {
        let leftBtn = MultiTouchButton(title: "◀", action: .left)
        let rightBtn = MultiTouchButton(title: "▶", action: .right)

        let jumpBtn = MultiTouchButton(title: "JUMP", action: .jump)
        let duckBtn = MultiTouchButton(title: "DUCK", action: .crouch)
        let lightBtn = MultiTouchButton(title: "LIGHT", action: .flashlight)
        let pushBtn = MultiTouchButton(title: "PUSH", action: .push)

        buttons = [leftBtn, rightBtn, jumpBtn, duckBtn, lightBtn, pushBtn]
        buttons.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let safe = safeAreaLayoutGuide
        let btnSize: CGFloat = 58
        let gap: CGFloat = 12

        NSLayoutConstraint.activate([
            leftBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 18),
            leftBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            leftBtn.widthAnchor.constraint(equalToConstant: 66),
            leftBtn.heightAnchor.constraint(equalToConstant: btnSize),

            rightBtn.leadingAnchor.constraint(equalTo: leftBtn.trailingAnchor, constant: gap),
            rightBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            rightBtn.widthAnchor.constraint(equalToConstant: 66),
            rightBtn.heightAnchor.constraint(equalToConstant: btnSize),

            jumpBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -18),
            jumpBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            jumpBtn.widthAnchor.constraint(equalToConstant: 68),
            jumpBtn.heightAnchor.constraint(equalToConstant: btnSize),

            duckBtn.trailingAnchor.constraint(equalTo: jumpBtn.leadingAnchor, constant: -gap),
            duckBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            duckBtn.widthAnchor.constraint(equalToConstant: 68),
            duckBtn.heightAnchor.constraint(equalToConstant: btnSize),

            lightBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -18),
            lightBtn.bottomAnchor.constraint(equalTo: jumpBtn.topAnchor, constant: -gap),
            lightBtn.widthAnchor.constraint(equalToConstant: 68),
            lightBtn.heightAnchor.constraint(equalToConstant: 48),

            pushBtn.trailingAnchor.constraint(equalTo: lightBtn.leadingAnchor, constant: -gap),
            pushBtn.bottomAnchor.constraint(equalTo: duckBtn.topAnchor, constant: -gap),
            pushBtn.widthAnchor.constraint(equalToConstant: 68),
            pushBtn.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    func resetAll() {
        buttons.forEach { $0.reset() }
    }
}
