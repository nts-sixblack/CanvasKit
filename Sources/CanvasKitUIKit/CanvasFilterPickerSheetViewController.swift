#if canImport(UIKit)
import UIKit
import CanvasKitCore

@MainActor
final class CanvasFilterPickerSheetViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum Layout {
        static let hiddenSheetOffset: CGFloat = 420
        static let sheetHeight: CGFloat = 334
        static let thumbnailSize = CGSize(width: 86, height: 116)
        static let itemSpacing: CGFloat = 14
        static let horizontalInset: CGFloat = 24
    }

    private let presets: [CanvasFilterPreset]
    private let basePreviewImage: UIImage
    private let onSelectionChanged: (CanvasFilterPreset) -> Void
    private let onCancel: () -> Void
    private let onDone: (CanvasFilterPreset) -> Void

    private let scrimView = UIControl()
    private let sheetContainerView = UIView()
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    private var thumbnails: [CanvasFilterPreset: UIImage] = [:]
    private var sheetBottomConstraint: NSLayoutConstraint?
    private var hasAnimatedPresentation = false
    private var thumbnailGenerationToken = UUID()

    private var selectedPreset: CanvasFilterPreset {
        didSet {
            guard selectedPreset != oldValue else {
                return
            }
            collectionView.reloadData()
            scrollToSelectedPreset(animated: true)
            onSelectionChanged(selectedPreset)
        }
    }

    init(
        selectedPreset: CanvasFilterPreset,
        basePreviewImage: UIImage,
        presets: [CanvasFilterPreset] = CanvasFilterPreset.allCases,
        onSelectionChanged: @escaping (CanvasFilterPreset) -> Void,
        onCancel: @escaping () -> Void,
        onDone: @escaping (CanvasFilterPreset) -> Void
    ) {
        self.selectedPreset = selectedPreset
        self.basePreviewImage = basePreviewImage
        self.presets = presets
        self.onSelectionChanged = onSelectionChanged
        self.onCancel = onCancel
        self.onDone = onDone

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = Layout.itemSpacing
        layout.minimumLineSpacing = Layout.itemSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Layout.horizontalInset,
            bottom: 0,
            right: Layout.horizontalInset
        )
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

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
        generateThumbnails()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedPresentation else {
            return
        }

        hasAnimatedPresentation = true
        scrollToSelectedPreset(animated: false)
        animateSheet(isPresenting: true, completion: nil)
    }

    private func configurePresentation() {
        view.backgroundColor = .clear
        thumbnails[.normal] = basePreviewImage
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

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = CanvasEditorUIRuntime.currentConfiguration.strings.filterSheetTitle
        titleLabel.textColor = CanvasEditorTheme.secondaryText
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.sheetTitleFont.resolvedUIFont()
        titleLabel.textAlignment = .center

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CanvasFilterPickerCell.self, forCellWithReuseIdentifier: CanvasFilterPickerCell.reuseIdentifier)

        configureFooterButton(
            cancelButton,
            title: CanvasEditorUIRuntime.currentConfiguration.strings.filterCancelButtonTitle,
            action: #selector(cancelTapped)
        )
        configureFooterButton(
            doneButton,
            title: CanvasEditorUIRuntime.currentConfiguration.strings.filterDoneButtonTitle,
            action: #selector(doneTapped)
        )

        [titleLabel, collectionView, cancelButton, doneButton].forEach(sheetContainerView.addSubview)

        sheetBottomConstraint = sheetContainerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: Layout.hiddenSheetOffset
        )
        sheetBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.topAnchor.constraint(equalTo: view.topAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetContainerView.heightAnchor.constraint(equalToConstant: Layout.sheetHeight),

            titleLabel.topAnchor.constraint(equalTo: sheetContainerView.topAnchor, constant: 26),
            titleLabel.centerXAnchor.constraint(equalTo: sheetContainerView.centerXAnchor),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),
            collectionView.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: Layout.thumbnailSize.height + 48),

            cancelButton.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor, constant: 32),
            cancelButton.bottomAnchor.constraint(equalTo: sheetContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -22),

            doneButton.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor, constant: -32),
            doneButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor)
        ])
    }

    private func configureFooterButton(_ button: UIButton, title: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .plain()
        button.configuration?.title = title
        button.configuration?.baseForegroundColor = CanvasEditorTheme.primaryText
        button.titleLabel?.font = CanvasEditorUIRuntime.currentConfiguration.theme.inspectorTitleFont.resolvedUIFont()
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func scrollToSelectedPreset(animated: Bool) {
        guard let index = presets.firstIndex(of: selectedPreset) else {
            return
        }

        collectionView.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )
    }

    private func generateThumbnails() {
        let token = UUID()
        thumbnailGenerationToken = token
        let presets = self.presets
        let basePreviewImage = self.basePreviewImage

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let renderedThumbnails = presets.reduce(into: [CanvasFilterPreset: UIImage]()) { partialResult, preset in
                partialResult[preset] = CanvasFilterProcessor.apply(preset, to: basePreviewImage)
            }

            Task { @MainActor [weak self] in
                guard let self, self.thumbnailGenerationToken == token else {
                    return
                }
                self.thumbnails.merge(renderedThumbnails, uniquingKeysWith: { _, new in new })
                self.collectionView.reloadData()
                self.scrollToSelectedPreset(animated: false)
            }
        }
    }

    private func animateSheet(isPresenting: Bool, completion: (() -> Void)?) {
        sheetBottomConstraint?.constant = isPresenting ? 0 : Layout.hiddenSheetOffset

        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.scrimView.alpha = isPresenting ? 1 : 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            if !isPresenting {
                self.dismiss(animated: false, completion: completion)
            } else {
                completion?()
            }
        }
    }

    @objc
    private func cancelTapped() {
        onCancel()
        animateSheet(isPresenting: false, completion: nil)
    }

    @objc
    private func doneTapped() {
        let preset = selectedPreset
        animateSheet(isPresenting: false) { [onDone] in
            onDone(preset)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        presets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CanvasFilterPickerCell.reuseIdentifier,
            for: indexPath
        ) as? CanvasFilterPickerCell else {
            return UICollectionViewCell()
        }

        let preset = presets[indexPath.item]
        let image = thumbnails[preset] ?? basePreviewImage
        cell.configure(
            preset: preset,
            image: image,
            isSelected: preset == selectedPreset
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedPreset = presets[indexPath.item]
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: Layout.thumbnailSize.width, height: Layout.thumbnailSize.height + 36)
    }
}

