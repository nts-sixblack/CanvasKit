#if canImport(UIKit)
import UIKit
import CanvasKitCore

struct CanvasMaskedImageSelectionGeometry {
    var center: CGPoint
    var size: CGSize
    var rotation: CGFloat
    var scale: CGFloat
}

final class CanvasNodeView: UIView {
    private let textLabel = UILabel()
    private let imageView = UIImageView()
    private let maskedContentContainerView = UIView()
    private let maskedImageView = UIImageView()
    private let maskedEditingTintView = UIView()
    private let maskedOverlayImageView = UIImageView()
    private let maskedMaskImageView = UIImageView()
    private let shapeLayer = CAShapeLayer()
    private let placeholderView = UIView()
    private let placeholderLabel = UILabel()
    private let maskedPlaceholderPlusIconView = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private(set) var nodeID: String?
    var onMaskedImageGeometryDidChange: (() -> Void)?
    private var maskedImagePayload: CanvasMaskedImagePayload?
    private var maskedContentImage: UIImage?
    private var resolvedMaskedContentLayout: CanvasResolvedMaskedImageLayout?
    private var isMaskedImageEditingSelected = false
    private var usesMaskedPlaceholderStyle = false

    var maskedImageSelectionGeometry: CanvasMaskedImageSelectionGeometry? {
        guard let maskedImagePayload,
              let resolvedMaskedContentLayout else {
            return nil
        }

        return CanvasMaskedImageSelectionGeometry(
            center: resolvedMaskedContentLayout.center,
            size: resolvedMaskedContentLayout.size,
            rotation: CGFloat(maskedImagePayload.contentTransform.rotation),
            scale: CGFloat(maskedImagePayload.contentTransform.scale)
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false

        textLabel.numberOfLines = 0
        textLabel.adjustsFontSizeToFitWidth = false
        textLabel.isOpaque = false
        textLabel.backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        maskedContentContainerView.backgroundColor = .clear
        maskedContentContainerView.clipsToBounds = true

        maskedImageView.contentMode = .scaleToFill
        maskedImageView.clipsToBounds = false

        maskedEditingTintView.backgroundColor = CanvasEditorTheme.maskedImageEditingBackground
        maskedEditingTintView.isHidden = true

        maskedOverlayImageView.contentMode = .scaleToFill
        maskedOverlayImageView.clipsToBounds = true
        maskedOverlayImageView.isHidden = true

        maskedMaskImageView.contentMode = .scaleToFill

        placeholderLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.imagePlaceholderTitle
        placeholderLabel.textAlignment = .center
        placeholderLabel.textColor = CanvasEditorTheme.placeholderText
        placeholderLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.bodyFont.resolvedUIFont()

        maskedPlaceholderPlusIconView.image = UIImage(systemName: "plus.circle")
        maskedPlaceholderPlusIconView.contentMode = .scaleAspectFit
        maskedPlaceholderPlusIconView.tintColor = CanvasEditorTheme.accent
        maskedPlaceholderPlusIconView.isHidden = true
        maskedPlaceholderPlusIconView.accessibilityIdentifier = "canvas-node-masked-placeholder-plus"

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true

        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)

        maskedContentContainerView.addSubview(maskedImageView)
        maskedContentContainerView.addSubview(maskedEditingTintView)
        addSubview(maskedContentContainerView)
        addSubview(imageView)
        addSubview(textLabel)
        addSubview(placeholderView)
        addSubview(maskedOverlayImageView)

        placeholderView.addSubview(maskedPlaceholderPlusIconView)
        placeholderView.addSubview(placeholderLabel)
        placeholderView.addSubview(loadingIndicator)

        applyRegularPlaceholderStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let insetBounds = bounds.insetBy(dx: 8, dy: 8)
        shapeLayer.frame = bounds
        textLabel.frame = insetBounds
        imageView.frame = bounds
        maskedContentContainerView.frame = bounds
        maskedMaskImageView.frame = maskedContentContainerView.bounds
        maskedEditingTintView.frame = maskedContentContainerView.bounds
        maskedOverlayImageView.frame = bounds
        placeholderView.frame = bounds
        placeholderLabel.frame = placeholderView.bounds.insetBy(dx: 12, dy: 12)
        let plusIconSize = max(30, min(44, min(bounds.width, bounds.height) * 0.2))
        maskedPlaceholderPlusIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: plusIconSize,
            weight: .regular
        )
        maskedPlaceholderPlusIconView.bounds = CGRect(
            origin: .zero,
            size: CGSize(width: plusIconSize, height: plusIconSize)
        )
        maskedPlaceholderPlusIconView.center = CGPoint(
            x: placeholderView.bounds.midX,
            y: placeholderView.bounds.midY
        )
        loadingIndicator.center = CGPoint(x: placeholderView.bounds.midX, y: placeholderView.bounds.midY - 10)

