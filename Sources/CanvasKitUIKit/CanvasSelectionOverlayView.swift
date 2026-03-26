#if canImport(UIKit)
import UIKit
import CanvasKitCore

final class CanvasSelectionOverlayView: UIView {
    private let borderLayer = CAShapeLayer()
    private var selectionInset: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionInset)
    }
    private var selectionCornerRadius: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.selectionCornerRadius)
    }

    override init(frame: CGRect) {
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
        borderLayer.path = UIBezierPath(roundedRect: selectionRect, cornerRadius: selectionCornerRadius).cgPath
        CATransaction.commit()
    }

    func apply(node: CanvasNode) {}

    var contentInset: CGFloat {
        selectionInset
    }

    var selectionRect: CGRect {
        bounds.insetBy(dx: selectionInset, dy: selectionInset)
    }
}

final class OverlayHandleControl: UIControl {
    private let imageView = UIImageView()

    init(systemImage: String, tintColor: UIColor = .black) {
        let layout = CanvasEditorUIRuntime.currentConfiguration.layout
        let size = CGFloat(layout.overlayHandleSize)
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = CanvasEditorTheme.overlayHandleBackground
        layer.cornerRadius = CGFloat(layout.overlayHandleCornerRadius)
        layer.shadowColor = CanvasEditorTheme.overlayHandleShadow.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        imageView.image = UIImage(systemName: systemImage)
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 33, weight: .bold)
        imageView.tintColor = tintColor
        imageView.contentMode = .center
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
#endif