private final class CanvasFilterPickerCell: UICollectionViewCell {
    static let reuseIdentifier = "CanvasFilterPickerCell"

    private let thumbnailContainerView = UIView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        thumbnailContainerView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainerView.applyCanvasEditorCardStyle(
            backgroundColor: CanvasEditorTheme.cardSurface,
            cornerRadius: 18,
            borderColor: CanvasEditorTheme.separator,
            shadowColor: CanvasEditorTheme.controlShadow,
            shadowOpacity: 1,
            shadowRadius: 12,
            shadowOffset: CGSize(width: 0, height: 6)
        )

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 14
        thumbnailImageView.layer.cornerCurve = .continuous

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = CanvasEditorUIRuntime.currentConfiguration.theme.bodyFont.resolvedUIFont()
        titleLabel.textColor = CanvasEditorTheme.secondaryText
        titleLabel.numberOfLines = 2

        contentView.addSubview(thumbnailContainerView)
        thumbnailContainerView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            thumbnailContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            thumbnailContainerView.widthAnchor.constraint(equalToConstant: 86),
            thumbnailContainerView.heightAnchor.constraint(equalToConstant: 116),

            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailContainerView.topAnchor, constant: 6),
            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailContainerView.leadingAnchor, constant: 6),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailContainerView.trailingAnchor, constant: -6),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor, constant: -6),

            titleLabel.topAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    func configure(preset: CanvasFilterPreset, image: UIImage, isSelected: Bool) {
        thumbnailImageView.image = image
        titleLabel.text = preset.displayTitle
        accessibilityLabel = preset.displayTitle
        self.isSelected = isSelected
        updateSelectionAppearance()
    }

    private func updateSelectionAppearance() {
        thumbnailContainerView.layer.borderColor = (isSelected ? CanvasEditorTheme.accent : CanvasEditorTheme.separator).cgColor
        thumbnailContainerView.layer.borderWidth = isSelected ? 2 : 1
        titleLabel.textColor = isSelected ? CanvasEditorTheme.primaryText : CanvasEditorTheme.secondaryText
    }
}
#endif