        if usesMaskedPlaceholderStyle {
            placeholderView.layer.cornerRadius = 0
        } else {
            placeholderView.layer.cornerRadius = max(18, min(bounds.width, bounds.height) * 0.12)
        }

        updateMaskedContentLayout()
    }

    func apply(node: CanvasNode, assetLoader: CanvasAssetLoader) {
        nodeID = node.id
        accessibilityIdentifier = node.id
        bounds = CGRect(origin: .zero, size: node.size.cgSize)
        center = node.transform.position.cgPoint
        alpha = CGFloat(node.opacity)
        transform = CGAffineTransform(rotationAngle: node.transform.rotation)
            .scaledBy(x: node.transform.scale, y: node.transform.scale)

        maskedImagePayload = nil
        maskedContentImage = nil
        resolvedMaskedContentLayout = nil
        maskedImageView.image = nil
        maskedEditingTintView.isHidden = true
        maskedOverlayImageView.image = nil
        maskedOverlayImageView.isHidden = true
        maskedMaskImageView.image = nil
        maskedContentContainerView.mask = nil
        maskedContentContainerView.backgroundColor = .clear
        placeholderLabel.isHidden = false
        maskedPlaceholderPlusIconView.isHidden = true

        switch node.kind {
        case .text, .emoji:
            applyText(node: node)
            shapeLayer.isHidden = true
            imageView.isHidden = true
            maskedContentContainerView.isHidden = true
            maskedOverlayImageView.isHidden = true
            placeholderView.isHidden = true
            textLabel.isHidden = false
            loadingIndicator.stopAnimating()

        case .sticker, .image:
            applyImage(node: node, assetLoader: assetLoader)
            shapeLayer.isHidden = true
            textLabel.isHidden = true
            imageView.isHidden = false
            maskedContentContainerView.isHidden = true
            maskedOverlayImageView.isHidden = true

        case .maskedImage:
            applyMaskedImage(node: node, assetLoader: assetLoader)
            shapeLayer.isHidden = true
            textLabel.isHidden = true
            imageView.isHidden = true

        case .shape:
            applyShape(node: node)
            textLabel.isHidden = true
            imageView.isHidden = true
            maskedContentContainerView.isHidden = true
            maskedOverlayImageView.isHidden = true
        }
    }

    func setMaskedImageEditingState(_ isEditing: Bool) {
        isMaskedImageEditingSelected = isEditing
        updateMaskedEditingAppearance()
    }

    private func applyText(node: CanvasNode) {
        let style = node.style ?? (node.kind == .emoji ? .defaultEmoji : .defaultText)
        textLabel.attributedText = style.attributedString(text: node.text ?? "")
        textLabel.backgroundColor = style.resolvedBackgroundUIColor ?? .clear
        textLabel.layer.cornerRadius = style.backgroundFill == nil ? 0 : 16
        textLabel.clipsToBounds = style.backgroundFill != nil
    }

    private func applyImage(node: CanvasNode, assetLoader: CanvasAssetLoader) {
        applyRegularPlaceholderStyle()
        placeholderView.isHidden = false
        imageView.image = nil
        imageView.tintColor = node.style?.foregroundColor.uiColor ?? .white
        placeholderLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.imageLoadingTitle
        loadingIndicator.startAnimating()

        if node.source?.kind == .symbol {
            imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
                pointSize: CanvasSymbolNodeLayout.symbolPointSize(for: node),
                weight: .bold
            )
            imageView.contentMode = .scaleAspectFit
        } else {
            imageView.preferredSymbolConfiguration = nil
            imageView.contentMode = .scaleAspectFit
        }

        assetLoader.image(for: node.source) { [weak self] image in
            guard let self, self.nodeID == node.id else {
                return
            }
            self.imageView.image = image
            self.loadingIndicator.stopAnimating()
            self.placeholderLabel.text = image == nil
                ? CanvasEditorUIRuntime.currentConfiguration.strings.imagePlaceholderTitle
                : ""
            self.placeholderView.isHidden = image != nil
        }
    }

    private func applyMaskedImage(node: CanvasNode, assetLoader: CanvasAssetLoader) {
        guard let payload = node.maskedImage else {
            maskedContentContainerView.isHidden = true
            maskedOverlayImageView.isHidden = true
            placeholderView.isHidden = true
            loadingIndicator.stopAnimating()
            return
        }

        maskedImagePayload = payload
        maskedContentContainerView.isHidden = false
        maskedContentContainerView.backgroundColor = CanvasEditorTheme.placeholderBackground
        maskedContentContainerView.mask = nil
        updateMaskedContentLayout()
        updateMaskedEditingAppearance()

        applyMaskedPlaceholderStyle()
        placeholderView.isHidden = false
        let showsEmptyAffordance = node.source == nil
        placeholderLabel.text = showsEmptyAffordance
            ? ""
            : CanvasEditorUIRuntime.currentConfiguration.strings.imageLoadingTitle
        placeholderLabel.isHidden = showsEmptyAffordance
        maskedPlaceholderPlusIconView.isHidden = !showsEmptyAffordance

        if showsEmptyAffordance {
            loadingIndicator.stopAnimating()
        } else {
            loadingIndicator.startAnimating()
        }

        assetLoader.image(for: payload.maskSource) { [weak self] image in
            guard let self, self.nodeID == node.id else {
                return
            }
            self.maskedMaskImageView.image = image
            self.maskedContentContainerView.mask = image == nil ? nil : self.maskedMaskImageView
        }

        if let overlaySource = payload.overlaySource {
            assetLoader.image(for: overlaySource) { [weak self] image in
                guard let self, self.nodeID == node.id else {
                    return
                }
                self.maskedOverlayImageView.image = image
                self.maskedOverlayImageView.isHidden = image == nil
            }
        } else {
            maskedOverlayImageView.image = nil
            maskedOverlayImageView.isHidden = true
        }

        guard node.source != nil else {
            maskedContentImage = nil
            maskedImageView.image = nil
            return
        }

        assetLoader.image(for: node.source) { [weak self] image in
            guard let self, self.nodeID == node.id else {
                return
            }

            self.maskedContentImage = image
            self.maskedImageView.image = image
            self.updateMaskedContentLayout()
            self.loadingIndicator.stopAnimating()
            self.placeholderLabel.text = image == nil
                ? CanvasEditorUIRuntime.currentConfiguration.strings.imagePlaceholderTitle
                : ""
            self.placeholderLabel.isHidden = image != nil
            self.maskedPlaceholderPlusIconView.isHidden = true
            self.placeholderView.isHidden = image != nil
            self.maskedContentContainerView.backgroundColor = image == nil
                ? CanvasEditorTheme.placeholderBackground
                : .clear
            self.updateMaskedEditingAppearance()
        }
    }

    private func updateMaskedContentLayout() {
        guard let maskedImagePayload else {
            resolvedMaskedContentLayout = nil
            return
        }

        let layout = CanvasMaskedImageLayout.resolvedContentLayout(
            imageSize: maskedContentImage?.size ?? bounds.size,
            in: bounds,
            contentTransform: maskedImagePayload.contentTransform
        )
        resolvedMaskedContentLayout = layout

        maskedImageView.bounds = CGRect(origin: .zero, size: layout.size)
        maskedImageView.center = layout.center
        maskedImageView.transform = CGAffineTransform(rotationAngle: maskedImagePayload.contentTransform.rotation)
            .scaledBy(
                x: maskedImagePayload.contentTransform.scale,
                y: maskedImagePayload.contentTransform.scale
            )
        onMaskedImageGeometryDidChange?()
    }

    private func updateMaskedEditingAppearance() {
        guard maskedImagePayload != nil else {
            maskedEditingTintView.isHidden = true
            return
        }

        maskedEditingTintView.backgroundColor = CanvasEditorTheme.maskedImageEditingBackground
        maskedEditingTintView.isHidden = !isMaskedImageEditingSelected
    }

    private func applyShape(node: CanvasNode) {
        applyRegularPlaceholderStyle()
        shapeLayer.isHidden = false
        imageView.isHidden = true
        placeholderView.isHidden = true
        textLabel.isHidden = true
        loadingIndicator.stopAnimating()

        guard let payload = node.shape else {
            shapeLayer.path = nil
            return
        }

        shapeLayer.strokeColor = payload.strokeColor.uiColor.cgColor
        shapeLayer.lineWidth = payload.strokeWidth
        shapeLayer.path = payload.bezierPath().cgPath
    }

    private func applyRegularPlaceholderStyle() {
        usesMaskedPlaceholderStyle = false
        placeholderView.backgroundColor = CanvasEditorTheme.placeholderBackground
        placeholderView.layer.borderColor = CanvasEditorTheme.placeholderBorder.cgColor
        placeholderView.layer.borderWidth = 1
        placeholderLabel.isHidden = false
        maskedPlaceholderPlusIconView.isHidden = true
    }

    private func applyMaskedPlaceholderStyle() {
        usesMaskedPlaceholderStyle = true
        placeholderView.backgroundColor = .clear
        placeholderView.layer.borderColor = UIColor.clear.cgColor
        placeholderView.layer.borderWidth = 0
    }
}
#endif
