#if canImport(UIKit)
import PhotosUI
import UIKit
import CanvasKitCore

public protocol CanvasEditorViewControllerDelegate: AnyObject {
    func canvasEditorViewControllerDidCancel(_ viewController: CanvasEditorViewController)
    func canvasEditorViewController(
        _ viewController: CanvasEditorViewController,
        didExport result: CanvasEditorResult,
        previewImage: UIImage
    )
}

@MainActor
private enum CanvasEditorLoadingState {
    case none
    case importingImage
    case exportingImage
    case loadingSignatures
    case savingSignature

    var message: String {
        let strings = CanvasEditorUIRuntime.currentConfiguration.strings
        switch self {
        case .none:
            return ""
        case .importingImage:
            return strings.importingImageMessage
        case .exportingImage:
            return strings.exportingImageMessage
        case .loadingSignatures:
            return strings.loadingSignaturesMessage
        case .savingSignature:
            return strings.savingSignatureMessage
        }
    }
}

private enum CanvasEditorOperationError: Error, Sendable {
    case pngEncodingFailed
    case exportPreparationFailed
}

private enum BrushInspectorMode: Equatable {
    case create
    case edit
}

private enum ToolInspectorMode: Equatable {
    case brush(BrushInspectorMode)
    case eraser
}

private enum VisibleInspectorKind {
    case none
    case text
    case brush
    case eraser
}

private enum PhotoImportTarget: Equatable, Sendable {
    case addImageNode
    case maskedNode(String)
}

private struct ToolbarToolDescriptor {
    let tool: CanvasEditorTool
    let button: UIButton
    let action: Selector
    let requiresSignatureStore: Bool
}

@MainActor
public final class CanvasEditorViewController: UIViewController, CanvasTextInspectorViewDelegate, CanvasBrushInspectorViewDelegate, CanvasEraserInspectorViewDelegate, PHPickerViewControllerDelegate, UIColorPickerViewControllerDelegate, CanvasStageViewDelegate, CanvasLayerPanelViewDelegate {
    public weak var delegate: CanvasEditorViewControllerDelegate?

    public let store: CanvasEditorStore

    private let stageView: CanvasStageView
    private let bottomPanel = UIView()
    private let historyActionsContainer = UIView()
    private let historyActionsStack = UIStackView()
    private let toolbarScrollView = UIScrollView()
    private let toolbarContentStack = UIStackView()
    private let panelScrimView = UIControl()
    private let inspectorContainerView = UIView()
    private let textInspectorView: CanvasTextInspectorView
    private let brushInspectorView: CanvasBrushInspectorView
    private let eraserInspectorView: CanvasEraserInspectorView
    private let loadingOverlayView: CanvasLoadingOverlayView
    private let layerPanelView: CanvasLayerPanelView

    private var theme: CanvasEditorTheme { store.configuration.theme }
    private var icons: CanvasEditorIconSet { store.configuration.icons }
    private var strings: CanvasEditorStrings { store.configuration.strings }
    private var layout: CanvasEditorLayout { store.configuration.layout }
    private var toolbarTileHeight: CGFloat { CGFloat(layout.toolbarTileHeight) }
    private var toolbarTileMinimumWidth: CGFloat { max(72, toolbarTileHeight - 10) }
    private var historyButtonSize: CGFloat { CGFloat(layout.historyButtonSize) }
    private var canvasToHistorySpacing: CGFloat { CGFloat(layout.canvasToHistorySpacing) }
    private var historyToBottomPanelSpacing: CGFloat { CGFloat(layout.historyToBottomPanelSpacing) }
    private var inspectorMaximumHeight: CGFloat { CGFloat(layout.inspectorMaximumHeight) }
    private var inspectorMinimumTopMargin: CGFloat { CGFloat(layout.inspectorMinimumTopMargin) }
    private var inspectorVisibleOffset: CGFloat { CGFloat(layout.inspectorVisibleOffset) }
    private var inspectorBottomConstraint: NSLayoutConstraint?
    private var inspectorHeightConstraint: NSLayoutConstraint?
    private var layerPanelHeightConstraint: NSLayoutConstraint?
    private var isInspectorVisible = false
    private var isInspectorRequested = false
    private var toolInspectorMode: ToolInspectorMode?
    private var isInlineEditingText = false
    private var isLayerPanelVisible = false
    private var lastSelectedNodeID: String?
    private var hasObservedInitialProject = false
    private var hasCanvasChanges = false
    private var loadingState: CanvasEditorLoadingState = .none
    private var currentVisibleInspectorKind: VisibleInspectorKind = .none
    private var activeTextColorPickerTarget: CanvasTextInspectorColorTarget?
    private var committedBrushConfiguration = CanvasBrushConfiguration.defaultValue {
        didSet {
            guard isViewLoaded else {
                return
            }
            updateBrushButtonAppearance()
        }
    }
    private var brushDraftConfiguration: CanvasBrushConfiguration?
    private var eraserDraftStrokeWidth: Double?
    private var eraserStrokeWidth: Double = 24
    private var isBrushModeEnabled = false
    private var isEraserModeEnabled = false
    private var filterDraftPreset: CanvasFilterPreset?
    private var pendingPhotoImportTarget: PhotoImportTarget?

    private var projectObserverID: UUID?
    private var selectionObserverID: UUID?

    private lazy var addTextButton = makeGridToolButton(
        title: strings.addTextToolTitle,
        systemImage: icons.addTextTool
    )
    private lazy var addEmojiButton = makeGridToolButton(
        title: strings.addEmojiToolTitle,
        systemImage: icons.addEmojiTool
    )
    private lazy var addStickerButton = makeGridToolButton(
        title: strings.addStickerToolTitle,
        systemImage: icons.addStickerTool
    )
    private lazy var addPhotoButton = makeGridToolButton(
        title: strings.addPhotoToolTitle,
        systemImage: icons.addPhotoTool
    )
    private lazy var filterButton = makeGridToolButton(
        title: strings.filterToolTitle,
        systemImage: icons.filterTool
    )
    private lazy var addSignatureButton = makeGridToolButton(
        title: strings.addSignatureToolTitle,
        systemImage: icons.addSignatureTool
    )
    private lazy var eraserButton = makeGridToolButton(
        title: strings.eraserToolTitle,
        systemImage: icons.eraserTool
    )
    private lazy var addBrushButton = makeGridToolButton(
        title: strings.brushToolTitle,
        systemImage: icons.brushTool
    )
    private lazy var duplicateButton = makeGridToolButton(
        title: strings.duplicateToolTitle,
        systemImage: icons.duplicateTool
    )
    private lazy var deleteButton = makeGridToolButton(
        title: strings.deleteToolTitle,
        systemImage: icons.deleteTool
    )
    private lazy var undoButton = makeHistoryButton(
        title: strings.undoButtonTitle,
        systemImage: icons.undo
    )
    private lazy var redoButton = makeHistoryButton(
        title: strings.redoButtonTitle,
        systemImage: icons.redo
    )
    private lazy var layersButton = makeHistoryButton(
        title: strings.layersButtonTitle,
        systemImage: icons.layers
    )
    private lazy var exportBarButtonItem: UIBarButtonItem = {
        let style: UIBarButtonItem.Style
        if #available(iOS 26.0, *) {
            style = .prominent
        } else {
            style = .plain
        }

