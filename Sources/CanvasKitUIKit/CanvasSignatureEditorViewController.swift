#if canImport(UIKit)
import UIKit
import CanvasKitCore

@MainActor
final class CanvasSignatureEditorViewController: UIViewController {
    private let signatureConfiguration: CanvasSignatureConfiguration
    private let fallbackPalette: [CanvasColor]
    private let assetLoader: CanvasAssetLoader
    private let signatureStore: CanvasSignatureStore
    private let onCancel: () -> Void
    private let onSave: (CanvasSignatureDescriptor) -> Void

    private let titleLabel = UILabel()
    private let canvasContainerView = UIView()
    private let drawingView = CanvasSignatureDrawingView()
    private let placeholderStackView = UIStackView()
    private let placeholderTitleLabel = UILabel()
    private let placeholderSubtitleLabel = UILabel()
    private let historyStackView = UIStackView()
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let bottomPanelView = UIView()
    private let colorStripView = CanvasSignatureColorStripView()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let loadingOverlayView = CanvasLoadingOverlayView()

    private var strokeHistory = CanvasHistory<[CanvasSignatureStroke]>()
    private var hasActiveStroke = false {
        didSet {
            updatePlaceholderVisibility()
        }
    }
    private var strokes: [CanvasSignatureStroke] = [] {
        didSet {
            drawingView.setStrokes(strokes)
            updateHistoryButtons()
            updateDoneButtonVisibility()
            updatePlaceholderVisibility()
        }
    }
    private var selectedColor: CanvasColor {
        didSet {
            drawingView.currentStrokeColor = selectedColor
            colorStripView.applySelection(color: selectedColor)
        }
    }
    private var selectedLineWidth: Double {
        didSet {
            drawingView.currentLineWidth = selectedLineWidth
        }
    }

    init(
        signatureConfiguration: CanvasSignatureConfiguration,
        fallbackPalette: [CanvasColor],
        assetLoader: CanvasAssetLoader,
        signatureStore: CanvasSignatureStore,
        onCancel: @escaping () -> Void,
        onSave: @escaping (CanvasSignatureDescriptor) -> Void
    ) {
        self.signatureConfiguration = signatureConfiguration
        self.fallbackPalette = fallbackPalette
        self.assetLoader = assetLoader
        self.signatureStore = signatureStore
        self.onCancel = onCancel
        self.onSave = onSave
        selectedColor = signatureConfiguration.defaultColor
        selectedLineWidth = signatureConfiguration.defaultLineWidth
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CanvasEditorTheme.sheetSurface
        setupLayout()
        configureInitialState()
    }

    private func setupLayout() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.signatureEditorTitle.uppercased()
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.sheetTitleFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.secondaryText
        titleLabel.textAlignment = .center

        canvasContainerView.translatesAutoresizingMaskIntoConstraints = false
        canvasContainerView.applyCanvasEditorCardStyle(
            backgroundColor: .white,
            cornerRadius: 22,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.surfaceShadow,
            shadowOpacity: 1,
            shadowRadius: 18,
            shadowOffset: CGSize(width: 0, height: 10)
        )

        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.backgroundColor = .clear
        canvasContainerView.addSubview(drawingView)

        placeholderStackView.translatesAutoresizingMaskIntoConstraints = false
        placeholderStackView.axis = .vertical
        placeholderStackView.spacing = 6
        placeholderStackView.alignment = .center
        canvasContainerView.addSubview(placeholderStackView)

        placeholderTitleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.signaturePlaceholderTitle
        placeholderTitleLabel.font = UIFont.systemFont(ofSize: 38, weight: .light)
        placeholderTitleLabel.textColor = CanvasEditorTheme.placeholderText

        placeholderSubtitleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.signaturePlaceholderSubtitle
        placeholderSubtitleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.bodyFont.resolvedUIFont()
        placeholderSubtitleLabel.textColor = CanvasEditorTheme.placeholderText

        [placeholderTitleLabel, placeholderSubtitleLabel].forEach(placeholderStackView.addArrangedSubview)

        historyStackView.translatesAutoresizingMaskIntoConstraints = false
        historyStackView.axis = .horizontal
        historyStackView.spacing = 18

        [undoButton, redoButton].forEach { button in
            button.widthAnchor.constraint(equalToConstant: 58).isActive = true
            button.heightAnchor.constraint(equalToConstant: 58).isActive = true
            historyStackView.addArrangedSubview(button)
        }

