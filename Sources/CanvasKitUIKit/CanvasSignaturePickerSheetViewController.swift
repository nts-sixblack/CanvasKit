#if canImport(UIKit)
import UIKit
import CanvasKitCore

@MainActor
final class CanvasSignaturePickerSheetViewController: UIViewController {
    private let hiddenSheetOffset: CGFloat = 420
    private var signatures: [CanvasSignatureDescriptor]
    private let signatureStore: CanvasSignatureStore
    private let assetLoader: CanvasAssetLoader
    private let onRequestNew: () -> Void
    private let onAdd: (CanvasSignatureDescriptor) -> Void

    private let scrimView = UIControl()
    private let sheetContainerView = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let cancelButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)

    private var sheetBottomConstraint: NSLayoutConstraint?
    private var hasAnimatedPresentation = false
    private var signatureTiles: [String: CanvasSignaturePickerTileView] = [:]
    private var selectedSignatureID: String? {
        didSet {
            updateSelectionUI()
        }
    }
    private var isDeletingSignature = false {
        didSet {
            updateInteractionState()
        }
    }

    init(
        signatures: [CanvasSignatureDescriptor],
        signatureStore: CanvasSignatureStore,
        assetLoader: CanvasAssetLoader,
        onRequestNew: @escaping () -> Void,
        onAdd: @escaping (CanvasSignatureDescriptor) -> Void
    ) {
        self.signatures = signatures
        self.signatureStore = signatureStore
        self.assetLoader = assetLoader
        self.onRequestNew = onRequestNew
        self.onAdd = onAdd
        selectedSignatureID = signatures.first?.id
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePresentation()
        setupLayout()
        rebuildTiles()
        updateSelectionUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedPresentation else {
            return
        }

        hasAnimatedPresentation = true
        animateSheet(isPresenting: true, completion: nil)
    }

    private func configurePresentation() {
        view.backgroundColor = .clear
    }

    private func setupLayout() {
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        scrimView.backgroundColor = CanvasEditorTheme.scrim
        scrimView.alpha = 0
        scrimView.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(scrimView)

        sheetContainerView.translatesAutoresizingMaskIntoConstraints = false
        sheetContainerView.applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 28,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.surfaceShadow,
            shadowOpacity: 1,
            shadowRadius: 24,
            shadowOffset: CGSize(width: 0, height: -10)
        )
        sheetContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(sheetContainerView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 14
        scrollView.addSubview(stackView)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.configuration = .plain()
        cancelButton.configuration?.title = CanvasEditorUIRuntime.currentConfiguration.strings.signatureCancelButtonTitle
        cancelButton.configuration?.baseForegroundColor = CanvasEditorTheme.primaryText
        cancelButton.titleLabel?.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.configuration = .plain()
        addButton.configuration?.title = CanvasEditorUIRuntime.currentConfiguration.strings.signatureAddButtonTitle
        addButton.configuration?.baseForegroundColor = CanvasEditorTheme.primaryText
        addButton.titleLabel?.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        [scrollView, cancelButton, addButton].forEach(sheetContainerView.addSubview)

        sheetBottomConstraint = sheetContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: hiddenSheetOffset)
        sheetBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.topAnchor.constraint(equalTo: view.topAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetContainerView.heightAnchor.constraint(equalToConstant: 264),

            scrollView.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor, constant: -24),
            scrollView.topAnchor.constraint(equalTo: sheetContainerView.topAnchor, constant: 24),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor, constant: 32),
            cancelButton.bottomAnchor.constraint(equalTo: sheetContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            addButton.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor, constant: -32),
            addButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),

            scrollView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -24)
        ])
    }

    private func rebuildTiles() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        signatureTiles.removeAll()

        let newTile = CanvasSignaturePickerTileView()
        newTile.configureAsNew()
        newTile.addTarget(self, action: #selector(newTapped), for: .touchUpInside)
        stackView.addArrangedSubview(newTile)

        signatures.forEach { signature in
            let tile = CanvasSignaturePickerTileView()
            tile.configure(signature: signature, assetLoader: assetLoader)
            tile.addAction(UIAction { [weak self] _ in
                self?.selectedSignatureID = signature.id
            }, for: .touchUpInside)
            tile.onDeleteTapped = { [weak self] in
                self?.presentDeleteConfirmation(for: signature)
            }
            signatureTiles[signature.id] = tile
            stackView.addArrangedSubview(tile)
        }
    }

    private func applySignatures(_ signatures: [CanvasSignatureDescriptor]) {
        let previousSelectionID = selectedSignatureID
        self.signatures = signatures

        if let previousSelectionID,
           signatures.contains(where: { $0.id == previousSelectionID }) {
            selectedSignatureID = previousSelectionID
        } else {
            selectedSignatureID = signatures.first?.id
        }

        rebuildTiles()
        updateSelectionUI()
    }

    private func updateSelectionUI() {
        signatureTiles.forEach { id, tile in
            tile.isSelected = id == selectedSignatureID
        }
        addButton.isEnabled = selectedSignatureID != nil
        addButton.alpha = addButton.isEnabled ? 1 : 0.45
    }

    private func updateInteractionState() {
        sheetContainerView.isUserInteractionEnabled = !isDeletingSignature
        sheetContainerView.alpha = isDeletingSignature ? 0.7 : 1
    }

    private func presentDeleteConfirmation(for signature: CanvasSignatureDescriptor) {
        let strings = CanvasEditorUIRuntime.currentConfiguration.strings
        let alert = UIAlertController(
            title: strings.deleteToolTitle,
            message: strings.deleteSignatureConfirmationMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: strings.signatureCancelButtonTitle,
            style: .cancel
        ))
        alert.addAction(UIAlertAction(
            title: strings.deleteToolTitle,
            style: .destructive
        ) { [weak self] _ in
            self?.deleteSignature(signature)
        })
        present(alert, animated: true)
    }

    private func deleteSignature(_ signature: CanvasSignatureDescriptor) {
        isDeletingSignature = true

        Task { [weak self] in
            guard let self else { return }

            do {
                try await signatureStore.deleteSignature(id: signature.id)
                let refreshedSignatures = try await signatureStore.loadSignatures()
                self.isDeletingSignature = false
                self.applySignatures(refreshedSignatures)
            } catch {
                self.isDeletingSignature = false
                self.presentErrorAlert(
                    message: CanvasEditorUIRuntime.currentConfiguration.strings.deleteSignatureFailureMessage
                )
            }
        }
    }

    private func presentErrorAlert(message: String) {
        let strings = CanvasEditorUIRuntime.currentConfiguration.strings
        let alert = UIAlertController(
            title: strings.errorAlertTitle,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: strings.okButtonTitle, style: .default))
        present(alert, animated: true)
    }

    @objc
    private func cancelTapped() {
        animateSheet(isPresenting: false) { [weak self] in
            self?.dismiss(animated: false)
        }
    }

    @objc
    private func addTapped() {
        guard let selectedSignatureID,
              let signature = signatures.first(where: { $0.id == selectedSignatureID }) else {
            return
        }

        animateSheet(isPresenting: false) { [weak self] in
            self?.dismiss(animated: false) {
                self?.onAdd(signature)
            }
        }
    }

    @objc
    private func newTapped() {
        animateSheet(isPresenting: false) { [weak self] in
            self?.dismiss(animated: false) {
                self?.onRequestNew()
            }
        }
    }

    private func animateSheet(isPresenting: Bool, completion: (() -> Void)?) {
        sheetBottomConstraint?.constant = isPresenting ? 0 : hiddenSheetOffset
        let animations = {
            self.scrimView.alpha = isPresenting ? 1 : 0
            self.view.layoutIfNeeded()
        }

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseOut],
            animations: animations
        ) { _ in
            completion?()
        }
    }
}