        return UIBarButtonItem(
            title: strings.exportButtonTitle,
            style: style,
            target: self,
            action: #selector(exportTapped)
        )
    }()

    private var signatureStore: CanvasSignatureStore? {
        store.configuration.signatures.store
    }

    public init(input: CanvasEditorInput, configuration: CanvasEditorConfiguration = .default) {
        let resolvedStore: CanvasEditorStore
        let resolvedTitle: String

        switch input {
        case .template(let template):
            resolvedStore = CanvasEditorStore(template: template, configuration: configuration)
            resolvedTitle = template.name
        case .project(let project):
            resolvedStore = CanvasEditorStore(project: project, configuration: configuration)
            resolvedTitle = configuration.strings.resumeProjectTitle
        }

        CanvasEditorUIRuntime.currentConfiguration = configuration
        store = resolvedStore
        stageView = CanvasStageView()
        textInspectorView = CanvasTextInspectorView()
        brushInspectorView = CanvasBrushInspectorView()
        eraserInspectorView = CanvasEraserInspectorView()
        loadingOverlayView = CanvasLoadingOverlayView()
        layerPanelView = CanvasLayerPanelView()
        super.init(nibName: nil, bundle: nil)
        title = resolvedTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(self)
        if let projectObserverID {
            store.removeObserver(projectObserverID)
        }
        if let selectionObserverID {
            store.removeObserver(selectionObserverID)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        CanvasEditorFontRegistrar.registerFonts(from: store.configuration)
        view.backgroundColor = theme.canvasBackdrop

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: strings.closeButtonTitle,
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = exportBarButtonItem

        stageView.store = store
        stageView.delegate = self
        textInspectorView.delegate = self
        textInspectorView.configure(fontFamilies: store.configuration.fontCatalog, palette: store.configuration.colorPalette)
        brushInspectorView.delegate = self
        brushInspectorView.configure(palette: store.configuration.colorPalette)
        eraserInspectorView.delegate = self
        layerPanelView.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        setupLayout()
        setupToolbar()
        bindStore()
        updateBrushButtonAppearance()
        updateEraserButtonAppearance()
        updateInspectorMetrics()
        refreshChrome()
    }

    private func setupLayout() {
        [stageView, bottomPanel, historyActionsContainer, layersButton, panelScrimView, inspectorContainerView, layerPanelView, loadingOverlayView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        bottomPanel.backgroundColor = CanvasEditorTheme.cardSurface
        bottomPanel.layer.cornerRadius = 30
        bottomPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomPanel.layer.cornerCurve = .continuous
        bottomPanel.layer.shadowColor = CanvasEditorTheme.surfaceShadow.cgColor
        bottomPanel.layer.shadowOpacity = 1
        bottomPanel.layer.shadowRadius = 22
        bottomPanel.layer.shadowOffset = CGSize(width: 0, height: -10)

        historyActionsStack.translatesAutoresizingMaskIntoConstraints = false
        historyActionsStack.axis = .horizontal
        historyActionsStack.spacing = 12
        historyActionsContainer.addSubview(historyActionsStack)

        inspectorContainerView.backgroundColor = .clear
        inspectorContainerView.alpha = 0

        panelScrimView.backgroundColor = .clear
        panelScrimView.alpha = 0
        panelScrimView.isHidden = true
        panelScrimView.addTarget(self, action: #selector(panelScrimTapped), for: .touchUpInside)

        layerPanelView.alpha = 0
        layerPanelView.isHidden = true
        layerPanelView.transform = layerPanelHiddenTransform
        layerPanelView.isUserInteractionEnabled = false

        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.showsHorizontalScrollIndicator = false
        toolbarScrollView.showsVerticalScrollIndicator = false
        toolbarScrollView.alwaysBounceHorizontal = true
        toolbarScrollView.alwaysBounceVertical = false
        toolbarScrollView.isDirectionalLockEnabled = true
        bottomPanel.addSubview(toolbarScrollView)

        toolbarContentStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarContentStack.axis = .horizontal
        toolbarContentStack.spacing = 10
        toolbarContentStack.alignment = .fill
        toolbarScrollView.addSubview(toolbarContentStack)

        textInspectorView.translatesAutoresizingMaskIntoConstraints = false
        brushInspectorView.translatesAutoresizingMaskIntoConstraints = false
        eraserInspectorView.translatesAutoresizingMaskIntoConstraints = false
        brushInspectorView.isHidden = true
        eraserInspectorView.isHidden = true
        inspectorContainerView.addSubview(textInspectorView)
        inspectorContainerView.addSubview(brushInspectorView)
        inspectorContainerView.addSubview(eraserInspectorView)

        inspectorBottomConstraint = inspectorContainerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: inspectorMaximumHeight + 40
        )
        inspectorHeightConstraint = inspectorContainerView.heightAnchor.constraint(equalToConstant: inspectorMaximumHeight + view.safeAreaInsets.bottom)
        layerPanelHeightConstraint = layerPanelView.heightAnchor.constraint(equalToConstant: 180)
        inspectorBottomConstraint?.isActive = true
        inspectorHeightConstraint?.isActive = true
        layerPanelHeightConstraint?.isActive = true

        inspectorContainerView.layer.shadowColor = CanvasEditorTheme.surfaceShadow.cgColor
        inspectorContainerView.layer.shadowOpacity = 1
        inspectorContainerView.layer.shadowRadius = 24
        inspectorContainerView.layer.shadowOffset = CGSize(width: 0, height: -10)

        NSLayoutConstraint.activate([
            stageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stageView.bottomAnchor.constraint(equalTo: historyActionsContainer.topAnchor, constant: -canvasToHistorySpacing),

            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            historyActionsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            historyActionsContainer.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -historyToBottomPanelSpacing),

            historyActionsStack.leadingAnchor.constraint(equalTo: historyActionsContainer.leadingAnchor),
            historyActionsStack.trailingAnchor.constraint(equalTo: historyActionsContainer.trailingAnchor),
            historyActionsStack.topAnchor.constraint(equalTo: historyActionsContainer.topAnchor),
            historyActionsStack.bottomAnchor.constraint(equalTo: historyActionsContainer.bottomAnchor),

            layersButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            layersButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            layersButton.widthAnchor.constraint(equalToConstant: historyButtonSize),
            layersButton.heightAnchor.constraint(equalToConstant: historyButtonSize),

            toolbarScrollView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 18),
            toolbarScrollView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -18),
            toolbarScrollView.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 20),
            toolbarScrollView.bottomAnchor.constraint(equalTo: bottomPanel.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            toolbarScrollView.heightAnchor.constraint(equalToConstant: toolbarTileHeight),

            toolbarContentStack.leadingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.leadingAnchor),
            toolbarContentStack.trailingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.trailingAnchor),
            toolbarContentStack.topAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.topAnchor),
            toolbarContentStack.bottomAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.bottomAnchor),
            toolbarContentStack.heightAnchor.constraint(equalTo: toolbarScrollView.frameLayoutGuide.heightAnchor),

            inspectorContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inspectorContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            textInspectorView.leadingAnchor.constraint(equalTo: inspectorContainerView.leadingAnchor),
            textInspectorView.trailingAnchor.constraint(equalTo: inspectorContainerView.trailingAnchor),
            textInspectorView.topAnchor.constraint(equalTo: inspectorContainerView.topAnchor),
            textInspectorView.bottomAnchor.constraint(equalTo: inspectorContainerView.bottomAnchor),

            brushInspectorView.leadingAnchor.constraint(equalTo: inspectorContainerView.leadingAnchor),
            brushInspectorView.trailingAnchor.constraint(equalTo: inspectorContainerView.trailingAnchor),
            brushInspectorView.topAnchor.constraint(equalTo: inspectorContainerView.topAnchor),
            brushInspectorView.bottomAnchor.constraint(equalTo: inspectorContainerView.bottomAnchor),

            eraserInspectorView.leadingAnchor.constraint(equalTo: inspectorContainerView.leadingAnchor),
            eraserInspectorView.trailingAnchor.constraint(equalTo: inspectorContainerView.trailingAnchor),
            eraserInspectorView.topAnchor.constraint(equalTo: inspectorContainerView.topAnchor),
            eraserInspectorView.bottomAnchor.constraint(equalTo: inspectorContainerView.bottomAnchor),

            panelScrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelScrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelScrimView.topAnchor.constraint(equalTo: view.topAnchor),
            panelScrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            layerPanelView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            layerPanelView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            layerPanelView.widthAnchor.constraint(equalToConstant: 232),

            loadingOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupToolbar() {
        let visibleToolDescriptors = toolbarToolDescriptors().filter { descriptor in
            store.configuration.enabledTools.contains(descriptor.tool)
                && (!descriptor.requiresSignatureStore || signatureStore != nil)
                && (descriptor.tool != .filter || CanvasFilterProcessor.isAvailable)
        }

        visibleToolDescriptors.forEach { descriptor in
            descriptor.button.addTarget(self, action: descriptor.action, for: .touchUpInside)
        }

        let historyButtons: [(UIButton, Selector)] = [
            (undoButton, #selector(undoTapped)),
            (redoButton, #selector(redoTapped))
        ]

        historyButtons.forEach { button, action in
            button.addTarget(self, action: action, for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: historyButtonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: historyButtonSize).isActive = true
            historyActionsStack.addArrangedSubview(button)
        }
        exportBarButtonItem.isEnabled = store.configuration.enabledTools.contains(.export)
        layersButton.addTarget(self, action: #selector(layersTapped), for: .touchUpInside)

        visibleToolDescriptors.map(\.button).forEach { button in
            toolbarContentStack.addArrangedSubview(button)
        }
    }

    private func bindStore() {
        projectObserverID = store.observeProject { [weak self] _ in
            guard let self else { return }
            if self.hasObservedInitialProject {
                self.hasCanvasChanges = true
            } else {
                self.hasObservedInitialProject = true
            }
            self.refreshChrome()
        }
        selectionObserverID = store.observeSelection { [weak self] selectedNodeID in
            guard let self else { return }
            if selectedNodeID != self.lastSelectedNodeID {
                self.isInspectorRequested = false
                if self.toolInspectorMode == .brush(.edit) {
                    self.toolInspectorMode = nil
                }
            }
            if selectedNodeID == nil {
                self.isInlineEditingText = false
            }
            self.lastSelectedNodeID = selectedNodeID
            self.refreshChrome()
        }
    }

    private func refreshChrome() {
        layerPanelView.apply(nodes: store.layerPanelNodes, selectedNodeID: store.selectedNodeID)
        updateLayerPanelHeight()

        let hasSelection = store.selectedNode != nil
        duplicateButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
        undoButton.isEnabled = store.canUndo
        redoButton.isEnabled = store.canRedo
        updateBrushButtonAppearance()
        updateLayerButtonAppearance()
        updateEraserButtonAppearance()
        updateVisibleInspector(animated: true)
    }

    private var shouldShowPanelScrim: Bool {
        isInspectorVisible || isLayerPanelVisible
    }

    private func prepareForPanelPresentation(_ overlayView: UIView) {
        panelScrimView.isHidden = false
        view.bringSubviewToFront(panelScrimView)
        view.bringSubviewToFront(overlayView)
        view.bringSubviewToFront(loadingOverlayView)
    }

    private func updatePanelScrimVisibility() {
        panelScrimView.alpha = shouldShowPanelScrim ? 1 : 0
        panelScrimView.backgroundColor = shouldShowPanelScrim ? CanvasEditorTheme.scrim : .clear
    }

    private func finalizePanelScrimIfNeeded() {
        panelScrimView.isHidden = !shouldShowPanelScrim
    }

    private func setInspectorVisible(_ visible: Bool, animated: Bool) {
        if visible {
            prepareForPanelPresentation(inspectorContainerView)
        }

        isInspectorVisible = visible
        updateInspectorMetrics()
        let changes = {
            self.inspectorContainerView.alpha = visible ? 1 : 0
            self.updatePanelScrimVisibility()
            self.view.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            self.finalizePanelScrimIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.24, animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateInspectorMetrics()
        updateLayerPanelHeight()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateInspectorMetrics()
        updateLayerPanelHeight()
    }

    private func updateInspectorMetrics() {
        let totalHeight = currentInspectorHeight()
        inspectorHeightConstraint?.constant = totalHeight
        inspectorBottomConstraint?.constant = isInspectorVisible ? inspectorVisibleOffset : totalHeight + 20
    }

    private func currentInspectorHeight() -> CGFloat {
        let maximumContentHeight = min(
            inspectorMaximumHeight,
            max(view.bounds.height - view.safeAreaInsets.top - inspectorMinimumTopMargin - view.safeAreaInsets.bottom, 0)
        )

        let contentHeight: CGFloat
        switch currentVisibleInspectorKind {
        case .text:
            contentHeight = textInspectorView.preferredHeight(for: view.bounds.width, maximumHeight: maximumContentHeight)
        case .brush:
            contentHeight = brushInspectorView.preferredHeight(for: view.bounds.width, maximumHeight: maximumContentHeight)
        case .eraser:
            contentHeight = eraserInspectorView.preferredHeight(for: view.bounds.width, maximumHeight: maximumContentHeight)
        case .none:
            contentHeight = maximumContentHeight
        }

        return contentHeight + view.safeAreaInsets.bottom
    }

    private func setLoadingState(_ state: CanvasEditorLoadingState, animated: Bool = true) {
        loadingState = state
        let isBusy = state != .none
        stageView.isUserInteractionEnabled = !isBusy
        bottomPanel.isUserInteractionEnabled = !isBusy
        historyActionsContainer.isUserInteractionEnabled = !isBusy
        inspectorContainerView.isUserInteractionEnabled = !isBusy
        navigationItem.leftBarButtonItem?.isEnabled = !isBusy
        exportBarButtonItem.isEnabled = !isBusy && store.configuration.enabledTools.contains(.export)
        layersButton.isEnabled = !isBusy
        layerPanelView.isUserInteractionEnabled = !isBusy && isLayerPanelVisible

        if isBusy {
            setLayerPanelVisible(false, animated: animated)
            cancelActiveToolMode()
        }

        if isBusy {
            loadingOverlayView.show(message: state.message, animated: animated)
        } else {
            loadingOverlayView.hide(animated: animated)
            refreshChrome()
        }
    }

    private static func encodeProjectData(for project: CanvasProject, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(project)
    }

    @objc
    private func handleKeyboardWillShow(_ notification: Notification) {
        guard isInlineEditingText || isInspectorVisible else {
            return
        }
        isInspectorRequested = false
        toolInspectorMode = nil
        brushDraftConfiguration = nil
        eraserDraftStrokeWidth = nil
        updateVisibleInspector(animated: true)
    }

    private func updateLayerPanelHeight() {
        let maximumHeight = min(max(view.bounds.height - view.safeAreaInsets.top - 44, 220), 420)
        layerPanelHeightConstraint?.constant = layerPanelView.preferredHeight(maximumHeight: maximumHeight)
    }

    private func resolvedVisibleInspectorKind() -> VisibleInspectorKind {
        guard !isInlineEditingText else {
            return .none
        }

        if let toolInspectorMode {
            switch toolInspectorMode {
            case .brush(let brushInspectorMode):
                switch brushInspectorMode {
                case .create:
                    return .brush
                case .edit:
                    guard let node = store.selectedNode,
                          node.kind == .shape,
                          node.shape != nil else {
                        self.toolInspectorMode = nil
                        return .none
                    }
                    return .brush
                }
            case .eraser:
                return .eraser
            }
        }

        guard let node = store.selectedNode, node.kind == .text || node.kind == .emoji else {
            isInspectorRequested = false
            return .none
        }

        textInspectorView.apply(node: node)
        return isInspectorRequested ? .text : .none
    }

    private func updateVisibleInspector(animated: Bool) {
        let visibleInspectorKind = resolvedVisibleInspectorKind()
        currentVisibleInspectorKind = visibleInspectorKind
        textInspectorView.isHidden = visibleInspectorKind != .text
        brushInspectorView.isHidden = visibleInspectorKind != .brush
        eraserInspectorView.isHidden = visibleInspectorKind != .eraser
        setInspectorVisible(visibleInspectorKind != .none, animated: animated)
    }

    private func updateLayerButtonAppearance() {
        layersButton.isSelected = isLayerPanelVisible
        layersButton.setNeedsUpdateConfiguration()
    }

    private func setLayerPanelVisible(_ visible: Bool, animated: Bool) {
        guard isLayerPanelVisible != visible || layerPanelView.isHidden != !visible else {
            return
        }

        isLayerPanelVisible = visible
        updateLayerButtonAppearance()

        if visible {
            prepareForPanelPresentation(layerPanelView)
            layerPanelView.isHidden = false
            layerPanelView.isUserInteractionEnabled = loadingState == .none
        }

        let changes = {
            self.layerPanelView.alpha = visible ? 1 : 0
            self.layerPanelView.transform = visible ? .identity : self.layerPanelHiddenTransform
            self.updatePanelScrimVisibility()
        }

        let completion: (Bool) -> Void = { _ in
            if !visible {
                self.layerPanelView.isHidden = true
                self.layerPanelView.isUserInteractionEnabled = false
            }
            self.finalizePanelScrimIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
    }

    private var layerPanelHiddenTransform: CGAffineTransform {
        CGAffineTransform(translationX: 26, y: -8)
    }

    private func toolbarToolDescriptors() -> [ToolbarToolDescriptor] {
        [
            ToolbarToolDescriptor(tool: .addText, button: addTextButton, action: #selector(addTextTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .addEmoji, button: addEmojiButton, action: #selector(addEmojiTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .addSticker, button: addStickerButton, action: #selector(addStickerTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .addImage, button: addPhotoButton, action: #selector(addPhotoTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .filter, button: filterButton, action: #selector(filterTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .addSignature, button: addSignatureButton, action: #selector(addSignatureTapped), requiresSignatureStore: true),
            ToolbarToolDescriptor(tool: .addBrush, button: eraserButton, action: #selector(eraserTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .duplicate, button: duplicateButton, action: #selector(duplicateTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .delete, button: deleteButton, action: #selector(deleteTapped), requiresSignatureStore: false),
            ToolbarToolDescriptor(tool: .addBrush, button: addBrushButton, action: #selector(addBrushTapped), requiresSignatureStore: false)
        ]
    }

    private func makeGridToolButton(title: String, systemImage: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        var titleAttributes = AttributeContainer()
        titleAttributes.font = theme.toolbarLabelFont.resolvedUIFont()
        configuration.attributedTitle = AttributedString(title, attributes: titleAttributes)
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePlacement = .top
        configuration.imagePadding = 8
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        configuration.background.cornerRadius = 20
        button.configuration = configuration
        button.layer.cornerRadius = 22
        button.layer.cornerCurve = .continuous
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.configurationUpdateHandler = { button in
            guard var updatedConfiguration = button.configuration else {
                return
            }
            let foregroundColor: UIColor
            if button.isEnabled {
                foregroundColor = button.isSelected ? CanvasEditorTheme.accent : CanvasEditorTheme.primaryText
            } else {
                foregroundColor = CanvasEditorTheme.secondaryText.withAlphaComponent(0.7)
            }
            updatedConfiguration.baseForegroundColor = foregroundColor
            updatedConfiguration.baseBackgroundColor = button.isSelected ? CanvasEditorTheme.accentMuted : .clear
            button.configuration = updatedConfiguration
            button.alpha = button.isEnabled ? 1 : 0.45
        }
        button.heightAnchor.constraint(equalToConstant: toolbarTileHeight).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: toolbarTileMinimumWidth).isActive = true
        return button
    }

    private func updateBrushButtonAppearance() {
        guard var configuration = addBrushButton.configuration else {
            return
        }

        configuration.image = UIImage(systemName: committedBrushConfiguration.type.systemImageName)
        addBrushButton.configuration = configuration
        addBrushButton.isSelected = isBrushModeEnabled
        addBrushButton.setNeedsUpdateConfiguration()
    }

    private func updateEraserButtonAppearance() {
        eraserButton.isSelected = isEraserModeEnabled
        eraserButton.setNeedsUpdateConfiguration()
    }

    private func makeHistoryButton(title: String, systemImage: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImage)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
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
                ? (button.isSelected ? CanvasEditorTheme.accent : CanvasEditorTheme.primaryText)
                : CanvasEditorTheme.secondaryText
            updatedConfiguration.background.backgroundColor = CanvasEditorTheme.cardSurface
            button.configuration = updatedConfiguration
            button.alpha = button.isEnabled ? 1 : 0.5
        }
        return button
    }

    private func dismissInspector(animated: Bool, revertingBrushDraft: Bool = true, revertingEraserDraft: Bool = true) {
        if revertingBrushDraft {
            brushDraftConfiguration = nil
        }
        if revertingEraserDraft {
            eraserDraftStrokeWidth = nil
        }
        isInspectorRequested = false
        toolInspectorMode = nil
        updateVisibleInspector(animated: animated)
    }

    private func dismissEditingOverlays(animated: Bool) {
        dismissInspector(animated: animated)
        setLayerPanelVisible(false, animated: animated)
        cancelActiveToolMode()
    }

    private func presentBrushInspector(mode: BrushInspectorMode, configuration: CanvasBrushConfiguration) {
        setLayerPanelVisible(false, animated: true)
        isInspectorRequested = false
        toolInspectorMode = .brush(mode)
        brushDraftConfiguration = configuration
        eraserDraftStrokeWidth = nil
        brushInspectorView.apply(configuration: configuration)
        updateVisibleInspector(animated: true)
    }

    private func presentEraserInspector(strokeWidth: Double) {
        setLayerPanelVisible(false, animated: true)
        isInspectorRequested = false
        toolInspectorMode = .eraser
        brushDraftConfiguration = nil
        eraserDraftStrokeWidth = strokeWidth
        eraserInspectorView.apply(strokeWidth: strokeWidth)
        updateVisibleInspector(animated: true)
    }

    private func setBrushModeEnabled(_ enabled: Bool, animated _: Bool, configuration: CanvasBrushConfiguration? = nil) {
        guard enabled != isBrushModeEnabled || (enabled && configuration != nil) else {
            return
        }

        if enabled {
            cancelActiveToolMode()
            let activeConfiguration = configuration ?? committedBrushConfiguration
            isBrushModeEnabled = true
            updateBrushButtonAppearance()
            store.selectNode(nil)
            stageView.beginDrawing(with: activeConfiguration)
        } else {
            stageView.cancelDrawingMode()
            isBrushModeEnabled = false
            updateBrushButtonAppearance()
        }
    }

    private func setEraserModeEnabled(_ enabled: Bool, animated: Bool) {
        guard enabled != isEraserModeEnabled else {
            return
        }

        if enabled {
            cancelActiveToolMode()
            dismissInspector(animated: animated)
            isEraserModeEnabled = true
            updateEraserButtonAppearance()
            store.selectNode(nil)
            stageView.beginErasing(strokeWidth: eraserStrokeWidth)
        } else {
            cancelActiveToolMode()
        }
    }

    private func cancelActiveToolMode() {
        stageView.cancelDrawingMode()

        if isBrushModeEnabled {
            isBrushModeEnabled = false
            updateBrushButtonAppearance()
        }

        if isEraserModeEnabled {
            isEraserModeEnabled = false
            updateEraserButtonAppearance()
        }
    }

    private func applyTextStyleMutation(_ mutation: (inout CanvasTextStyle) -> Void) {
        store.updateSelectedTextStyle(mutation)
        stageView.ensureSelectedTextFitsHeight()
    }

    private func presentTextColorPicker(for target: CanvasTextInspectorColorTarget) {
        guard let node = store.selectedNode, node.kind == .text || node.kind == .emoji else {
            return
        }

        let style = node.style ?? (node.kind == .emoji ? .defaultEmoji : .defaultText)
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = true
        picker.selectedColor = selectedColor(for: target, in: style)

        activeTextColorPickerTarget = target
        present(picker, animated: true)
    }

    private func applySelectedPickerColor(_ color: UIColor, for target: CanvasTextInspectorColorTarget) {
        applyTextColorSelection(CanvasColor(uiColor: color), for: target)
    }

    private func selectedColor(for target: CanvasTextInspectorColorTarget, in style: CanvasTextStyle) -> UIColor {
        switch target {
        case .foreground:
            return style.foregroundColor.uiColor
        case .background:
            return style.backgroundFill?.color.uiColor ?? .clear
        case .shadow:
            return style.shadow?.color.uiColor ?? .black
        case .outline:
            return style.outline?.color.uiColor ?? .black
        }
    }

    private func applyTextColorSelection(_ color: CanvasColor, for target: CanvasTextInspectorColorTarget) {
        switch target {
        case .foreground:
            applyTextStyleMutation { $0.foregroundColor = color }
        case .background:
            applyTextStyleMutation {
                if color.alpha <= 0.001 {
                    $0.backgroundFill = nil
                    $0.shadow = nil
                } else {
                    $0.backgroundFill = CanvasFillStyle(color: color)
                }
            }
        case .shadow:
            applyTextStyleMutation {
                guard var shadow = $0.shadow else { return }
                shadow.color = color
                $0.shadow = shadow
            }
        case .outline:
            applyTextStyleMutation {
                guard var outline = $0.outline else { return }
                outline.color = color
                $0.outline = outline
            }
        }
    }

    private func presentEmojiPrompt() {
        let picker = CanvasInsertPickerSheetViewController(
            mode: .emoji,
            items: CanvasInsertPickerCatalog.emojiItems,
            assetLoader: stageView.assetLoader
        ) { [weak self] items in
            guard let self else { return }
            let selectedEmoji = items.compactMap { item -> String? in
                guard case .emoji(let emoji) = item.preview else {
                    return nil
                }
                return emoji
            }
            self.store.addEmojiNodes(texts: selectedEmoji)
        }
        presentInsertPicker(picker)
    }

    private func presentStickerPicker() {
        let picker = CanvasInsertPickerSheetViewController(
            mode: .sticker,
            items: CanvasInsertPickerCatalog.stickerItems(from: store.configuration.stickerCatalog),
            assetLoader: stageView.assetLoader
        ) { [weak self] items in
            guard let self else { return }
            let selectedSources = items.compactMap { item -> CanvasAssetSource? in
                guard case .asset(let source) = item.preview else {
                    return nil
                }
                return source
            }
            self.store.addStickerNodes(sources: selectedSources)
        }
        presentInsertPicker(picker)
    }

    private func presentFilterPicker() {
        let project = store.project
        let maxThumbnailDimension: CGFloat = 140
        let canvasMaxDimension = max(CGFloat(project.canvasSize.width), CGFloat(project.canvasSize.height))
        let previewScale = max(min(maxThumbnailDimension / canvasMaxDimension, 1), 0.05)
        let basePreviewImage = CanvasEditorRenderer.renderBaseImage(
            project: project,
            assetLoader: stageView.assetLoader,
            imageScale: previewScale
        )

        let currentFilter = project.canvasFilter
        filterDraftPreset = currentFilter
        stageView.setPreviewCanvasFilter(currentFilter)

        let picker = CanvasFilterPickerSheetViewController(
            selectedPreset: currentFilter,
            basePreviewImage: basePreviewImage,
            onSelectionChanged: { [weak self] preset in
                guard let self else {
                    return
                }
                self.filterDraftPreset = preset
                self.stageView.setPreviewCanvasFilter(preset)
            },
            onCancel: { [weak self] in
                guard let self else {
                    return
                }
                self.filterDraftPreset = nil
                self.stageView.setPreviewCanvasFilter(nil)
            },
            onDone: { [weak self] preset in
                guard let self else {
                    return
                }
                self.store.updateCanvasFilter(preset)
                self.filterDraftPreset = nil
                self.stageView.setPreviewCanvasFilter(nil)
            }
        )
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    private func loadSignaturesAndPresentFlow() {
        guard let signatureStore else {
            return
        }

        setLoadingState(.loadingSignatures)
        Task { [weak self] in
            guard let self else { return }

            do {
                let signatures = try await signatureStore.loadSignatures()
                self.setLoadingState(.none)

                if signatures.isEmpty {
                    self.presentSignatureEditor(returnToPickerOnCancel: false)
                } else {
                    self.presentSignaturePicker(signatures: signatures)
                }
            } catch {
                self.setLoadingState(.none)
                self.presentErrorAlert(message: self.strings.loadSignaturesFailureMessage)
            }
        }
    }

    private func presentSignaturePicker(signatures: [CanvasSignatureDescriptor]) {
        guard let signatureStore else {
            return
        }

        let picker = CanvasSignaturePickerSheetViewController(
            signatures: signatures,
            signatureStore: signatureStore,
            assetLoader: stageView.assetLoader,
            onRequestNew: { [weak self] in
                self?.presentSignatureEditor(returnToPickerOnCancel: true)
            },
            onAdd: { [weak self] signature in
                self?.insertSignature(signature)
            }
        )
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    private func presentSignatureEditor(returnToPickerOnCancel: Bool) {
        guard let signatureStore else {
            return
        }

        let editor = CanvasSignatureEditorViewController(
            signatureConfiguration: store.configuration.signatures,
            fallbackPalette: store.configuration.colorPalette,
            allowsColorPicker: store.configuration.features.allowsColorPicker,
            assetLoader: stageView.assetLoader,
            signatureStore: signatureStore,
            onCancel: { [weak self] in
                guard let self, returnToPickerOnCancel else {
                    return
                }
                self.loadSignaturesAndPresentFlow()
            },
            onSave: { [weak self] signature in
                self?.insertSignature(signature)
            }
        )
        editor.modalPresentationStyle = .fullScreen
        present(editor, animated: true)
    }

    private func insertSignature(_ signature: CanvasSignatureDescriptor) {
        let intrinsicSize = stageView.assetLoader
            .imageSynchronously(for: signature.source)
            .map { CanvasSize($0.size) }
        store.addImageNode(source: signature.source, intrinsicSize: intrinsicSize)
    }

    private func resolvedPhotoImportTargetForCurrentSelection() -> PhotoImportTarget {
        guard let selectedNode = store.selectedNode,
              selectedNode.kind == .maskedImage else {
            return .addImageNode
        }

        return .maskedNode(selectedNode.id)
    }

    private func presentPhotoPicker(for target: PhotoImportTarget) {
        pendingPhotoImportTarget = target

        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func applyImportedPhoto(
        source: CanvasAssetSource,
        importedImageSize: CanvasSize,
        target: PhotoImportTarget
    ) {
        switch target {
        case .addImageNode:
            store.addImageNode(source: source, intrinsicSize: importedImageSize)

        case .maskedNode(let nodeID):
            if store.selectedNodeID != nodeID {
                store.selectNode(nodeID)
            }

            guard store.selectedNodeID == nodeID,
                  store.selectedNode?.kind == .maskedImage else {
                store.addImageNode(source: source, intrinsicSize: importedImageSize)
                return
            }

            store.updateSelectedSource(source)
        }
    }

    private func presentInsertPicker(_ picker: UIViewController) {
        setLayerPanelVisible(false, animated: true)
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: true)
    }

    private func presentErrorAlert(message: String) {
        let alert = UIAlertController(
            title: strings.errorAlertTitle,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: strings.okButtonTitle, style: .default))
        present(alert, animated: true)
    }

    private func presentCloseConfirmationAlert() {
        let alert = UIAlertController(
            title: strings.closeConfirmationTitle,
            message: strings.closeConfirmationMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: strings.closeConfirmationStayButtonTitle,
            style: .cancel
        ))
        alert.addAction(UIAlertAction(
            title: strings.closeConfirmationDiscardButtonTitle,
            style: .destructive
        ) { [weak self] _ in
            self?.closeEditor()
        })
        present(alert, animated: true)
    }

    private func closeEditor() {
        delegate?.canvasEditorViewControllerDidCancel(self)
    }

    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, didSelectNodeID nodeID: String) {
        store.selectNode(nodeID)
    }

    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, didToggleLockForNodeID nodeID: String) {
        store.toggleNodeLock(nodeID)
    }

    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, moveNodeFrom sourceIndex: Int, to destinationIndex: Int) {
        store.moveNodeInLayerPanel(from: sourceIndex, to: destinationIndex)
    }

    func textInspectorViewDidRequestTextEdit(_ textInspectorView: CanvasTextInspectorView) {
        stageView.beginInlineEditingForSelectedNode()
    }

    func canvasBrushInspectorViewDidCancel(_ brushInspectorView: CanvasBrushInspectorView) {
        dismissInspector(animated: true)
    }

    func canvasBrushInspectorView(_ brushInspectorView: CanvasBrushInspectorView, didChange configuration: CanvasBrushConfiguration) {
        brushDraftConfiguration = configuration
    }

    func canvasBrushInspectorView(_ brushInspectorView: CanvasBrushInspectorView, didConfirm configuration: CanvasBrushConfiguration) {
        let resolvedConfiguration = brushDraftConfiguration ?? configuration

        switch toolInspectorMode {
        case .brush(.create):
            committedBrushConfiguration = resolvedConfiguration
            brushDraftConfiguration = nil
            dismissInspector(animated: true, revertingBrushDraft: false)
            setBrushModeEnabled(true, animated: true, configuration: resolvedConfiguration)

        case .brush(.edit):
            brushDraftConfiguration = nil
            store.updateSelectedShapeStyle(
                type: resolvedConfiguration.type,
                strokeColor: resolvedConfiguration.color,
                strokeWidth: resolvedConfiguration.strokeWidth,
                opacity: resolvedConfiguration.opacity
            )
            dismissInspector(animated: true, revertingBrushDraft: false)

        case .eraser:
            dismissInspector(animated: true)

        case .none:
            dismissInspector(animated: true)
        }
    }

    func canvasEraserInspectorViewDidCancel(_ eraserInspectorView: CanvasEraserInspectorView) {
        dismissInspector(animated: true)
    }

    func canvasEraserInspectorView(_ eraserInspectorView: CanvasEraserInspectorView, didChange strokeWidth: Double) {
        eraserDraftStrokeWidth = strokeWidth
    }

    func canvasEraserInspectorView(_ eraserInspectorView: CanvasEraserInspectorView, didConfirm strokeWidth: Double) {
        let resolvedStrokeWidth = eraserDraftStrokeWidth ?? strokeWidth
        eraserStrokeWidth = resolvedStrokeWidth
        eraserDraftStrokeWidth = nil
        dismissInspector(animated: true, revertingBrushDraft: false, revertingEraserDraft: false)
        setEraserModeEnabled(true, animated: true)
    }

    func canvasStageViewDidTapSelectedTextNode(_ stageView: CanvasStageView) {
        guard let node = store.selectedNode, node.kind == .text || node.kind == .emoji, !isInlineEditingText else {
            return
        }
        cancelActiveToolMode()
        setLayerPanelVisible(false, animated: true)
        toolInspectorMode = nil
        brushDraftConfiguration = nil
        eraserDraftStrokeWidth = nil
        isInspectorRequested.toggle()
        refreshChrome()
    }

    func canvasStageViewDidTapSelectedShapeNode(_ stageView: CanvasStageView) {
        guard let node = store.selectedNode,
              node.kind == .shape,
              let shape = node.shape,
              !isInlineEditingText else {
            return
        }

        if toolInspectorMode == .brush(.edit), !brushInspectorView.isHidden {
            dismissInspector(animated: true)
            return
        }

        presentBrushInspector(
            mode: .edit,
            configuration: CanvasBrushConfiguration(shape: shape, opacity: node.opacity)
        )
    }

    func canvasStageViewDidTapEmptyMaskedImageNode(_ stageView: CanvasStageView) {
        dismissEditingOverlays(animated: true)
        guard let selectedNode = store.selectedNode,
              selectedNode.kind == .maskedImage else {
            return
        }
        presentPhotoPicker(for: .maskedNode(selectedNode.id))
    }

    func canvasStageViewDidBeginInlineEditing(_ stageView: CanvasStageView) {
        isInlineEditingText = true
        isInspectorRequested = false
        toolInspectorMode = nil
        brushDraftConfiguration = nil
        eraserDraftStrokeWidth = nil
        updateVisibleInspector(animated: true)
    }

    func canvasStageViewDidEndInlineEditing(_ stageView: CanvasStageView) {
        isInlineEditingText = false
        refreshChrome()
    }

    func canvasStageViewDidBeginNodeManipulation(_ stageView: CanvasStageView) {
        guard isInspectorRequested || toolInspectorMode != nil || isInspectorVisible else {
            return
        }
        isInspectorRequested = false
        toolInspectorMode = nil
        brushDraftConfiguration = nil
        eraserDraftStrokeWidth = nil
        updateVisibleInspector(animated: true)
    }

    func canvasStageView(_ stageView: CanvasStageView, didFinishDrawing draft: CanvasShapeDraft) {
        committedBrushConfiguration = CanvasBrushConfiguration(
            type: draft.type,
            strokeWidth: draft.strokeWidth,
            opacity: draft.opacity,
            color: draft.strokeColor
        )
        store.addShapeNode(from: draft)
        if isBrushModeEnabled {
            store.selectNode(nil)
        }
    }

    func canvasStageView(_ stageView: CanvasStageView, didFinishErasing stroke: CanvasEraserStroke) {
        eraserStrokeWidth = stroke.strokeWidth
        store.addEraserStroke(stroke)
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSelectFontFamily fontFamily: String) {
        applyTextStyleMutation { $0.fontFamily = fontFamily }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSelectAlignment alignment: CanvasTextAlignment) {
        applyTextStyleMutation { $0.alignment = alignment }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSelectColor color: CanvasColor, for target: CanvasTextInspectorColorTarget) {
        applyTextColorSelection(color, for: target)
    }

    func textInspectorViewDidSelectClearBackground(_ textInspectorView: CanvasTextInspectorView) {
        applyTextStyleMutation {
            $0.backgroundFill = nil
            $0.shadow = nil
        }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didRequestColorPickerFor target: CanvasTextInspectorColorTarget) {
        presentTextColorPicker(for: target)
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSetItalic isItalic: Bool) {
        applyTextStyleMutation { $0.isItalic = isItalic }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSetShadow isEnabled: Bool) {
        applyTextStyleMutation {
            $0.shadow = isEnabled ? CanvasShadowStyle(color: .black, radius: 12, offsetX: 0, offsetY: 8) : nil
        }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didSetOutline isEnabled: Bool) {
        applyTextStyleMutation {
            $0.outline = isEnabled ? CanvasOutlineStyle(color: .black, width: 6) : nil
        }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didChangeFontSize value: Double) {
        applyTextStyleMutation { $0.fontSize = value }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didChangeLetterSpacing value: Double) {
        applyTextStyleMutation { $0.letterSpacing = value }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didChangeLineSpacing value: Double) {
        applyTextStyleMutation { $0.lineSpacing = value }
    }

    func textInspectorView(_ textInspectorView: CanvasTextInspectorView, didChangeOpacity value: Double) {
        applyTextStyleMutation { $0.opacity = value }
    }

    public func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let activeTextColorPickerTarget else {
            return
        }
        applySelectedPickerColor(viewController.selectedColor, for: activeTextColorPickerTarget)
    }

    public func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        activeTextColorPickerTarget = nil
    }

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let importTarget = pendingPhotoImportTarget ?? .addImageNode
        pendingPhotoImportTarget = nil
        dismiss(animated: true)
        guard let result = results.first else {
            return
        }
        guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        setLoadingState(.importingImage)
        let assetLoader = stageView.assetLoader
        let maxDimension = CGFloat(store.configuration.exportMaxDimension)
        let importFailureMessage = strings.importImageFailureMessage
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            let importedImage = object as? UIImage
            let importedImageSize = importedImage?.size
            let source = importedImage.flatMap {
                assetLoader.inlineSource(from: $0, maxDimension: maxDimension)
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.setLoadingState(.none)

                guard let source, let importedImageSize else {
                    self.presentErrorAlert(message: importFailureMessage)
                    return
                }

                self.applyImportedPhoto(
                    source: source,
                    importedImageSize: CanvasSize(importedImageSize),
                    target: importTarget
                )
            }
        }
    }

    @objc
    private func closeTapped() {
        guard hasCanvasChanges else {
            closeEditor()
            return
        }
        presentCloseConfirmationAlert()
    }

    @objc
    private func layersTapped() {
        dismissEditingOverlays(animated: true)
        setLayerPanelVisible(!isLayerPanelVisible, animated: true)
    }

    @objc
    private func panelScrimTapped() {
        if isLayerPanelVisible {
            setLayerPanelVisible(false, animated: true)
        } else if isInspectorVisible {
            dismissInspector(animated: true)
        }
    }

    @objc
    private func exportTapped() {
        let project = store.project
        let assetLoader = stageView.assetLoader
        let exportPNGFailureMessage = strings.exportPNGFailureMessage
        let exportImageFailureMessage = strings.exportImageFailureMessage
        setLoadingState(.exportingImage)

        Task { [weak self] in
            guard let self else { return }

            let exportSources = Self.exportAssetSources(from: project)
            await Task.detached(priority: .userInitiated) {
                assetLoader.prefetchSynchronously(for: exportSources)
            }.value

            let imageData = await MainActor.run {
                autoreleasepool {
                    CanvasEditorRenderer.render(project: project, assetLoader: assetLoader).pngData()
                }
            }

            let result: Result<CanvasEditorResult, CanvasEditorOperationError> = autoreleasepool {
                guard let imageData else {
                    return .failure(CanvasEditorOperationError.pngEncodingFailed)
                }

                do {
                    let projectData = try Self.encodeProjectData(for: project, prettyPrinted: false)
                    return .success(CanvasEditorResult(imageData: imageData, projectData: projectData))
                } catch {
                    return .failure(.exportPreparationFailed)
                }
            }

            await MainActor.run {
                self.setLoadingState(.none)

                switch result {
                case .success(let exportResult):
                    guard let previewImage = UIImage(data: exportResult.imageData) else {
                        self.presentErrorAlert(message: exportImageFailureMessage)
                        return
                    }
                    self.delegate?.canvasEditorViewController(
                        self,
                        didExport: exportResult,
                        previewImage: previewImage
                    )
                case .failure(let error):
                    let message = error == .pngEncodingFailed
                        ? exportPNGFailureMessage
                        : exportImageFailureMessage
                    self.presentErrorAlert(message: message)
                }
            }
        }
    }

    private static func exportAssetSources(from project: CanvasProject) -> [CanvasAssetSource] {
        var sources: [CanvasAssetSource] = []

        if let backgroundSource = project.background.source {
            sources.append(backgroundSource)
        }

        for node in project.nodes {
            if let source = node.source {
                sources.append(source)
            }

            if let maskedImage = node.maskedImage {
                sources.append(maskedImage.maskSource)
                if let overlaySource = maskedImage.overlaySource {
                    sources.append(overlaySource)
                }
            }
        }

        return sources
    }

    @objc
    private func addTextTapped() {
        dismissEditingOverlays(animated: true)
        store.addTextNode()
        stageView.beginInlineEditingForSelectedNode(placeCursorAtEnd: false)
    }

    @objc
    private func addEmojiTapped() {
        dismissEditingOverlays(animated: true)
        presentEmojiPrompt()
    }

    @objc
    private func addStickerTapped() {
        dismissEditingOverlays(animated: true)
        presentStickerPicker()
    }

    @objc
    private func addPhotoTapped() {
        dismissEditingOverlays(animated: true)
        presentPhotoPicker(for: resolvedPhotoImportTargetForCurrentSelection())
    }

    @objc
    private func filterTapped() {
        dismissEditingOverlays(animated: true)
        presentFilterPicker()
    }

    @objc
    private func addSignatureTapped() {
        dismissEditingOverlays(animated: true)
        loadSignaturesAndPresentFlow()
    }

    @objc
    private func eraserTapped() {
        if isEraserModeEnabled {
            setEraserModeEnabled(false, animated: true)
            return
        }

        cancelActiveToolMode()
        presentEraserInspector(strokeWidth: eraserStrokeWidth)
    }

    @objc
    private func addBrushTapped() {
        if isBrushModeEnabled {
            setBrushModeEnabled(false, animated: true)
            return
        }

        cancelActiveToolMode()
        presentBrushInspector(mode: .create, configuration: committedBrushConfiguration)
    }

    @objc
    private func duplicateTapped() {
        dismissEditingOverlays(animated: true)
        store.duplicateSelectedNode()
    }

    @objc
    private func deleteTapped() {
        dismissEditingOverlays(animated: true)
        store.deleteSelectedNode()
    }

    @objc
    private func undoTapped() {
        cancelActiveToolMode()
        store.undo()
    }

    @objc
    private func redoTapped() {
        cancelActiveToolMode()
        store.redo()
    }
}