        bottomPanelView.translatesAutoresizingMaskIntoConstraints = false
        bottomPanelView.applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 30,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.surfaceShadow,
            shadowOpacity: 1,
            shadowRadius: 20,
            shadowOffset: CGSize(width: 0, height: -8)
        )

        colorStripView.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.configuration = .plain()
        cancelButton.configuration?.title = CanvasEditorUIRuntime.currentConfiguration.strings.signatureCancelButtonTitle
        cancelButton.configuration?.baseForegroundColor = CanvasEditorTheme.primaryText
        cancelButton.titleLabel?.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.configuration = .plain()
        doneButton.configuration?.title = CanvasEditorUIRuntime.currentConfiguration.strings.signatureDoneButtonTitle
        doneButton.configuration?.baseForegroundColor = CanvasEditorTheme.primaryText
        doneButton.titleLabel?.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        loadingOverlayView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(canvasContainerView)
        view.addSubview(historyStackView)
        view.addSubview(bottomPanelView)
        view.addSubview(loadingOverlayView)

        [colorStripView, cancelButton, doneButton].forEach(bottomPanelView.addSubview)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            canvasContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            canvasContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            canvasContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            canvasContainerView.bottomAnchor.constraint(equalTo: historyStackView.topAnchor, constant: -28),

            drawingView.leadingAnchor.constraint(equalTo: canvasContainerView.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: canvasContainerView.trailingAnchor),
            drawingView.topAnchor.constraint(equalTo: canvasContainerView.topAnchor),
            drawingView.bottomAnchor.constraint(equalTo: canvasContainerView.bottomAnchor),

            placeholderStackView.centerXAnchor.constraint(equalTo: canvasContainerView.centerXAnchor),
            placeholderStackView.centerYAnchor.constraint(equalTo: canvasContainerView.centerYAnchor),
            placeholderStackView.leadingAnchor.constraint(greaterThanOrEqualTo: canvasContainerView.leadingAnchor, constant: 24),
            placeholderStackView.trailingAnchor.constraint(lessThanOrEqualTo: canvasContainerView.trailingAnchor, constant: -24),

            historyStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            historyStackView.bottomAnchor.constraint(equalTo: bottomPanelView.topAnchor, constant: -20),

            bottomPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            colorStripView.leadingAnchor.constraint(equalTo: bottomPanelView.leadingAnchor, constant: 24),
            colorStripView.trailingAnchor.constraint(equalTo: bottomPanelView.trailingAnchor, constant: -24),
            colorStripView.topAnchor.constraint(equalTo: bottomPanelView.topAnchor, constant: 18),
            colorStripView.heightAnchor.constraint(equalToConstant: 52),

            cancelButton.leadingAnchor.constraint(equalTo: bottomPanelView.leadingAnchor, constant: 36),
            cancelButton.topAnchor.constraint(equalTo: colorStripView.bottomAnchor, constant: 18),
            cancelButton.bottomAnchor.constraint(equalTo: bottomPanelView.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            doneButton.trailingAnchor.constraint(equalTo: bottomPanelView.trailingAnchor, constant: -36),
            doneButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),

            loadingOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        configureHistoryButton(
            undoButton,
            title: CanvasEditorUIRuntime.currentConfiguration.strings.undoButtonTitle,
            systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.undo
        )
        configureHistoryButton(
            redoButton,
            title: CanvasEditorUIRuntime.currentConfiguration.strings.redoButtonTitle,
            systemImage: CanvasEditorUIRuntime.currentConfiguration.icons.redo
        )
    }

    private func configureInitialState() {
        colorStripView.onSelectColor = { [weak self] color in
            self?.selectedColor = color
        }
        colorStripView.configure(palette: resolvedPalette())
        colorStripView.applySelection(color: selectedColor)

        drawingView.currentStrokeColor = selectedColor
        drawingView.currentLineWidth = selectedLineWidth
        drawingView.onDrawingStateChange = { [weak self] isDrawing in
            self?.hasActiveStroke = isDrawing
        }
        drawingView.onCommitStroke = { [weak self] stroke in
            guard let self else { return }
            self.strokeHistory.record(currentValue: self.strokes)
            self.strokes.append(stroke)
        }

        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)

        updateHistoryButtons()
        updateDoneButtonVisibility()
    }

    private func resolvedPalette() -> [CanvasColor] {
        let basePalette = signatureConfiguration.palette ?? fallbackPalette
        var resolved = [CanvasColor.black]

        basePalette.forEach { color in
            if !resolved.contains(color) {
                resolved.append(color)
            }
        }

        if !resolved.contains(signatureConfiguration.defaultColor) {
            resolved.insert(signatureConfiguration.defaultColor, at: 0)
        }

        return resolved
    }

    private func updateHistoryButtons() {
        undoButton.isEnabled = strokeHistory.canUndo
        redoButton.isEnabled = strokeHistory.canRedo
    }

    private func updateDoneButtonVisibility() {
        doneButton.isHidden = strokes.isEmpty
    }

    private func updatePlaceholderVisibility() {
        placeholderStackView.isHidden = !strokes.isEmpty || hasActiveStroke
    }

    private func configureHistoryButton(_ button: UIButton, title: String, systemImage: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImage)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        configuration.background.backgroundColor = CanvasEditorTheme.cardSurface
        configuration.background.cornerRadius = 18
        button.configuration = configuration
        button.accessibilityLabel = title
        button.applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 18,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.controlShadow,
            shadowOpacity: 1,
            shadowRadius: 18,
            shadowOffset: CGSize(width: 0, height: 10)
        )
        button.configurationUpdateHandler = { button in
            guard var updatedConfiguration = button.configuration else {
                return
            }
            updatedConfiguration.baseForegroundColor = button.isEnabled
                ? CanvasEditorTheme.primaryText
                : CanvasEditorTheme.secondaryText
            updatedConfiguration.background.backgroundColor = CanvasEditorTheme.cardSurface
            button.configuration = updatedConfiguration
            button.alpha = button.isEnabled ? 1 : 0.45
        }
    }

    @objc
    private func undoTapped() {
        guard let previous = strokeHistory.undo(currentValue: strokes) else {
            return
        }
        strokes = previous
    }

    @objc
    private func redoTapped() {
        guard let next = strokeHistory.redo(currentValue: strokes) else {
            return
        }
        strokes = next
    }

    @objc
    private func cancelTapped() {
        dismiss(animated: true) { [onCancel] in
            onCancel()
        }
    }

    @objc
    private func doneTapped() {
        guard !strokes.isEmpty else {
            return
        }
        guard let image = renderSignatureImage(),
              let source = assetLoader.inlineSource(from: image) else {
            presentErrorAlert(message: CanvasEditorUIRuntime.currentConfiguration.strings.saveSignatureFailureMessage)
            return
        }

        setLoadingState(isLoading: true)
        let draft = CanvasSignatureDescriptor(
            id: UUID().uuidString,
            name: generatedSignatureName(),
            source: source
        )

        Task { [weak self] in
            guard let self else { return }

            do {
                let savedSignature = try await signatureStore.saveSignature(draft)
                self.setLoadingState(isLoading: false)
                self.dismiss(animated: true) { [onSave] in
                    onSave(savedSignature)
                }
            } catch {
                self.setLoadingState(isLoading: false)
                self.presentErrorAlert(message: CanvasEditorUIRuntime.currentConfiguration.strings.saveSignatureFailureMessage)
            }
        }
    }

    private func setLoadingState(isLoading: Bool) {
        view.isUserInteractionEnabled = !isLoading
        if isLoading {
            loadingOverlayView.show(
                message: CanvasEditorUIRuntime.currentConfiguration.strings.savingSignatureMessage,
                animated: true
            )
        } else {
            loadingOverlayView.hide(animated: true)
            view.isUserInteractionEnabled = true
        }
    }

    private func presentErrorAlert(message: String) {
        let alert = UIAlertController(
            title: CanvasEditorUIRuntime.currentConfiguration.strings.errorAlertTitle,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: CanvasEditorUIRuntime.currentConfiguration.strings.okButtonTitle,
            style: .default
        ))
        present(alert, animated: true)
    }

    private func generatedSignatureName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Signature \(formatter.string(from: Date()))"
    }

    private func renderSignatureImage() -> UIImage? {
        guard let bounds = renderedStrokeBounds() else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            for stroke in strokes {
                cgContext.setStrokeColor(stroke.color.uiColor.cgColor)
                cgContext.setLineWidth(stroke.lineWidth)
                cgContext.addPath(CanvasSignaturePathBuilder.makePath(points: stroke.points))
                cgContext.strokePath()
            }
        }
    }

    private func renderedStrokeBounds() -> CGRect? {
        guard !strokes.isEmpty else {
            return nil
        }

        let rawBounds = strokes.reduce(into: CGRect.null) { partialResult, stroke in
            let path = CanvasSignaturePathBuilder.makePath(points: stroke.points)
            let strokedPath = path.copy(
                strokingWithWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            partialResult = partialResult.union(strokedPath.boundingBoxOfPath)
        }

        guard !rawBounds.isNull else {
            return nil
        }

        let padding = max(strokes.map(\.lineWidth).max() ?? 0, 8) + 8
        let paddedBounds = rawBounds.insetBy(dx: -padding, dy: -padding)
        return CGRect(
            x: floor(paddedBounds.minX),
            y: floor(paddedBounds.minY),
            width: ceil(paddedBounds.width),
            height: ceil(paddedBounds.height)
        )
    }
}

