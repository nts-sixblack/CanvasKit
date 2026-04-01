#if canImport(UIKit)
import UIKit
import CanvasKitCore

final class CanvasSelectionOverlayView: UIView {
    private let borderLayer = CAShapeLayer()
    private var resolvedSelectionInset: CGFloat
    private var resolvedSelectionCornerRadius: CGFloat
    private var selectionInset: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionInset)
    }
    private var selectionCornerRadius: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionCornerRadius)
    }

    override init(frame: CGRect) {
        resolvedSelectionInset = CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionInset)
        resolvedSelectionCornerRadius = CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionCornerRadius)
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false

        borderLayer.strokeColor = CanvasEditorTheme.selectionBorder.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineDashPattern = [8, 6]
        borderLayer.lineWidth = 2
        layer.addSublayer(borderLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(roundedRect: selectionRect, cornerRadius: resolvedSelectionCornerRadius).cgPath
        CATransaction.commit()
    }

    var contentInset: CGFloat {
        resolvedSelectionInset
    }

    var selectionRect: CGRect {
        bounds.insetBy(dx: resolvedSelectionInset, dy: resolvedSelectionInset)
    }

    func apply(node: CanvasNode) {
        switch node.kind {
        case .maskedImage:
            resolvedSelectionInset = 0
            resolvedSelectionCornerRadius = 12
            borderLayer.lineDashPattern = nil
            borderLayer.lineWidth = 2
        default:
            resolvedSelectionInset = selectionInset
            resolvedSelectionCornerRadius = selectionCornerRadius
            borderLayer.lineDashPattern = [8, 6]
            borderLayer.lineWidth = 2
        }

        borderLayer.strokeColor = CanvasEditorTheme.selectionBorder.cgColor
        setNeedsLayout()
    }
}

final class OverlayHandleControl: UIControl {
    private let imageView = UIImageView()
    private var metrics: CanvasOverlayHandleMetrics

    init(systemImage: String, tintColor: UIColor = .black) {
        let layout = CanvasEditorUIRuntime.currentConfiguration.layout
        metrics = CanvasOverlayHandleLayoutMath.defaultMetrics(layout: layout)
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: metrics.handleSize, height: metrics.handleSize)))
        backgroundColor = CanvasEditorTheme.overlayHandleBackground
        layer.shadowColor = CanvasEditorTheme.overlayHandleShadow.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        imageView.image = UIImage(systemName: systemImage)
        imageView.tintColor = tintColor
        imageView.contentMode = .center
        addSubview(imageView)

        apply(metrics: metrics)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: metrics.handleSize, height: metrics.handleSize)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    func updateMetrics(_ metrics: CanvasOverlayHandleMetrics) {
        guard self.metrics != metrics else {
            return
        }
        apply(metrics: metrics)
    }

    private func apply(metrics: CanvasOverlayHandleMetrics) {
        self.metrics = metrics
        bounds.size = CGSize(width: metrics.handleSize, height: metrics.handleSize)
        layer.cornerRadius = metrics.cornerRadius
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: metrics.symbolPointSize,
            weight: .bold
        )
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}
#endif