@MainActor
protocol CanvasLayerPanelViewDelegate: AnyObject {
    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, didSelectNodeID nodeID: String)
    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, didToggleLockForNodeID nodeID: String)
    func canvasLayerPanelView(_ layerPanelView: CanvasLayerPanelView, moveNodeFrom sourceIndex: Int, to destinationIndex: Int)
}

final class CanvasLayerPanelView: UIView, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: CanvasLayerPanelViewDelegate?

    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var nodes: [CanvasNode] = []
    private var selectedNodeID: String?

    private let headerHeight: CGFloat = 52
    private let rowHeight: CGFloat = 56
    private let bottomInset: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)

        let layout = CanvasEditorUIRuntime.currentConfiguration.layout

        applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.sheetSurface,
            cornerRadius: CGFloat(layout.floatingPanelCornerRadius),
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.surfaceShadow,
            shadowOpacity: 1,
            shadowRadius: 24,
            shadowOffset: CGSize(width: 0, height: 12)
        )

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.layerPanelTitle
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.sheetTitleFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.primaryText
        addSubview(titleLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = rowHeight
        tableView.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: bottomInset, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CanvasLayerPanelCell.self, forCellReuseIdentifier: CanvasLayerPanelCell.reuseIdentifier)
        tableView.allowsSelection = true
        tableView.allowsSelectionDuringEditing = true
        tableView.setEditing(true, animated: false)
        addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),

            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(nodes: [CanvasNode], selectedNodeID: String?) {
        self.nodes = nodes
        self.selectedNodeID = selectedNodeID
        tableView.reloadData()

        if let selectedNodeID,
           let selectedIndex = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            tableView.selectRow(at: IndexPath(row: selectedIndex, section: 0), animated: false, scrollPosition: .none)
        } else if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: false)
        }
    }

    func preferredHeight(maximumHeight: CGFloat) -> CGFloat {
        let contentHeight = headerHeight + (CGFloat(nodes.count) * rowHeight) + bottomInset + 8
        return min(maximumHeight, max(contentHeight, 124))
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        nodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CanvasLayerPanelCell.reuseIdentifier,
            for: indexPath
        ) as? CanvasLayerPanelCell else {
            return UITableViewCell()
        }

        let node = nodes[indexPath.row]
        cell.configure(node: node, isSelectedInPanel: node.id == selectedNodeID)
        cell.onToggleLock = { [weak self] in
            guard let self else { return }
            self.delegate?.canvasLayerPanelView(self, didToggleLockForNodeID: node.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        nodes[indexPath.row].isEditable
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        nodes[indexPath.row].isEditable ? indexPath : nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.canvasLayerPanelView(self, didSelectNodeID: nodes[indexPath.row].id)
    }

    func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        let safeRow = min(max(proposedDestinationIndexPath.row, 0), max(nodes.count - 1, 0))
        return IndexPath(row: safeRow, section: 0)
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movingNode = nodes.remove(at: sourceIndexPath.row)
        nodes.insert(movingNode, at: destinationIndexPath.row)
        delegate?.canvasLayerPanelView(self, moveNodeFrom: sourceIndexPath.row, to: destinationIndexPath.row)
    }
}