private struct CanvasSignatureStroke {
    var points: [CGPoint]
    var color: CanvasColor
    var lineWidth: CGFloat
}

private enum CanvasSignaturePathBuilder {
    static func makePath(points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else {
            return path
        }

        path.move(to: first)

        switch points.count {
        case 1:
            path.addLine(to: first)
        case 2:
            path.addLine(to: points[1])
        default:
            for index in 1..<(points.count - 1) {
                let current = points[index]
                let next = points[index + 1]
                path.addQuadCurve(to: midpoint(from: current, to: next), control: current)
            }

            path.addQuadCurve(
                to: points[points.count - 1],
                control: points[points.count - 2]
            )
        }

        return path
    }

    private static func midpoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
    }
}

private final class CanvasSignatureDrawingView: UIView {
    var currentStrokeColor: CanvasColor = .black
    var currentLineWidth: Double = 4
    var onDrawingStateChange: ((Bool) -> Void)?
    var onCommitStroke: ((CanvasSignatureStroke) -> Void)?

    private var strokes: [CanvasSignatureStroke] = []
    private var activePoints: [CGPoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStrokes(_ strokes: [CanvasSignatureStroke]) {
        self.strokes = strokes
        activePoints.removeAll()
        onDrawingStateChange?(false)
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }
        activePoints = [point]
        onDrawingStateChange?(true)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }
        activePoints.append(point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }
        activePoints.append(point)
        commitActiveStrokeIfNeeded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activePoints.removeAll()
        onDrawingStateChange?(false)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        for stroke in strokes {
            drawStroke(stroke)
        }

