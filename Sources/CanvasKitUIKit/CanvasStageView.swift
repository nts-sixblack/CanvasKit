#if canImport(UIKit)
import UIKit
import CanvasKitCore

struct CanvasBrushConfiguration: Hashable {
    var type: CanvasShapeType
    var strokeWidth: Double
    var opacity: Double
    var color: CanvasColor

    static let defaultValue = CanvasBrushConfiguration(
        type: .brush,
        strokeWidth: 18,
        opacity: 1,
        color: .white
    )

    init(
        type: CanvasShapeType,
        strokeWidth: Double,
        opacity: Double,
        color: CanvasColor
    ) {
        self.type = type
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.color = color
    }

    init(shape: CanvasShapePayload, opacity: Double) {
        self.init(
            type: shape.type,
            strokeWidth: shape.strokeWidth,
            opacity: opacity,
            color: shape.strokeColor
        )
    }
}

private enum CanvasStageToolMode: Equatable {
    case drawing(CanvasBrushConfiguration)
    case erasing(strokeWidth: Double)
}

private final class CanvasOverlayPassthroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            guard !subview.isHidden,
                  subview.alpha > 0.01,
                  subview.isUserInteractionEnabled else {
                return false
            }

            let subviewPoint = subview.convert(point, from: self)
            return subview.point(inside: subviewPoint, with: event)
        }
    }
}

private enum CanvasTransparencyGridStyle {
    static let cellSize: CGFloat = 8
    static let lightColor = UIColor(white: 1, alpha: 1)
    static let darkColor = UIColor(white: 0.9, alpha: 1)
}

private final class CanvasTransparencyGridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.cornerCurve = .continuous
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setFillColor(CanvasTransparencyGridStyle.lightColor.cgColor)
        context.fill(rect)

        context.setFillColor(CanvasTransparencyGridStyle.darkColor.cgColor)

        let cellSize = CanvasTransparencyGridStyle.cellSize
        let rowRange = Int(floor(rect.minY / cellSize))...Int(ceil(rect.maxY / cellSize))
        let columnRange = Int(floor(rect.minX / cellSize))...Int(ceil(rect.maxX / cellSize))

        for row in rowRange {
            for column in columnRange where (row + column).isMultiple(of: 2) {
                let cellRect = CGRect(
                    x: CGFloat(column) * cellSize,
                    y: CGFloat(row) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                context.fill(cellRect.intersection(rect))
            }
        }
    }
}

private final class CanvasEraserMaskLayer: CALayer {
    var strokes: [CanvasEraserStroke] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var previewStroke: CanvasEraserStroke? {
        didSet {
            setNeedsDisplay()
        }
    }

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let layer = layer as? CanvasEraserMaskLayer {
            strokes = layer.strokes
            previewStroke = layer.previewStroke
        }
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in context: CGContext) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(bounds)

        var renderedStrokes = strokes
        if let previewStroke, !previewStroke.points.isEmpty {
            renderedStrokes.append(previewStroke)
        }
        CanvasEraserPathBuilder.applyClearStrokes(renderedStrokes, in: context)
    }

    private func commonInit() {
        contentsScale = 1
        needsDisplayOnBoundsChange = true
    }
}

@MainActor
protocol CanvasStageViewDelegate: AnyObject {
    func canvasStageViewDidTapSelectedTextNode(_ stageView: CanvasStageView)
    func canvasStageViewDidTapSelectedShapeNode(_ stageView: CanvasStageView)
    func canvasStageViewDidTapEmptyMaskedImageNode(_ stageView: CanvasStageView)
    func canvasStageViewDidBeginInlineEditing(_ stageView: CanvasStageView)
    func canvasStageViewDidEndInlineEditing(_ stageView: CanvasStageView)
    func canvasStageViewDidBeginNodeManipulation(_ stageView: CanvasStageView)
    func canvasStageView(_ stageView: CanvasStageView, didFinishDrawing draft: CanvasShapeDraft)
    func canvasStageView(_ stageView: CanvasStageView, didFinishErasing stroke: CanvasEraserStroke)
}

final class CanvasStageView: UIView, UIGestureRecognizerDelegate, UITextViewDelegate {
    weak var delegate: CanvasStageViewDelegate?

    var store: CanvasEditorStore? {
        didSet {
            rebindStore(oldValue: oldValue)
        }
    }

    let assetLoader = CanvasAssetLoader(resources: CanvasEditorUIRuntime.currentConfiguration.resources)

    private let transparencyGridView = CanvasTransparencyGridView()
    private let canvasContainerView = UIView()
    private let contentContainerView = UIView()
    private let backgroundColorView = UIView()
    private let backgroundImageView = UIImageView()
    private let filteredPreviewImageView = UIImageView()
    private let overlayControlContainerView = CanvasOverlayPassthroughView()
    private let lowerNodeContainerView = UIView()
    private let selectedNodeHostView = UIView()
    private let upperNodeContainerView = UIView()
    private let drawingPreviewView = UIView()
    private let selectionOverlay = CanvasSelectionOverlayView()
    private let inlineTextView = UITextView()

    private let deleteHandle = OverlayHandleControl(
        systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.handleDelete,
        tintColor: CanvasEditorTheme.destructive
    )
    private let widthHandle = OverlayHandleControl(
        systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.handleResizeWidth,
        tintColor: CanvasEditorTheme.overlayHandleTint
    )
    private let heightHandle = OverlayHandleControl(
        systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.handleResizeHeight,
        tintColor: CanvasEditorTheme.overlayHandleTint
    )
    private let transformHandle = OverlayHandleControl(
        systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.handleTransform,
        tintColor: CanvasEditorTheme.overlayHandleTint
    )
    private let drawingPreviewLayer = CAShapeLayer()
    private let eraserMaskLayer = CanvasEraserMaskLayer()