final class CanvasLayerPanelCell: UITableViewCell {
    static let reuseIdentifier = "CanvasLayerPanelCell"
    private static let previewAssetLoader = CanvasAssetLoader(resources: CanvasEditorUIRuntime.currentConfiguration.resources)

    var onToggleLock: (() -> Void)?

    private let rowBackgroundView = UIView()
    private let previewContainerView = UIView()
    private let previewLabel = UILabel()
    private let previewImageView = UIImageView()
    private let titleLabel = UILabel()
    private let lockButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        rowBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        rowBackgroundView.applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 16,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.controlShadow,
            shadowOpacity: 1,
            shadowRadius: 12,
            shadowOffset: CGSize(width: 0, height: 6)
        )
        contentView.addSubview(rowBackgroundView)

        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.layer.cornerRadius = 10
        previewContainerView.layer.cornerCurve = .continuous
        previewContainerView.clipsToBounds = true
        rowBackgroundView.addSubview(previewContainerView)

        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.layerPreviewFont.resolvedUIFont()
        previewLabel.textAlignment = .center
        previewContainerView.addSubview(previewLabel)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.contentMode = .scaleAspectFit
        previewContainerView.addSubview(previewImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.layerTitleFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail
        rowBackgroundView.addSubview(titleLabel)

        lockButton.translatesAutoresizingMaskIntoConstraints = false
        lockButton.tintColor = CanvasEditorTheme.secondaryText
        lockButton.addAction(UIAction { [weak self] _ in
            self?.onToggleLock?()
        }, for: .touchUpInside)
        rowBackgroundView.addSubview(lockButton)

        NSLayoutConstraint.activate([
            rowBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            rowBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            rowBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            rowBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),

            previewContainerView.leadingAnchor.constraint(equalTo: rowBackgroundView.leadingAnchor, constant: 10),
            previewContainerView.centerYAnchor.constraint(equalTo: rowBackgroundView.centerYAnchor),
            previewContainerView.widthAnchor.constraint(equalToConstant: 30),
            previewContainerView.heightAnchor.constraint(equalToConstant: 30),

            previewLabel.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 4),
            previewLabel.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -4),
            previewLabel.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 2),
            previewLabel.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -2),

            previewImageView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 6),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -6),
            previewImageView.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 6),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -6),

            titleLabel.leadingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: rowBackgroundView.centerYAnchor),

            lockButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            lockButton.trailingAnchor.constraint(equalTo: rowBackgroundView.trailingAnchor, constant: -30),
            lockButton.centerYAnchor.constraint(equalTo: rowBackgroundView.centerYAnchor),
            lockButton.widthAnchor.constraint(equalToConstant: 28),
            lockButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggleLock = nil
    }

    func configure(node: CanvasNode, isSelectedInPanel: Bool) {
        let isLocked = !node.isEditable
        rowBackgroundView.backgroundColor = isSelectedInPanel ? CanvasEditorTheme.accentMuted : CanvasEditorTheme.cardSurface
        rowBackgroundView.layer.borderColor = (isSelectedInPanel
            ? CanvasEditorTheme.accent.withAlphaComponent(0.22)
            : CanvasEditorTheme.separator).cgColor
        rowBackgroundView.alpha = isLocked ? 0.58 : 1
        titleLabel.text = Self.displayTitle(for: node)
        titleLabel.textColor = CanvasEditorTheme.primaryText
        lockButton.setImage(
            UIImage(
                systemName: isLocked
                    ? CanvasEditorUIRuntime.currentConfiguration.icons.layerLocked
                    : CanvasEditorUIRuntime.currentConfiguration.icons.layerUnlocked
            ),
            for: .normal
        )
        lockButton.tintColor = isLocked ? CanvasEditorTheme.destructive : CanvasEditorTheme.secondaryText

        previewContainerView.backgroundColor = Self.previewBackground(for: node)
        previewLabel.isHidden = false
        previewImageView.isHidden = true

        switch node.kind {
        case .text:
            previewLabel.text = "T"
            previewLabel.textColor = node.style?.foregroundColor.uiColor ?? CanvasEditorTheme.primaryText
        case .emoji:
            previewLabel.text = String((node.text ?? "🙂").prefix(1))
            previewLabel.textColor = CanvasEditorTheme.primaryText
        case .sticker:
            previewImageView.isHidden = false
            previewLabel.isHidden = true
            let stickerImage = Self.previewAssetLoader.imageSynchronously(for: node.source)
            previewImageView.image = stickerImage ?? UIImage(
                systemName: node.source?.name ?? CanvasEditorUIRuntime.currentConfiguration.icons.defaultSticker
            )
            previewImageView.tintColor = stickerImage == nil ? (node.style?.foregroundColor.uiColor ?? CanvasEditorTheme.primaryText) : nil
        case .image:
            previewImageView.isHidden = false
            previewLabel.isHidden = true
            previewImageView.image = UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.layerImage)
            previewImageView.tintColor = CanvasEditorTheme.primaryText
        case .maskedImage:
            previewImageView.isHidden = false
            previewLabel.isHidden = true
            let maskImage = node.maskedImage.flatMap { Self.previewAssetLoader.imageSynchronously(for: $0.maskSource) }
            previewImageView.image = maskImage ?? UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.layerImage)
            previewImageView.tintColor = maskImage == nil ? CanvasEditorTheme.primaryText : nil
        case .shape:
            previewImageView.isHidden = false
            previewLabel.isHidden = true
            previewImageView.image = UIImage(
                systemName: node.shape?.type.systemImageName ?? CanvasEditorUIRuntime.currentConfiguration.icons.shapeBrush
            )
            previewImageView.tintColor = node.shape?.strokeColor.uiColor ?? CanvasEditorTheme.primaryText
        }
    }

    private static func displayTitle(for node: CanvasNode) -> String {
        if let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        if let text = node.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return String(text.prefix(18))
        }

        switch node.kind {
        case .text:
            return CanvasEditorUIRuntime.currentConfiguration.strings.layerTextFallbackTitle
        case .emoji:
            return CanvasEditorUIRuntime.currentConfiguration.strings.layerEmojiFallbackTitle
        case .sticker:
            return CanvasEditorUIRuntime.currentConfiguration.strings.layerStickerFallbackTitle
        case .image:
            return CanvasEditorUIRuntime.currentConfiguration.strings.layerImageFallbackTitle
        case .maskedImage:
            return CanvasEditorUIRuntime.currentConfiguration.strings.layerImageFallbackTitle
        case .shape:
            return node.shape?.type.displayTitle ?? CanvasEditorUIRuntime.currentConfiguration.strings.layerShapeFallbackTitle
        }
    }

    private static func previewBackground(for node: CanvasNode) -> UIColor {
        switch node.kind {
        case .text:
            return CanvasEditorTheme.layerTextPreviewBackground
        case .emoji:
            return CanvasEditorTheme.layerEmojiPreviewBackground
        case .sticker:
            return CanvasEditorTheme.layerStickerPreviewBackground
        case .image:
            return CanvasEditorTheme.layerImagePreviewBackground
        case .maskedImage:
            return CanvasEditorTheme.layerImagePreviewBackground
        case .shape:
            return CanvasEditorTheme.layerShapePreviewBackground
        }
    }
}
#endif
