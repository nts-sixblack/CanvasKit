#if canImport(UIKit)
import UIKit
import CanvasKitCore

extension UIColor {
    var isLightColor: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
            return luminance > 0.68
        }

        let fallback = CIColor(color: self)
        let luminance = (0.299 * fallback.red) + (0.587 * fallback.green) + (0.114 * fallback.blue)
        return luminance > 0.68
    }
}

final class InspectorColorChipButton: UIButton {
    enum Kind {
        case color(UIColor)
        case clear
        case picker
    }

    private let ringView = UIView()
    private let swatchView = UIView()
    private let iconView = UIImageView()
    private var kind: Kind = .picker
    private var displayedColor: UIColor?

    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.isUserInteractionEnabled = false
        ringView.layer.cornerRadius = 22
        ringView.layer.borderWidth = 1.5
        addSubview(ringView)

        swatchView.translatesAutoresizingMaskIntoConstraints = false
        swatchView.isUserInteractionEnabled = false
        swatchView.layer.cornerRadius = 17
        addSubview(swatchView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44),

            ringView.leadingAnchor.constraint(equalTo: leadingAnchor),
            ringView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ringView.topAnchor.constraint(equalTo: topAnchor),
            ringView.bottomAnchor.constraint(equalTo: bottomAnchor),

            swatchView.centerXAnchor.constraint(equalTo: centerXAnchor),
            swatchView.centerYAnchor.constraint(equalTo: centerYAnchor),
            swatchView.widthAnchor.constraint(equalToConstant: 34),
            swatchView.heightAnchor.constraint(equalToConstant: 34),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(kind: Kind) {
        self.kind = kind
        updateAppearance()
    }

    func setDisplayedColor(_ color: UIColor?) {
        displayedColor = color
        updateAppearance()
    }

    private func updateAppearance() {
        switch kind {
        case .color(let color):
            swatchView.backgroundColor = color
            ringView.backgroundColor = .clear
            ringView.layer.borderColor = isSelected ? CanvasEditorTheme.accent.cgColor : UIColor.clear.cgColor
            iconView.image = isSelected
                ? UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.colorCheckmark)
                : nil
            iconView.tintColor = color.isLightColor ? .black : .white

        case .clear:
            swatchView.backgroundColor = CanvasEditorTheme.cardSurface
            ringView.backgroundColor = isSelected ? CanvasEditorTheme.accentMuted : CanvasEditorTheme.canvasBackdrop
            ringView.layer.borderColor = isSelected ? CanvasEditorTheme.accent.cgColor : CanvasEditorTheme.separator.cgColor
            iconView.image = isSelected
                ? UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.colorCheckmarkCircle)
                : UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.colorCircle)
            iconView.tintColor = isSelected ? CanvasEditorTheme.accent : CanvasEditorTheme.secondaryText

        case .picker:
            let resolvedColor = displayedColor ?? CanvasEditorTheme.canvasBackdrop
            swatchView.backgroundColor = resolvedColor
            ringView.backgroundColor = isSelected ? CanvasEditorTheme.accentMuted : CanvasEditorTheme.cardSurface
            ringView.layer.borderColor = isSelected ? CanvasEditorTheme.accent.cgColor : CanvasEditorTheme.separator.cgColor
            iconView.image = UIImage(
                systemName: displayedColor == nil
                    ? CanvasEditorUIRuntime.currentConfiguration.icons.colorPickerEmpty
                    : CanvasEditorUIRuntime.currentConfiguration.icons.colorPickerFilled
            )
            iconView.tintColor = displayedColor?.isLightColor == true ? .black : CanvasEditorTheme.primaryText
        }
    }
}

final class InspectorSliderRow: UIView {
    var onChange: ((Double) -> Void)?

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private let range: ClosedRange<Double>

    init(title: String, range: ClosedRange<Double>) {
        self.range = range
        super.init(frame: .zero)

        applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 18,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.controlShadow,
            shadowOpacity: 1,
            shadowRadius: 14,
            shadowOffset: CGSize(width: 0, height: 8)
        )

        titleLabel.text = title.uppercased()
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.sectionTitleFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.secondaryText

        valueLabel.textColor = CanvasEditorTheme.primaryText
        valueLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.valueFont.resolvedUIFont()
        valueLabel.textAlignment = .right

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel])
        header.axis = .horizontal

        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.minimumTrackTintColor = CanvasEditorTheme.accent
        slider.maximumTrackTintColor = CanvasEditorTheme.separator
        slider.thumbTintColor = CanvasEditorTheme.accent
        slider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            valueLabel.text = String(format: "%.1f", self.value)
            onChange?(self.value)
        }, for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [header, slider])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
        value = (range.lowerBound + range.upperBound) / 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var value: Double {
        get { Double(slider.value) }
        set {
            slider.value = Float(min(max(newValue, range.lowerBound), range.upperBound))
            valueLabel.text = String(format: "%.1f", Double(slider.value))
        }
    }
}
#endif