    private lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    private lazy var doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    private lazy var pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    private lazy var rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
    private lazy var drawingPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDrawingPan(_:)))

    private var projectObserverID: UUID?
    private var selectionObserverID: UUID?
    private var nodeViews: [String: CanvasNodeView] = [:]
    private var pendingProject: CanvasProject?
    private var filteredPreviewRenderToken = UUID()
    private var previewCanvasFilterOverride: CanvasFilterPreset?

    private var canvasSize: CGSize = .zero
    private var canvasScale: CGFloat = 1
    private var hasCompletedInitialViewportLayout = false
    private var activePanTranslation: CGPoint = .zero
    private var activePanNodeID: String?
    private var activePinchNodeID: String?
    private var activeRotationNodeID: String?
    private var lastTransformVector: CGPoint?
    private var lastTextWidthTranslation: CGPoint = .zero
    private var lastTextHeightTranslation: CGPoint = .zero
    private var editingNodeID: String?
    private var activeEditingStyle: CanvasTextStyle?
    private var isApplyingInlineEditorState = false
    private var toolMode: CanvasStageToolMode?
    private var toolPoints: [CGPoint] = []
    private var toolStartPoint: CGPoint?

    private var viewportPadding: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.viewportPadding)
    }
    private var textContentInset: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.textContentInset)
    }
    private var hasRenderableBounds: Bool {
        bounds.width > 0 && bounds.height > 0
    }

    var isToolModeActive: Bool {
        toolMode != nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = CanvasEditorTheme.canvasBackdrop

        canvasContainerView.backgroundColor = .clear
        canvasContainerView.layer.shadowColor = CanvasEditorTheme.surfaceShadow.cgColor
        canvasContainerView.layer.shadowOpacity = 1
        canvasContainerView.layer.shadowRadius = 24
        canvasContainerView.layer.shadowOffset = CGSize(width: 0, height: 14)
        contentContainerView.clipsToBounds = true
        contentContainerView.layer.cornerRadius = CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.surfaceCornerRadius)
        contentContainerView.layer.cornerCurve = .continuous
        overlayControlContainerView.backgroundColor = .clear

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        filteredPreviewImageView.contentMode = .scaleToFill
        filteredPreviewImageView.clipsToBounds = true
        filteredPreviewImageView.isUserInteractionEnabled = false
        filteredPreviewImageView.isHidden = true

        lowerNodeContainerView.clipsToBounds = true
        selectedNodeHostView.clipsToBounds = false
        upperNodeContainerView.clipsToBounds = true
        drawingPreviewView.clipsToBounds = true
        drawingPreviewView.isUserInteractionEnabled = false
        drawingPreviewView.isHidden = true

        selectionOverlay.isHidden = true

        inlineTextView.isOpaque = false
        inlineTextView.backgroundColor = .clear
        inlineTextView.textContainerInset = .zero
        inlineTextView.textContainer.lineFragmentPadding = 0
        inlineTextView.autocorrectionType = .no
        inlineTextView.autocapitalizationType = .sentences
        inlineTextView.smartQuotesType = .no
        inlineTextView.smartDashesType = .no
        inlineTextView.smartInsertDeleteType = .no
        inlineTextView.isScrollEnabled = false
        inlineTextView.isHidden = true
        inlineTextView.delegate = self

        drawingPreviewLayer.fillColor = UIColor.clear.cgColor
        drawingPreviewLayer.lineCap = .round
        drawingPreviewLayer.lineJoin = .round
        drawingPreviewLayer.isHidden = true
        drawingPreviewView.layer.addSublayer(drawingPreviewLayer)
        contentContainerView.layer.mask = eraserMaskLayer

        addSubview(transparencyGridView)
        addSubview(canvasContainerView)
        addSubview(overlayControlContainerView)
        canvasContainerView.addSubview(contentContainerView)
        contentContainerView.addSubview(backgroundColorView)
        contentContainerView.addSubview(backgroundImageView)
        contentContainerView.addSubview(lowerNodeContainerView)
        contentContainerView.addSubview(selectedNodeHostView)
        contentContainerView.addSubview(upperNodeContainerView)
        canvasContainerView.addSubview(filteredPreviewImageView)
        canvasContainerView.addSubview(drawingPreviewView)
        canvasContainerView.addSubview(selectionOverlay)
        canvasContainerView.addSubview(inlineTextView)

        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach {
            $0.isHidden = true
            overlayControlContainerView.addSubview($0)
        }

        deleteHandle.addAction(UIAction { [weak self] _ in
            self?.handleDeleteTapped()
        }, for: .touchUpInside)

        let transformPan = UIPanGestureRecognizer(target: self, action: #selector(handleTransformHandlePan(_:)))
        let widthPan = UIPanGestureRecognizer(target: self, action: #selector(handleTextWidthHandlePan(_:)))
        let heightPan = UIPanGestureRecognizer(target: self, action: #selector(handleTextHeightHandlePan(_:)))
        transformHandle.addGestureRecognizer(transformPan)
        widthHandle.addGestureRecognizer(widthPan)
        heightHandle.addGestureRecognizer(heightPan)

        tapGestureRecognizer.cancelsTouchesInView = false
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.cancelsTouchesInView = false
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        drawingPanGestureRecognizer.maximumNumberOfTouches = 1
        drawingPanGestureRecognizer.isEnabled = false

        [tapGestureRecognizer, doubleTapGestureRecognizer, panGestureRecognizer, pinchGestureRecognizer, rotationGestureRecognizer, drawingPanGestureRecognizer].forEach {
            $0.delegate = self
            addGestureRecognizer($0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    isolated deinit {
        if let projectObserverID {
            store?.removeObserver(projectObserverID)
        }
        if let selectionObserverID {
            store?.removeObserver(selectionObserverID)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard hasRenderableBounds else {
            return
        }

        if let pendingProject {
            let shouldDisableAnimations = !hasCompletedInitialViewportLayout
            performStageUpdates(disablingAnimations: shouldDisableAnimations) {
                applyProject(pendingProject)
                self.pendingProject = nil
                applyViewportLayout()
            }

            if canvasSize.width > 0, canvasSize.height > 0 {
                hasCompletedInitialViewportLayout = true
            }
            return
        }

        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return
        }

        let shouldDisableAnimations = !hasCompletedInitialViewportLayout
        performStageUpdates(disablingAnimations: shouldDisableAnimations) {
            applyViewportLayout()
        }
        hasCompletedInitialViewportLayout = true
    }

    func renderProject(_ project: CanvasProject) {
        pendingProject = project

        guard hasRenderableBounds, hasCompletedInitialViewportLayout else {
            setNeedsLayout()
            return
        }

        applyProject(project)
        pendingProject = nil
        setNeedsLayout()
        layoutIfNeeded()
        updateEraserMask(strokes: project.eraserStrokes)
        updateSelectionOverlay()
        updateInlineTextEditor()
    }

    func beginInlineEditingForSelectedNode(placeCursorAtEnd: Bool = true) {
        guard let node = store?.selectedNode,
              node.isEditable,
              node.kind == .text else {
            return
        }
        editingNodeID = node.id
        activeEditingStyle = node.style
        delegate?.canvasStageViewDidBeginInlineEditing(self)
        syncNodePresentation()
        updateInlineTextEditor(forceTextRefresh: true)
        refreshFilteredPreviewIfNeeded()

        let targetOffset = placeCursorAtEnd ? (inlineTextView.text as NSString).length : 0
        inlineTextView.selectedRange = NSRange(location: targetOffset, length: 0)
        inlineTextView.becomeFirstResponder()
    }

    func setPreviewCanvasFilter(_ filter: CanvasFilterPreset?) {
        guard previewCanvasFilterOverride != filter else {
            return
        }
        previewCanvasFilterOverride = filter
        refreshFilteredPreviewIfNeeded()
    }

    func beginDrawing(with configuration: CanvasBrushConfiguration) {
        endInlineEditing()
        toolMode = .drawing(configuration)
        resetCurrentToolStrokePreview()
        drawingPreviewView.isHidden = false
        drawingPreviewLayer.isHidden = false
        setNodeGesturesEnabled(false)
        drawingPanGestureRecognizer.isEnabled = true
        selectionOverlay.isHidden = true
        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach { $0.isHidden = true }
        canvasContainerView.bringSubviewToFront(drawingPreviewView)
    }

    func beginErasing(strokeWidth: Double) {
        endInlineEditing()
        toolMode = .erasing(strokeWidth: strokeWidth)
        resetCurrentToolStrokePreview()
        drawingPreviewView.isHidden = true
        drawingPreviewLayer.isHidden = true
        setNodeGesturesEnabled(false)
        drawingPanGestureRecognizer.isEnabled = true
        selectionOverlay.isHidden = true
        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach { $0.isHidden = true }
    }

    func cancelDrawingMode() {
        toolMode = nil
        resetCurrentToolStrokePreview()
        drawingPreviewLayer.isHidden = true
        drawingPreviewView.isHidden = true
        drawingPanGestureRecognizer.isEnabled = false
        setNodeGesturesEnabled(true)
        updateSelectionOverlay()
    }

    func endInlineEditing() {
        guard editingNodeID != nil else {
            return
        }
        if inlineTextView.isFirstResponder {
            inlineTextView.resignFirstResponder()
        } else {
            endInlineEditingWithoutResigning()
        }
    }

    func ensureSelectedTextFitsHeight() {
        guard let store, let node = store.selectedNode, node.kind == .text else {
            return
        }

        let style = node.style ?? .defaultText
        let contentWidth = max(node.size.width - (textContentInset * 2), 40)
        let requiredHeight = style.requiredTextHeight(
            text: node.text ?? "",
            constrainedWidth: contentWidth
        ) + (textContentInset * 2)

        guard abs(requiredHeight - node.size.height) > 0.5 else {
            return
        }

        store.updateSelectedTextHeight(requiredHeight)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === drawingPanGestureRecognizer {
            return isToolModeActive
        }

        guard let touchedView = touch.view else {
            return true
        }

        let blockedViews = [inlineTextView, deleteHandle, widthHandle, heightHandle, transformHandle]
        return !blockedViews.contains(where: { touchedView.isDescendant(of: $0) })
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gestureTypes = [type(of: gestureRecognizer), type(of: otherGestureRecognizer)]
        return gestureTypes.contains(where: { $0 == UIPinchGestureRecognizer.self }) &&
            gestureTypes.contains(where: { $0 == UIRotationGestureRecognizer.self })
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingInlineEditorState else {
            return
        }
        store?.updateSelectedText(textView.text)
        ensureSelectedTextFitsHeight()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        endInlineEditingWithoutResigning()
    }

    @objc
    private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: canvasContainerView)
        let tappedNode = hitTestNode(at: location)
        let tappedSelectedTextNode = tappedNode?.id == store?.selectedNodeID && tappedNode?.kind == .text
        let tappedSelectedShapeNode = tappedNode?.id == store?.selectedNodeID && tappedNode?.kind == .shape
        let tappedEmptyMaskedImageNode = tappedNode?.kind == .maskedImage && tappedNode?.source == nil

        if editingNodeID != nil, tappedNode?.id != editingNodeID {
            endInlineEditing()
        }

        store?.selectNode(tappedNode?.id)
        if tappedEmptyMaskedImageNode {
            delegate?.canvasStageViewDidTapEmptyMaskedImageNode(self)
        } else if tappedSelectedTextNode, editingNodeID == nil {
            delegate?.canvasStageViewDidTapSelectedTextNode(self)
        } else if tappedSelectedShapeNode, editingNodeID == nil {
            delegate?.canvasStageViewDidTapSelectedShapeNode(self)
        }
    }

    @objc
    private func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: canvasContainerView)
        guard let node = hitTestNode(at: location) else {
            return
        }
        store?.selectNode(node.id)
        if node.kind == .text {
            beginInlineEditingForSelectedNode()
        }
    }

    @objc
    private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let store else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            activePanTranslation = .zero
            activePanNodeID = nil
            let location = gestureRecognizer.location(in: canvasContainerView)
            if let node = hitTestNode(at: location) {
                if editingNodeID != nil, editingNodeID != node.id {
                    endInlineEditing()
                }
                delegate?.canvasStageViewDidBeginNodeManipulation(self)
                store.selectNode(node.id)
                activePanNodeID = node.id
            }

        case .changed:
            guard activePanNodeID == store.selectedNodeID,
                  let selectedNode = store.selectedNode,
                  selectedNode.isEditable else {
                return
            }
            let translation = gestureRecognizer.translation(in: self)
            let delta = CGPoint(
                x: (translation.x - activePanTranslation.x) / max(canvasScale, 0.001),
                y: (translation.y - activePanTranslation.y) / max(canvasScale, 0.001)
            )
            activePanTranslation = translation

            if selectedNode.kind == .maskedImage {
                let projectedDelta = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
                    delta,
                    rotation: selectedNode.transform.rotation
                )
                store.moveSelectedMaskedImageContent(
                    by: CanvasPoint(
                        x: projectedDelta.localDeltaX,
                        y: projectedDelta.localDeltaY
                    )
                )
            } else {
                store.moveSelectedNode(by: CanvasPoint(delta))
            }

        default:
            activePanTranslation = .zero
            activePanNodeID = nil
        }
    }

    @objc
    private func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let store else {
            return
        }

        if gestureRecognizer.state == .began {
            activePinchNodeID = nil
            let location = gestureRecognizer.location(in: canvasContainerView)
            if let node = hitTestNode(at: location) {
                if editingNodeID != nil, editingNodeID != node.id {
                    endInlineEditing()
                }
                delegate?.canvasStageViewDidBeginNodeManipulation(self)
                store.selectNode(node.id)
                activePinchNodeID = node.id
            }
        }

        switch gestureRecognizer.state {
        case .changed:
            guard activePinchNodeID == store.selectedNodeID,
                  let selectedNode = store.selectedNode,
                  selectedNode.isEditable else {
                return
            }

            if selectedNode.kind == .maskedImage {
                store.scaleSelectedMaskedImageContent(by: gestureRecognizer.scale)
            } else {
                store.scaleSelectedNode(by: gestureRecognizer.scale)
            }
            gestureRecognizer.scale = 1

        default:
            if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed {
                activePinchNodeID = nil
            }
        }
    }

    @objc
    private func handleRotation(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let store else {
            return
        }

        if gestureRecognizer.state == .began {
            activeRotationNodeID = nil
            let location = gestureRecognizer.location(in: canvasContainerView)
            if let node = hitTestNode(at: location) {
                if editingNodeID != nil, editingNodeID != node.id {
                    endInlineEditing()
                }
                delegate?.canvasStageViewDidBeginNodeManipulation(self)
                store.selectNode(node.id)
                activeRotationNodeID = node.id
            }
        }

        switch gestureRecognizer.state {
        case .changed:
            guard activeRotationNodeID == store.selectedNodeID,
                  let selectedNode = store.selectedNode,
                  selectedNode.isEditable else {
                return
            }

            if selectedNode.kind == .maskedImage {
                store.rotateSelectedMaskedImageContent(by: gestureRecognizer.rotation)
            } else {
                store.rotateSelectedNode(by: gestureRecognizer.rotation)
            }
            gestureRecognizer.rotation = 0

        default:
            if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed {
                activeRotationNodeID = nil
            }
        }
    }

    @objc
    private func handleTransformHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let store, let selectedNode = store.selectedNode else {
            return
        }

        if gestureRecognizer.state == .began {
            endInlineEditing()
            delegate?.canvasStageViewDidBeginNodeManipulation(self)
        }

        let location = gestureRecognizer.location(in: canvasContainerView)
        let center: CGPoint = if selectedNode.kind == .maskedImage,
                                 let selectedView = nodeViews[selectedNode.id],
                                 let maskedSelectionGeometry = selectedView.maskedImageSelectionGeometry {
            selectedView.convert(maskedSelectionGeometry.center, to: canvasContainerView)
        } else {
            selectedNode.transform.position.cgPoint
        }
        let vector = CGPoint(x: location.x - center.x, y: location.y - center.y)

        switch gestureRecognizer.state {
        case .began:
            lastTransformVector = vector

        case .changed:
            guard let previousVector = lastTransformVector else {
                lastTransformVector = vector
                return
            }
            let previousLength = max(hypot(previousVector.x, previousVector.y), 1)
            let currentLength = max(hypot(vector.x, vector.y), 1)
            let scaleMultiplier = currentLength / previousLength
            let previousAngle = atan2(previousVector.y, previousVector.x)
            let currentAngle = atan2(vector.y, vector.x)

            if selectedNode.kind == .maskedImage {
                store.transformSelectedMaskedImageContent(
                    scaleMultiplier: scaleMultiplier,
                    rotationDelta: currentAngle - previousAngle
                )
            } else {
                store.transformSelectedNode(
                    scaleMultiplier: scaleMultiplier,
                    rotationDelta: currentAngle - previousAngle
                )
            }
            lastTransformVector = vector

        default:
            lastTransformVector = nil
        }
    }

    @objc
    private func handleTextWidthHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let store, let selectedNode = store.selectedNode, selectedNode.kind == .text else {
            return
        }

        if gestureRecognizer.state == .began {
            endInlineEditing()
            lastTextWidthTranslation = .zero
            delegate?.canvasStageViewDidBeginNodeManipulation(self)
        }

        let translation = gestureRecognizer.translation(in: canvasContainerView)
        let delta = CGPoint(
            x: translation.x - lastTextWidthTranslation.x,
            y: translation.y - lastTextWidthTranslation.y
        )

        switch gestureRecognizer.state {
        case .changed:
            let projectedDelta = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
                delta,
                rotation: selectedNode.transform.rotation
            )
            let widthDelta = projectedDelta.localDeltaX / max(selectedNode.transform.scale, 0.001)
            store.adjustSelectedTextWidth(by: widthDelta)
            ensureSelectedTextFitsHeight()
            lastTextWidthTranslation = translation

        default:
            lastTextWidthTranslation = .zero
        }
    }

    @objc
    private func handleTextHeightHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let store, let selectedNode = store.selectedNode, selectedNode.kind == .text else {
            return
        }

        if gestureRecognizer.state == .began {
            endInlineEditing()
            lastTextHeightTranslation = .zero
            delegate?.canvasStageViewDidBeginNodeManipulation(self)
        }

        let translation = gestureRecognizer.translation(in: canvasContainerView)
        let delta = CGPoint(
            x: translation.x - lastTextHeightTranslation.x,
            y: translation.y - lastTextHeightTranslation.y
        )

        switch gestureRecognizer.state {
        case .changed:
            let projectedDelta = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
                delta,
                rotation: selectedNode.transform.rotation
            )
            let heightDelta = projectedDelta.localDeltaY / max(selectedNode.transform.scale, 0.001)
            let style = selectedNode.style ?? .defaultText
            let minimumHeight = style.requiredTextHeight(
                text: selectedNode.text ?? "",
                constrainedWidth: max(selectedNode.size.width - (textContentInset * 2), 40)
            ) + (textContentInset * 2)
            store.adjustSelectedTextHeight(by: heightDelta, minimumHeight: minimumHeight)
            lastTextHeightTranslation = translation

        default:
            lastTextHeightTranslation = .zero
        }
    }

    @objc
    private func handleDrawingPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let toolMode else {
            return
        }

        let location = clampedCanvasPoint(gestureRecognizer.location(in: canvasContainerView))

        switch gestureRecognizer.state {
        case .began:
            toolStartPoint = location
            toolPoints = [location]
            updateToolPreview()

        case .changed:
            guard let toolStartPoint else {
                return
            }

            switch toolMode {
            case .drawing(let configuration):
                switch configuration.type {
                case .brush:
                    appendFreehandPoint(location)
                case .line, .arrow, .oval, .rectangle:
                    toolPoints = [toolStartPoint, location]
                }
            case .erasing:
                appendFreehandPoint(location)
            }

            updateToolPreview()

        case .ended:
            switch toolMode {
            case .drawing(let configuration):
                if let draft = currentShapeDraft(using: configuration) {
                    delegate?.canvasStageView(self, didFinishDrawing: draft)
                }
                resetCurrentToolStrokePreview()
            case .erasing(let strokeWidth):
                if let stroke = currentEraserStroke(strokeWidth: strokeWidth) {
                    delegate?.canvasStageView(self, didFinishErasing: stroke)
                }
                resetCurrentToolStrokePreview()
            }

        case .cancelled, .failed:
            switch toolMode {
            case .drawing:
                resetCurrentToolStrokePreview()
            case .erasing:
                resetCurrentToolStrokePreview()
            }

        default:
            break
        }
    }

    private func handleDeleteTapped() {
        endInlineEditing()
        store?.deleteSelectedContent()
    }

    private func setNodeGesturesEnabled(_ enabled: Bool) {
        tapGestureRecognizer.isEnabled = enabled
        doubleTapGestureRecognizer.isEnabled = enabled
        panGestureRecognizer.isEnabled = enabled
        pinchGestureRecognizer.isEnabled = enabled
        rotationGestureRecognizer.isEnabled = enabled
    }

    private func resetCurrentToolStrokePreview() {
        toolPoints.removeAll()
        toolStartPoint = nil
        drawingPreviewLayer.path = nil
        drawingPreviewLayer.isHidden = true
        updateEraserMask()
    }

    private func clampedCanvasPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), canvasSize.width),
            y: min(max(point.y, 0), canvasSize.height)
        )
    }

    private func appendFreehandPoint(_ point: CGPoint) {
        if let previousPoint = toolPoints.last {
            let distance = hypot(point.x - previousPoint.x, point.y - previousPoint.y)
            if distance >= 1.5 {
                toolPoints.append(point)
            } else {
                toolPoints[toolPoints.count - 1] = point
            }
        } else {
            toolPoints = [point]
        }
    }

    private func updateToolPreview() {
        guard let toolMode else {
            drawingPreviewLayer.path = nil
            drawingPreviewLayer.isHidden = true
            updateEraserMask()
            return
        }

        switch toolMode {
        case .drawing(let configuration):
            drawingPreviewView.isHidden = false
            drawingPreviewLayer.path = CanvasShapePathBuilder.makePath(
                type: configuration.type,
                points: toolPoints
            ).cgPath
            drawingPreviewLayer.strokeColor = configuration.color.uiColor.withAlphaComponent(configuration.opacity).cgColor
            drawingPreviewLayer.lineWidth = configuration.strokeWidth
            updateEraserMask()
        case .erasing(let strokeWidth):
            drawingPreviewLayer.path = nil
            drawingPreviewLayer.isHidden = true
            drawingPreviewView.isHidden = true
            updateEraserMask(previewStroke: currentEraserStroke(strokeWidth: strokeWidth))
            return
        }

        drawingPreviewLayer.isHidden = toolPoints.isEmpty
    }

    private func currentShapeDraft(using configuration: CanvasBrushConfiguration) -> CanvasShapeDraft? {
        guard !toolPoints.isEmpty else {
            return nil
        }

        let minimumDistance = max(CGFloat(configuration.strokeWidth) * 0.5, 6)
        let pointDistance: CGFloat
        if let first = toolPoints.first, let last = toolPoints.last {
            pointDistance = hypot(last.x - first.x, last.y - first.y)
        } else {
            pointDistance = 0
        }

        if configuration.type != .brush, pointDistance < minimumDistance {
            return nil
        }

        return CanvasShapeDraft(
            type: configuration.type,
            points: toolPoints.map { point in
                CanvasPoint(x: point.x, y: point.y)
            },
            strokeColor: configuration.color,
            strokeWidth: configuration.strokeWidth,
            opacity: configuration.opacity
        )
    }

    private func currentEraserStroke(strokeWidth: Double) -> CanvasEraserStroke? {
        guard !toolPoints.isEmpty else {
            return nil
        }

        return CanvasEraserStroke(
            points: toolPoints.map { CanvasPoint(x: $0.x, y: $0.y) },
            strokeWidth: strokeWidth
        )
    }

    private func updateEraserMask(
        strokes: [CanvasEraserStroke]? = nil,
        previewStroke: CanvasEraserStroke? = nil
    ) {
        let resolvedPreviewStroke = previewStroke ?? {
            guard case .erasing(let strokeWidth) = toolMode else {
                return nil
            }
            return currentEraserStroke(strokeWidth: strokeWidth)
        }()

        guard canvasSize.width > 0, canvasSize.height > 0 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            eraserMaskLayer.strokes = []
            eraserMaskLayer.previewStroke = nil
            CATransaction.commit()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eraserMaskLayer.strokes = strokes ?? store?.project.eraserStrokes ?? []
        eraserMaskLayer.previewStroke = resolvedPreviewStroke
        CATransaction.commit()
    }

    private func applyProject(_ project: CanvasProject) {
        canvasSize = project.canvasSize.cgSize

        backgroundColorView.backgroundColor = project.background.color?.uiColor ?? .clear
        backgroundImageView.image = nil
        if project.background.kind == .image {
            assetLoader.image(for: project.background.source) { [weak self] image in
                self?.backgroundImageView.image = image
            }
        }

        nodeViews.values.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()

        project.sortedNodes.forEach { node in
            let nodeView = CanvasNodeView()
            nodeView.viewportScale = canvasScale
            nodeView.onMaskedImageGeometryDidChange = { [weak self, weak nodeView] in
                guard let self, let nodeView, self.store?.selectedNodeID == nodeView.nodeID else {
                    return
                }
                self.updateSelectionOverlay()
            }
            nodeView.apply(node: node, assetLoader: assetLoader)
            nodeViews[node.id] = nodeView
        }

        syncNodePresentation()
        canvasContainerView.bringSubviewToFront(filteredPreviewImageView)
        canvasContainerView.bringSubviewToFront(drawingPreviewView)
        canvasContainerView.bringSubviewToFront(selectionOverlay)
        canvasContainerView.bringSubviewToFront(inlineTextView)
        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach {
            overlayControlContainerView.bringSubviewToFront($0)
        }
        bringSubviewToFront(overlayControlContainerView)
    }

    private func applyViewportLayout() {
        let layout = CanvasViewportMath.fit(canvasSize: canvasSize, in: bounds, padding: viewportPadding)
        canvasScale = layout.scale
        nodeViews.values.forEach { $0.viewportScale = canvasScale }

        canvasContainerView.bounds = CGRect(origin: .zero, size: canvasSize)
        canvasContainerView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        canvasContainerView.transform = CGAffineTransform(scaleX: canvasScale, y: canvasScale)
        transparencyGridView.frame = layout.canvasFrame
        transparencyGridView.layer.cornerRadius = contentContainerView.layer.cornerRadius * canvasScale
        transparencyGridView.isHidden = layout.canvasFrame.isEmpty
        transparencyGridView.setNeedsDisplay()
        overlayControlContainerView.frame = bounds
        canvasContainerView.layer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: canvasSize),
            cornerRadius: contentContainerView.layer.cornerRadius
        ).cgPath

        contentContainerView.frame = CGRect(origin: .zero, size: canvasSize)
        backgroundColorView.frame = contentContainerView.bounds
        backgroundImageView.frame = contentContainerView.bounds
        filteredPreviewImageView.frame = contentContainerView.frame
        filteredPreviewImageView.layer.cornerRadius = contentContainerView.layer.cornerRadius
        filteredPreviewImageView.layer.cornerCurve = .continuous
        [lowerNodeContainerView, selectedNodeHostView, upperNodeContainerView, drawingPreviewView].forEach {
            $0.frame = CGRect(origin: .zero, size: canvasSize)
        }
        drawingPreviewLayer.frame = drawingPreviewView.bounds
        eraserMaskLayer.frame = contentContainerView.bounds
        updateEraserMask()
        refreshFilteredPreviewIfNeeded()

        updateOverlayHandleMetrics()
        updateSelectionOverlay()
        updateInlineTextEditor()
    }

    private func performStageUpdates(disablingAnimations: Bool, updates: () -> Void) {
        guard disablingAnimations else {
            updates()
            return
        }

        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updates()
            CATransaction.commit()
        }
    }

    private func rebindStore(oldValue: CanvasEditorStore?) {
        if let projectObserverID {
            oldValue?.removeObserver(projectObserverID)
        }
        if let selectionObserverID {
            oldValue?.removeObserver(selectionObserverID)
        }

        projectObserverID = store?.observeProject { [weak self] project in
            self?.renderProject(project)
        }
        selectionObserverID = store?.observeSelection { [weak self] selectedNodeID in
            guard let self else { return }
            if let editingNodeID = self.editingNodeID, editingNodeID != selectedNodeID {
                self.endInlineEditing()
            }
            self.syncNodePresentation()
            self.updateSelectionOverlay()
            self.updateInlineTextEditor()
        }
    }

    private func syncNodePresentation() {
        guard let store else {
            return
        }

        let sortedNodes = store.project.sortedNodes
        let selectedNodeIndex = store.selectedNodeID.flatMap { selectedNodeID in
            sortedNodes.firstIndex(where: { $0.id == selectedNodeID })
        }

        if let selectedNodeIndex {
            for node in sortedNodes[..<selectedNodeIndex] {
                guard let nodeView = nodeViews[node.id] else {
                    continue
                }
                lowerNodeContainerView.addSubview(nodeView)
            }

            if let selectedNodeView = nodeViews[sortedNodes[selectedNodeIndex].id] {
                selectedNodeHostView.addSubview(selectedNodeView)
            }

            for node in sortedNodes[(selectedNodeIndex + 1)...] {
                guard let nodeView = nodeViews[node.id] else {
                    continue
                }
                upperNodeContainerView.addSubview(nodeView)
            }
        } else {
            for node in sortedNodes {
                guard let nodeView = nodeViews[node.id] else {
                    continue
                }
                lowerNodeContainerView.addSubview(nodeView)
            }
        }

        for node in sortedNodes {
            nodeViews[node.id]?.setMaskedImageEditingState(node.id == store.selectedNodeID)
        }

        updateInlineEditingVisibility()
    }

    private func updateOverlayHandleMetrics() {
        let displayedCanvasShortSide = min(canvasSize.width, canvasSize.height) * max(canvasScale, 0)
        let metrics = CanvasOverlayHandleLayoutMath.resolvedMetrics(
            layout: CanvasEditorUIRuntime.currentConfiguration.layout,
            displayedCanvasShortSide: displayedCanvasShortSide
        )

        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach {
            $0.updateMetrics(metrics)
        }
    }

    private func updateSelectionOverlay() {
        guard !isToolModeActive else {
            selectionOverlay.isHidden = true
            [deleteHandle, widthHandle, heightHandle, transformHandle].forEach { $0.isHidden = true }
            return
        }

        guard let store,
              let selectedNodeID = store.selectedNodeID,
              let selectedView = nodeViews[selectedNodeID],
              let selectedNode = store.selectedNode else {
            selectionOverlay.isHidden = true
            [deleteHandle, widthHandle, heightHandle, transformHandle].forEach { $0.isHidden = true }
            return
        }

        selectionOverlay.apply(node: selectedNode)
        let overlayInset = selectionOverlay.contentInset
        let maskedSelectionGeometry = selectedNode.kind == .maskedImage
            ? selectedView.maskedImageSelectionGeometry
            : nil
        let overlaySize = CGSize(
            width: (maskedSelectionGeometry?.size.width ?? selectedView.bounds.width) + (overlayInset * 2),
            height: (maskedSelectionGeometry?.size.height ?? selectedView.bounds.height) + (overlayInset * 2)
        )
        let selectedCenter: CGPoint = if let maskedSelectionGeometry {
            selectedView.convert(maskedSelectionGeometry.center, to: canvasContainerView)
        } else {
            selectedView.superview?.convert(selectedView.center, to: canvasContainerView) ?? selectedView.center
        }
        let overlayTransform: CGAffineTransform = if let maskedSelectionGeometry {
            CGAffineTransform(rotationAngle: maskedSelectionGeometry.rotation)
                .scaledBy(x: maskedSelectionGeometry.scale, y: maskedSelectionGeometry.scale)
                .concatenating(selectedView.transform)
        } else {
            selectedView.transform
        }

        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectionOverlay.bounds = CGRect(origin: .zero, size: overlaySize)
            selectionOverlay.center = selectedCenter
            selectionOverlay.transform = overlayTransform
            selectionOverlay.isHidden = false
            selectionOverlay.layer.removeAllAnimations()
            CATransaction.commit()
        }
        canvasContainerView.bringSubviewToFront(selectionOverlay)

        let selectionRect = selectionOverlay.selectionRect
        deleteHandle.center = selectionOverlay.convert(
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            to: overlayControlContainerView
        )
        widthHandle.center = selectionOverlay.convert(
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            to: overlayControlContainerView
        )
        heightHandle.center = selectionOverlay.convert(
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            to: overlayControlContainerView
        )
        transformHandle.center = selectionOverlay.convert(
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
            to: overlayControlContainerView
        )

        deleteHandle.isHidden = !store.canDeleteSelectedContent
        transformHandle.isHidden = false
        widthHandle.isHidden = selectedNode.kind != .text
        heightHandle.isHidden = selectedNode.kind != .text

        let handleRotation = CGAffineTransform(
            rotationAngle: CGFloat(selectedNode.transform.rotation) + (maskedSelectionGeometry?.rotation ?? 0)
        )
        [deleteHandle, widthHandle, heightHandle, transformHandle].forEach {
            $0.transform = handleRotation
            overlayControlContainerView.bringSubviewToFront($0)
        }
        bringSubviewToFront(overlayControlContainerView)
    }

    private func updateInlineTextEditor(forceTextRefresh: Bool = false) {
        guard let editingNodeID,
              let store,
              let node = store.project.nodes.first(where: { $0.id == editingNodeID }),
              node.kind == .text else {
            inlineTextView.isHidden = true
            activeEditingStyle = nil
            return
        }

        let style = node.style ?? .defaultText
        let targetSize = CGSize(
            width: max(node.size.width - (textContentInset * 2), 40),
            height: max(node.size.height - (textContentInset * 2), 30)
        )

        inlineTextView.bounds = CGRect(origin: .zero, size: targetSize)
        inlineTextView.center = node.transform.position.cgPoint
        inlineTextView.transform = CGAffineTransform(rotationAngle: node.transform.rotation)
            .scaledBy(x: node.transform.scale, y: node.transform.scale)
        inlineTextView.backgroundColor = style.resolvedBackgroundUIColor ?? .clear
        inlineTextView.layer.cornerRadius = style.backgroundFill == nil ? 0 : 16
        inlineTextView.tintColor = style.foregroundColor.uiColor
        inlineTextView.textAlignment = style.alignment.nsTextAlignment

        let currentSelection = inlineTextView.selectedRange
        let requiresTextRefresh = forceTextRefresh ||
            inlineTextView.text != (node.text ?? "") ||
            activeEditingStyle != style
        if requiresTextRefresh {
            isApplyingInlineEditorState = true
            inlineTextView.attributedText = style.attributedString(text: node.text ?? "")
            inlineTextView.typingAttributes = style.textAttributes()
            let clampedLocation = min(currentSelection.location, (inlineTextView.text as NSString).length)
            inlineTextView.selectedRange = NSRange(location: clampedLocation, length: 0)
            isApplyingInlineEditorState = false
            activeEditingStyle = style
        }

        inlineTextView.isHidden = false
        canvasContainerView.bringSubviewToFront(inlineTextView)
    }

    private func updateInlineEditingVisibility() {
        nodeViews.values.forEach { $0.isHidden = false }
        guard let editingNodeID else {
            inlineTextView.isHidden = true
            return
        }
        nodeViews[editingNodeID]?.isHidden = true
    }

    private func endInlineEditingWithoutResigning() {
        guard editingNodeID != nil else {
            return
        }
        editingNodeID = nil
        activeEditingStyle = nil
        inlineTextView.isHidden = true
        syncNodePresentation()
        refreshFilteredPreviewIfNeeded()
        delegate?.canvasStageViewDidEndInlineEditing(self)
    }

    private var effectiveCanvasFilter: CanvasFilterPreset {
        previewCanvasFilterOverride ?? store?.project.canvasFilter ?? .normal
    }

    private func refreshFilteredPreviewIfNeeded() {
        let activeFilter = effectiveCanvasFilter
        guard activeFilter.usesImageFiltering,
              let store,
              canvasSize.width > 0,
              canvasSize.height > 0 else {
            resetFilteredPreview()
            return
        }

        let project = store.project
        let excludedNodeIDs = editingNodeID.map { Set([$0]) } ?? []
        let renderScale = max(min(UIScreen.main.scale * canvasScale, UIScreen.main.scale), 0.25)
        let renderToken = UUID()
        filteredPreviewRenderToken = renderToken

        DispatchQueue.global(qos: .userInitiated).async { [assetLoader] in
            let baseImage = CanvasEditorRenderer.renderBaseImage(
                project: project,
                assetLoader: assetLoader,
                excludingNodeIDs: excludedNodeIDs,
                imageScale: renderScale
            )
            let filteredImage = CanvasEditorRenderer.applyFilter(activeFilter, to: baseImage)

            Task { @MainActor [weak self] in
                guard let self, self.filteredPreviewRenderToken == renderToken else {
                    return
                }
                self.filteredPreviewImageView.image = filteredImage
                self.filteredPreviewImageView.isHidden = false
                self.contentContainerView.alpha = 0
            }
        }
    }

    private func resetFilteredPreview() {
        filteredPreviewRenderToken = UUID()
        filteredPreviewImageView.image = nil
        filteredPreviewImageView.isHidden = true
        contentContainerView.alpha = 1
    }

    private func hitTestNode(at point: CGPoint) -> CanvasNode? {
        guard let store else {
            return nil
        }

        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        if !canvasBounds.contains(point) {
            guard let selectedNodeID = store.selectedNodeID,
                  let selectedNode = store.selectedNode,
                  selectedNode.id == selectedNodeID,
                  let selectedNodeView = nodeViews[selectedNodeID],
                  !selectedNodeView.isHidden else {
                return nil
            }

            let localPoint = selectedNodeView.convert(point, from: canvasContainerView)
            return selectedNodeView.point(inside: localPoint, with: nil) ? selectedNode : nil
        }

        for node in store.project.sortedNodes.reversed() {
            guard node.isEditable else {
                continue
            }
            guard let nodeView = nodeViews[node.id], !nodeView.isHidden else {
                continue
            }
            let localPoint = nodeView.convert(point, from: canvasContainerView)
            if nodeView.point(inside: localPoint, with: nil) {
                return node
            }
        }
        return nil
    }
}
#endif