        guard !activePoints.isEmpty else {
            return
        }

        drawStroke(
            CanvasSignatureStroke(
                points: normalizedPoints(activePoints),
                color: currentStrokeColor,
                lineWidth: CGFloat(currentLineWidth)
            )
        )
    }

    private func commitActiveStrokeIfNeeded() {
        let normalized = normalizedPoints(activePoints)
        guard !normalized.isEmpty else {
            return
        }

        onCommitStroke?(
            CanvasSignatureStroke(
                points: normalized,
                color: currentStrokeColor,
                lineWidth: CGFloat(currentLineWidth)
            )
        )
        activePoints.removeAll()
        onDrawingStateChange?(false)
        setNeedsDisplay()
    }

    private func normalizedPoints(_ points: [CGPoint]) -> [CGPoint] {
        guard let first = points.first else {
            return []
        }
        if points.count == 1 {
            return [first, first]
        }
        return points
    }

    private func drawStroke(_ stroke: CanvasSignatureStroke) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(stroke.color.uiColor.cgColor)
        context.setLineWidth(stroke.lineWidth)
        context.addPath(CanvasSignaturePathBuilder.makePath(points: stroke.points))
        context.strokePath()
        context.restoreGState()
    }
}

private final class CanvasSignatureColorStripView: UIView {
    var onSelectColor: ((CanvasColor) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var paletteButtons: [CanvasColor: InspectorColorChipButton] = [:]
    private var palette: [CanvasColor] = []
    private var selectedColor: CanvasColor = .black

    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(palette: [CanvasColor]) {
        self.palette = palette
        rebuildButtons()
        applySelection(color: selectedColor)
    }

    func applySelection(color: CanvasColor) {
        selectedColor = color
        for (paletteColor, button) in paletteButtons {
            button.isSelected = paletteColor == color
        }
    }

    private func rebuildButtons() {
        paletteButtons.removeAll()
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        palette.forEach { color in
            let button = InspectorColorChipButton()
            button.configure(kind: .color(color.uiColor))
            button.addAction(UIAction { [weak self] _ in
                self?.applySelection(color: color)
                self?.onSelectColor?(color)
            }, for: .touchUpInside)
            paletteButtons[color] = button
            stackView.addArrangedSubview(button)
        }
    }
}
#endif