private final class CanvasSignaturePickerTileView: UIControl {
    private let previewContainerView = UIView()
    private let previewImageView = UIImageView()
    private let plusIconView = UIImageView()
    private let deleteButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private var representedSignatureID: String?
    var onDeleteTapped: (() -> Void)?

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 142).isActive = true

        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.isUserInteractionEnabled = false
        previewContainerView.layer.cornerRadius = 20
        previewContainerView.layer.cornerCurve = .continuous
        previewContainerView.layer.borderWidth = 2
        previewContainerView.backgroundColor = CanvasEditorTheme.canvasBackdrop
        addSubview(previewContainerView)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.tintColor = CanvasEditorTheme.primaryText
        previewContainerView.addSubview(previewImageView)

        plusIconView.translatesAutoresizingMaskIntoConstraints = false
        plusIconView.contentMode = .scaleAspectFit
        plusIconView.tintColor = CanvasEditorTheme.accent
        previewContainerView.addSubview(plusIconView)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.configuration = .plain()
        deleteButton.configuration?.image = UIImage(systemName: CanvasEditorUIRuntime.currentConfiguration.icons.deleteTool)
        deleteButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        deleteButton.configuration?.baseForegroundColor = CanvasEditorTheme.destructive
        deleteButton.backgroundColor = CanvasEditorTheme.cardSurface
        deleteButton.layer.cornerRadius = 14
        deleteButton.layer.cornerCurve = .continuous
        deleteButton.accessibilityLabel = CanvasEditorUIRuntime.currentConfiguration.strings.deleteToolTitle
        deleteButton.addAction(UIAction { [weak self] _ in
            self?.onDeleteTapped?()
        }, for: .touchUpInside)
        addSubview(deleteButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.accent
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            previewContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            previewContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            previewContainerView.topAnchor.constraint(equalTo: topAnchor),
            previewContainerView.heightAnchor.constraint(equalToConstant: 116),

            previewImageView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor, constant: 16),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -16),
            previewImageView.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 14),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: -14),

            plusIconView.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            plusIconView.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
            plusIconView.widthAnchor.constraint(equalToConstant: 32),
            plusIconView.heightAnchor.constraint(equalToConstant: 32),

            deleteButton.topAnchor.constraint(equalTo: previewContainerView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateSelectionAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureAsNew() {
        representedSignatureID = nil
        onDeleteTapped = nil
        previewContainerView.backgroundColor = CanvasEditorTheme.canvasBackdrop
        previewImageView.image = nil
        previewImageView.isHidden = true
        plusIconView.image = UIImage(systemName: "plus.circle")
        plusIconView.isHidden = false
        deleteButton.isHidden = true
        titleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.signatureNewItemTitle
        titleLabel.isHidden = false
        titleLabel.textColor = CanvasEditorTheme.accent
        accessibilityLabel = CanvasEditorUIRuntime.currentConfiguration.strings.signatureNewItemTitle
    }

    func configure(signature: CanvasSignatureDescriptor, assetLoader: CanvasAssetLoader) {
        representedSignatureID = signature.id
        previewContainerView.backgroundColor = .white
        plusIconView.isHidden = true
        previewImageView.isHidden = false
        deleteButton.isHidden = false
        titleLabel.text = nil
        titleLabel.isHidden = true
        titleLabel.textColor = CanvasEditorTheme.primaryText
        accessibilityLabel = signature.name

        previewImageView.image = assetLoader.imageSynchronously(for: signature.source)
        assetLoader.image(for: signature.source) { [weak self] image in
            guard let self, self.representedSignatureID == signature.id else {
                return
            }
            self.previewImageView.image = image
        }
    }

    private func updateSelectionAppearance() {
        previewContainerView.layer.borderColor = isSelected
            ? CanvasEditorTheme.accent.cgColor
            : CanvasEditorTheme.separator.cgColor
    }
}
#endif
