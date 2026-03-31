import Foundation

public enum CanvasEditorInput: Sendable {
    case template(CanvasTemplate)
    case project(CanvasProject)
}

public struct CanvasFontDescriptor: Codable, Hashable, Sendable {
    public var familyName: String?
    public var pointSize: Double
    public var weight: CanvasFontWeight
    public var isItalic: Bool
    public var usesMonospacedDigits: Bool

    public init(
        familyName: String? = nil,
        pointSize: Double,
        weight: CanvasFontWeight = .regular,
        isItalic: Bool = false,
        usesMonospacedDigits: Bool = false
    ) {
        self.familyName = familyName
        self.pointSize = pointSize
        self.weight = weight
        self.isItalic = isItalic
        self.usesMonospacedDigits = usesMonospacedDigits
    }
}

public struct CanvasFontCatalog {
    public var families: [String]
    public var bundledFontFiles: [String]

    public init(
        families: [String],
        bundledFontFiles: [String] = []
    ) {
        self.families = families
        self.bundledFontFiles = bundledFontFiles
    }
}

public struct CanvasTemplateCatalog {
    public var templates: [CanvasTemplate]
    public var bundledFileNames: [String]
    public var externalURLs: [URL]
    public var bundleSubdirectory: String?

    public init(
        templates: [CanvasTemplate] = [],
        bundledFileNames: [String] = [],
        externalURLs: [URL] = [],
        bundleSubdirectory: String? = "Templates"
    ) {
        self.templates = templates
        self.bundledFileNames = bundledFileNames
        self.externalURLs = externalURLs
        self.bundleSubdirectory = bundleSubdirectory
    }
}

public struct CanvasEditorFeatures: Codable, Hashable, Sendable {
    public var enabledTools: [CanvasEditorTool]
    public var allowsColorPicker: Bool
    public var allowsLayerReordering: Bool

    public init(
        enabledTools: [CanvasEditorTool] = CanvasEditorTool.allCases,
        allowsColorPicker: Bool = true,
        allowsLayerReordering: Bool = true
    ) {
        self.enabledTools = enabledTools
        self.allowsColorPicker = allowsColorPicker
        self.allowsLayerReordering = allowsLayerReordering
    }
}

@MainActor
public protocol CanvasSignatureStore: AnyObject {
    func loadSignatures() async throws -> [CanvasSignatureDescriptor]
    func saveSignature(_ signature: CanvasSignatureDescriptor) async throws -> CanvasSignatureDescriptor
    func deleteSignature(id: String) async throws
}

public struct CanvasSignatureConfiguration {
    public var store: CanvasSignatureStore?
    public var defaultColor: CanvasColor
    public var defaultLineWidth: Double
    public var lineWidthRange: ClosedRange<Double>
    public var palette: [CanvasColor]?

    public init(
        store: CanvasSignatureStore? = nil,
        defaultColor: CanvasColor = .black,
        defaultLineWidth: Double = 4,
        lineWidthRange: ClosedRange<Double> = 1...24,
        palette: [CanvasColor]? = nil
    ) {
        self.store = store
        self.defaultColor = defaultColor
        self.defaultLineWidth = min(max(defaultLineWidth, lineWidthRange.lowerBound), lineWidthRange.upperBound)
        self.lineWidthRange = lineWidthRange
        self.palette = palette
    }
}

public struct CanvasEditorTheme: Codable, Hashable, Sendable {
    public var canvasBackdropColor: CanvasColor
    public var sheetSurfaceColor: CanvasColor
    public var cardSurfaceColor: CanvasColor
    public var primaryTextColor: CanvasColor
    public var secondaryTextColor: CanvasColor
    public var tertiaryTextColor: CanvasColor
    public var separatorColor: CanvasColor
    public var accentColor: CanvasColor
    public var accentMutedColor: CanvasColor
    public var destructiveColor: CanvasColor
    public var successColor: CanvasColor
    public var scrimColor: CanvasColor
    public var controlShadowColor: CanvasColor
    public var surfaceShadowColor: CanvasColor
    public var selectionBorderColor: CanvasColor
    public var overlayHandleBackgroundColor: CanvasColor
    public var overlayHandleTintColor: CanvasColor
    public var overlayHandleShadowColor: CanvasColor
    public var placeholderBackgroundColor: CanvasColor
    public var placeholderBorderColor: CanvasColor
    public var placeholderTextColor: CanvasColor
    public var loadingOverlayDimColor: CanvasColor
    public var loadingOverlayTextColor: CanvasColor
    public var layerTextPreviewBackgroundColor: CanvasColor
    public var layerEmojiPreviewBackgroundColor: CanvasColor
    public var layerStickerPreviewBackgroundColor: CanvasColor
    public var layerImagePreviewBackgroundColor: CanvasColor
    public var layerShapePreviewBackgroundColor: CanvasColor
    public var alignmentSelectedTextColor: CanvasColor
    public var toolbarLabelFont: CanvasFontDescriptor
    public var sheetTitleFont: CanvasFontDescriptor
    public var sectionTitleFont: CanvasFontDescriptor
    public var bodyFont: CanvasFontDescriptor
    public var buttonFont: CanvasFontDescriptor
    public var inspectorTitleFont: CanvasFontDescriptor
    public var layerTitleFont: CanvasFontDescriptor
    public var layerPreviewFont: CanvasFontDescriptor
    public var loadingTitleFont: CanvasFontDescriptor
    public var valueFont: CanvasFontDescriptor

    public init(
        canvasBackdropColor: CanvasColor = CanvasColor(hex: "F3F4F8"),
        sheetSurfaceColor: CanvasColor = CanvasColor(hex: "F3F4F8"),
        cardSurfaceColor: CanvasColor = .white,
        primaryTextColor: CanvasColor = CanvasColor(red: 0.22, green: 0.24, blue: 0.31),
        secondaryTextColor: CanvasColor = CanvasColor(red: 0.54, green: 0.58, blue: 0.68),
        tertiaryTextColor: CanvasColor = CanvasColor(red: 0.68, green: 0.71, blue: 0.79),
        separatorColor: CanvasColor = CanvasColor(red: 0.87, green: 0.89, blue: 0.94),
        accentColor: CanvasColor = CanvasColor(red: 0.33, green: 0.52, blue: 0.96),
        accentMutedColor: CanvasColor = CanvasColor(red: 0.33, green: 0.52, blue: 0.96, alpha: 0.12),
        destructiveColor: CanvasColor = CanvasColor(red: 0.98, green: 0.23, blue: 0.28),
        successColor: CanvasColor = CanvasColor(red: 0.20, green: 0.74, blue: 0.32),
        scrimColor: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.6),
        controlShadowColor: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.08),
        surfaceShadowColor: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.12),
        selectionBorderColor: CanvasColor = .white,
        overlayHandleBackgroundColor: CanvasColor = .white,
        overlayHandleTintColor: CanvasColor = .black,
        overlayHandleShadowColor: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.25),
        placeholderBackgroundColor: CanvasColor = CanvasColor(red: 1, green: 1, blue: 1, alpha: 0.12),
        placeholderBorderColor: CanvasColor = CanvasColor(red: 1, green: 1, blue: 1, alpha: 0.30),
        placeholderTextColor: CanvasColor = CanvasColor(red: 1, green: 1, blue: 1, alpha: 0.80),
        loadingOverlayDimColor: CanvasColor = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.24),
        loadingOverlayTextColor: CanvasColor = .white,
        layerTextPreviewBackgroundColor: CanvasColor = CanvasColor(red: 0.99, green: 0.77, blue: 0.71),
        layerEmojiPreviewBackgroundColor: CanvasColor = CanvasColor(red: 1, green: 0.94, blue: 0.70),
        layerStickerPreviewBackgroundColor: CanvasColor = CanvasColor(red: 0.82, green: 0.92, blue: 1),
        layerImagePreviewBackgroundColor: CanvasColor = CanvasColor(hex: "F3F4F8"),
        layerShapePreviewBackgroundColor: CanvasColor = CanvasColor(red: 0.84, green: 0.96, blue: 0.88),
        alignmentSelectedTextColor: CanvasColor = .white,
        toolbarLabelFont: CanvasFontDescriptor = .init(pointSize: 14, weight: .medium),
        sheetTitleFont: CanvasFontDescriptor = .init(pointSize: 17, weight: .medium),
        sectionTitleFont: CanvasFontDescriptor = .init(pointSize: 12, weight: .semibold),
        bodyFont: CanvasFontDescriptor = .init(pointSize: 14, weight: .medium),
        buttonFont: CanvasFontDescriptor = .init(pointSize: 16, weight: .semibold),
        inspectorTitleFont: CanvasFontDescriptor = .init(pointSize: 18, weight: .bold),
        layerTitleFont: CanvasFontDescriptor = .init(pointSize: 14, weight: .semibold),
        layerPreviewFont: CanvasFontDescriptor = .init(pointSize: 15, weight: .bold),
        loadingTitleFont: CanvasFontDescriptor = .init(pointSize: 17, weight: .semibold),
        valueFont: CanvasFontDescriptor = .init(pointSize: 13, weight: .medium, usesMonospacedDigits: true)
    ) {
        self.canvasBackdropColor = canvasBackdropColor
        self.sheetSurfaceColor = sheetSurfaceColor
        self.cardSurfaceColor = cardSurfaceColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.tertiaryTextColor = tertiaryTextColor
        self.separatorColor = separatorColor
        self.accentColor = accentColor
        self.accentMutedColor = accentMutedColor
        self.destructiveColor = destructiveColor
        self.successColor = successColor
        self.scrimColor = scrimColor
        self.controlShadowColor = controlShadowColor
        self.surfaceShadowColor = surfaceShadowColor
        self.selectionBorderColor = selectionBorderColor
        self.overlayHandleBackgroundColor = overlayHandleBackgroundColor
        self.overlayHandleTintColor = overlayHandleTintColor
        self.overlayHandleShadowColor = overlayHandleShadowColor
        self.placeholderBackgroundColor = placeholderBackgroundColor
        self.placeholderBorderColor = placeholderBorderColor
        self.placeholderTextColor = placeholderTextColor
        self.loadingOverlayDimColor = loadingOverlayDimColor
        self.loadingOverlayTextColor = loadingOverlayTextColor
        self.layerTextPreviewBackgroundColor = layerTextPreviewBackgroundColor
        self.layerEmojiPreviewBackgroundColor = layerEmojiPreviewBackgroundColor
        self.layerStickerPreviewBackgroundColor = layerStickerPreviewBackgroundColor
        self.layerImagePreviewBackgroundColor = layerImagePreviewBackgroundColor
        self.layerShapePreviewBackgroundColor = layerShapePreviewBackgroundColor
        self.alignmentSelectedTextColor = alignmentSelectedTextColor
        self.toolbarLabelFont = toolbarLabelFont
        self.sheetTitleFont = sheetTitleFont
        self.sectionTitleFont = sectionTitleFont
        self.bodyFont = bodyFont
        self.buttonFont = buttonFont
        self.inspectorTitleFont = inspectorTitleFont
        self.layerTitleFont = layerTitleFont
        self.layerPreviewFont = layerPreviewFont
        self.loadingTitleFont = loadingTitleFont
        self.valueFont = valueFont
    }
}

public struct CanvasEditorIconSet: Codable, Hashable, Sendable {
    public var addTextTool: String
    public var addEmojiTool: String
    public var addStickerTool: String
    public var addPhotoTool: String
    public var addSignatureTool: String
    public var eraserTool: String
    public var brushTool: String
    public var duplicateTool: String
    public var deleteTool: String
    public var undo: String
    public var redo: String
    public var layers: String
    public var close: String
    public var confirm: String
    public var layerLocked: String
    public var layerUnlocked: String
    public var layerImage: String
    public var defaultSticker: String
    public var colorCheckmark: String
    public var colorCheckmarkCircle: String
    public var colorCircle: String
    public var colorPickerEmpty: String
    public var colorPickerFilled: String
    public var pickerSelectedBadge: String
    public var handleDelete: String
    public var handleResizeWidth: String
    public var handleResizeHeight: String
    public var handleTransform: String
    public var shapeBrush: String
    public var shapeLine: String
    public var shapeArrow: String
    public var shapeOval: String
    public var shapeRectangle: String

    public init(
        addTextTool: String = "textformat",
        addEmojiTool: String = "face.smiling",
        addStickerTool: String = "sparkles",
        addPhotoTool: String = "photo.on.rectangle",
        addSignatureTool: String = "signature",
        eraserTool: String = "eraser",
        brushTool: String = "paintbrush",
        duplicateTool: String = "plus.square.on.square",
        deleteTool: String = "trash",
        undo: String = "arrow.uturn.backward",
        redo: String = "arrow.uturn.forward",
        layers: String = "square.stack.3d.up.fill",
        close: String = "xmark",
        confirm: String = "checkmark",
        layerLocked: String = "lock.fill",
        layerUnlocked: String = "lock.open",
        layerImage: String = "photo",
        defaultSticker: String = "sparkles",
        colorCheckmark: String = "checkmark",
        colorCheckmarkCircle: String = "checkmark.circle.fill",
        colorCircle: String = "circle",
        colorPickerEmpty: String = "eyedropper.halffull",
        colorPickerFilled: String = "eyedropper.full",
        pickerSelectedBadge: String = "checkmark.circle.fill",
        handleDelete: String = "xmark",
        handleResizeWidth: String = "arrow.left.and.right",
        handleResizeHeight: String = "arrow.up.and.down",
        handleTransform: String = "arrow.up.left.and.arrow.down.right",
        shapeBrush: String = "paintbrush",
        shapeLine: String = "line.diagonal",
        shapeArrow: String = "arrow.up.right",
        shapeOval: String = "circle",
        shapeRectangle: String = "square"
    ) {
        self.addTextTool = addTextTool
        self.addEmojiTool = addEmojiTool
        self.addStickerTool = addStickerTool
        self.addPhotoTool = addPhotoTool
        self.addSignatureTool = addSignatureTool
        self.eraserTool = eraserTool
        self.brushTool = brushTool
        self.duplicateTool = duplicateTool
        self.deleteTool = deleteTool
        self.undo = undo
        self.redo = redo
        self.layers = layers
        self.close = close
        self.confirm = confirm
        self.layerLocked = layerLocked
        self.layerUnlocked = layerUnlocked
        self.layerImage = layerImage
        self.defaultSticker = defaultSticker
        self.colorCheckmark = colorCheckmark
        self.colorCheckmarkCircle = colorCheckmarkCircle
        self.colorCircle = colorCircle
        self.colorPickerEmpty = colorPickerEmpty
        self.colorPickerFilled = colorPickerFilled
        self.pickerSelectedBadge = pickerSelectedBadge
        self.handleDelete = handleDelete
        self.handleResizeWidth = handleResizeWidth
        self.handleResizeHeight = handleResizeHeight
        self.handleTransform = handleTransform
        self.shapeBrush = shapeBrush
        self.shapeLine = shapeLine
        self.shapeArrow = shapeArrow
        self.shapeOval = shapeOval
        self.shapeRectangle = shapeRectangle
    }
}

public struct CanvasEditorStrings: Codable, Hashable, Sendable {
    public var closeButtonTitle: String
    public var exportButtonTitle: String
    public var resumeProjectTitle: String
    public var errorAlertTitle: String
    public var okButtonTitle: String
    public var importingImageMessage: String
    public var exportingImageMessage: String
    public var importImageFailureMessage: String
    public var exportImageFailureMessage: String
    public var exportPNGFailureMessage: String
    public var addTextToolTitle: String
    public var addEmojiToolTitle: String
    public var addStickerToolTitle: String
    public var addPhotoToolTitle: String
    public var addSignatureToolTitle: String
    public var eraserToolTitle: String
    public var brushToolTitle: String
    public var duplicateToolTitle: String
    public var deleteToolTitle: String
    public var undoButtonTitle: String
    public var redoButtonTitle: String
    public var layersButtonTitle: String
    public var emojiPickerTitle: String
    public var stickerPickerTitle: String
    public var pickerSelectedTitle: String
    public var pickerTapToSelectMessage: String
    public var pickerAddButtonTitle: String
    public var pickerAddButtonCountFormat: String
    public var pickerEmptyEmojiMessage: String
    public var pickerEmptyStickerMessage: String
    public var textInspectorTitle: String
    public var editContentButtonTitle: String
    public var fontSectionTitle: String
    public var alignmentSectionTitle: String
    public var styleSectionTitle: String
    public var textColorSectionTitle: String
    public var backgroundSectionTitle: String
    public var shadowColorSectionTitle: String
    public var outlineColorSectionTitle: String
    public var fontSizeRowTitle: String
    public var letterSpacingRowTitle: String
    public var lineSpacingRowTitle: String
    public var opacityRowTitle: String
    public var italicToggleTitle: String
    public var shadowToggleTitle: String
    public var outlineToggleTitle: String
    public var brushInspectorTitle: String
    public var brushShapeSectionTitle: String
    public var brushColorSectionTitle: String
    public var brushSizeRowTitle: String
    public var brushOpacityRowTitle: String
    public var eraserInspectorTitle: String
    public var eraserSizeRowTitle: String
    public var layerPanelTitle: String
    public var layerTextFallbackTitle: String
    public var layerEmojiFallbackTitle: String
    public var layerStickerFallbackTitle: String
    public var layerImageFallbackTitle: String
    public var layerShapeFallbackTitle: String
    public var imagePlaceholderTitle: String
    public var imageLoadingTitle: String
    public var signatureEditorTitle: String
    public var signaturePlaceholderTitle: String
    public var signaturePlaceholderSubtitle: String
    public var signatureCancelButtonTitle: String
    public var signatureDoneButtonTitle: String
    public var signatureAddButtonTitle: String
    public var signatureNewItemTitle: String
    public var loadingSignaturesMessage: String
    public var savingSignatureMessage: String
    public var loadSignaturesFailureMessage: String
    public var saveSignatureFailureMessage: String
    public var deleteSignatureFailureMessage: String
    public var deleteSignatureConfirmationMessage: String
    public var pickerTextColorAccessibilityLabel: String
    public var pickerBackgroundColorAccessibilityLabel: String
    public var pickerShadowColorAccessibilityLabel: String
    public var pickerOutlineColorAccessibilityLabel: String
    public var clearBackgroundAccessibilityLabel: String

    public init(
        closeButtonTitle: String = "Close",
        exportButtonTitle: String = "Export",
        resumeProjectTitle: String = "Resume Project",
        errorAlertTitle: String = "Error",
        okButtonTitle: String = "OK",
        importingImageMessage: String = "Importing image...",
        exportingImageMessage: String = "Exporting image...",
        importImageFailureMessage: String = "Unable to import the selected image.",
        exportImageFailureMessage: String = "Unable to export the current canvas.",
        exportPNGFailureMessage: String = "Unable to encode PNG output.",
        addTextToolTitle: String = "Text",
        addEmojiToolTitle: String = "Emoji",
        addStickerToolTitle: String = "Sticker",
        addPhotoToolTitle: String = "Photo",
        addSignatureToolTitle: String = "Signature",
        eraserToolTitle: String = "Eraser",
        brushToolTitle: String = "Brush",
        duplicateToolTitle: String = "Duplicate",
        deleteToolTitle: String = "Delete",
        undoButtonTitle: String = "Undo",
        redoButtonTitle: String = "Redo",
        layersButtonTitle: String = "Layers",
        emojiPickerTitle: String = "Emoji",
        stickerPickerTitle: String = "Sticker",
        pickerSelectedTitle: String = "Selected",
        pickerTapToSelectMessage: String = "Tap to select.",
        pickerAddButtonTitle: String = "Add",
        pickerAddButtonCountFormat: String = "Add %d",
        pickerEmptyEmojiMessage: String = "No emoji available.",
        pickerEmptyStickerMessage: String = "No sticker available.",
        textInspectorTitle: String = "Text Inspector",
        editContentButtonTitle: String = "Edit Content",
        fontSectionTitle: String = "Font",
        alignmentSectionTitle: String = "Alignment",
        styleSectionTitle: String = "Style",
        textColorSectionTitle: String = "Text Color",
        backgroundSectionTitle: String = "Background",
        shadowColorSectionTitle: String = "Shadow Color",
        outlineColorSectionTitle: String = "Outline Color",
        fontSizeRowTitle: String = "Font Size",
        letterSpacingRowTitle: String = "Letter Space",
        lineSpacingRowTitle: String = "Line Space",
        opacityRowTitle: String = "Opacity",
        italicToggleTitle: String = "Italic",
        shadowToggleTitle: String = "Shadow",
        outlineToggleTitle: String = "Outline",
        brushInspectorTitle: String = "Brush",
        brushShapeSectionTitle: String = "Shape",
        brushColorSectionTitle: String = "Color",
        brushSizeRowTitle: String = "Size",
        brushOpacityRowTitle: String = "Opacity",
        eraserInspectorTitle: String = "Eraser",
        eraserSizeRowTitle: String = "Size",
        layerPanelTitle: String = "Layers",
        layerTextFallbackTitle: String = "Text",
        layerEmojiFallbackTitle: String = "Emoji",
        layerStickerFallbackTitle: String = "Sticker",
        layerImageFallbackTitle: String = "Image",
        layerShapeFallbackTitle: String = "Shape",
        imagePlaceholderTitle: String = "Image",
        imageLoadingTitle: String = "Loading...",
        signatureEditorTitle: String = "Add New Signature",
        signaturePlaceholderTitle: String = "Sign here",
        signaturePlaceholderSubtitle: String = "Please sign formally and clearly",
        signatureCancelButtonTitle: String = "Cancel",
        signatureDoneButtonTitle: String = "Done",
        signatureAddButtonTitle: String = "Add",
        signatureNewItemTitle: String = "New",
        loadingSignaturesMessage: String = "Loading signatures...",
        savingSignatureMessage: String = "Saving signature...",
        loadSignaturesFailureMessage: String = "Unable to load signatures.",
        saveSignatureFailureMessage: String = "Unable to save signature.",
        deleteSignatureFailureMessage: String = "Unable to delete signature.",
        deleteSignatureConfirmationMessage: String = "Delete this signature?",
        pickerTextColorAccessibilityLabel: String = "Pick text color",
        pickerBackgroundColorAccessibilityLabel: String = "Pick background color",
        pickerShadowColorAccessibilityLabel: String = "Pick shadow color",
        pickerOutlineColorAccessibilityLabel: String = "Pick outline color",
        clearBackgroundAccessibilityLabel: String = "Clear background"
    ) {
        self.closeButtonTitle = closeButtonTitle
        self.exportButtonTitle = exportButtonTitle
        self.resumeProjectTitle = resumeProjectTitle
        self.errorAlertTitle = errorAlertTitle
        self.okButtonTitle = okButtonTitle
        self.importingImageMessage = importingImageMessage
        self.exportingImageMessage = exportingImageMessage
        self.importImageFailureMessage = importImageFailureMessage
        self.exportImageFailureMessage = exportImageFailureMessage
        self.exportPNGFailureMessage = exportPNGFailureMessage
        self.addTextToolTitle = addTextToolTitle
        self.addEmojiToolTitle = addEmojiToolTitle
        self.addStickerToolTitle = addStickerToolTitle
        self.addPhotoToolTitle = addPhotoToolTitle
        self.addSignatureToolTitle = addSignatureToolTitle
        self.eraserToolTitle = eraserToolTitle
        self.brushToolTitle = brushToolTitle
        self.duplicateToolTitle = duplicateToolTitle
        self.deleteToolTitle = deleteToolTitle
        self.undoButtonTitle = undoButtonTitle
        self.redoButtonTitle = redoButtonTitle
        self.layersButtonTitle = layersButtonTitle
        self.emojiPickerTitle = emojiPickerTitle
        self.stickerPickerTitle = stickerPickerTitle
        self.pickerSelectedTitle = pickerSelectedTitle
        self.pickerTapToSelectMessage = pickerTapToSelectMessage
        self.pickerAddButtonTitle = pickerAddButtonTitle
        self.pickerAddButtonCountFormat = pickerAddButtonCountFormat
        self.pickerEmptyEmojiMessage = pickerEmptyEmojiMessage
        self.pickerEmptyStickerMessage = pickerEmptyStickerMessage
        self.textInspectorTitle = textInspectorTitle
        self.editContentButtonTitle = editContentButtonTitle
        self.fontSectionTitle = fontSectionTitle
        self.alignmentSectionTitle = alignmentSectionTitle
        self.styleSectionTitle = styleSectionTitle
        self.textColorSectionTitle = textColorSectionTitle
        self.backgroundSectionTitle = backgroundSectionTitle
        self.shadowColorSectionTitle = shadowColorSectionTitle
        self.outlineColorSectionTitle = outlineColorSectionTitle
        self.fontSizeRowTitle = fontSizeRowTitle
        self.letterSpacingRowTitle = letterSpacingRowTitle
        self.lineSpacingRowTitle = lineSpacingRowTitle
        self.opacityRowTitle = opacityRowTitle
        self.italicToggleTitle = italicToggleTitle
        self.shadowToggleTitle = shadowToggleTitle
        self.outlineToggleTitle = outlineToggleTitle
        self.brushInspectorTitle = brushInspectorTitle
        self.brushShapeSectionTitle = brushShapeSectionTitle
        self.brushColorSectionTitle = brushColorSectionTitle
        self.brushSizeRowTitle = brushSizeRowTitle
        self.brushOpacityRowTitle = brushOpacityRowTitle
        self.eraserInspectorTitle = eraserInspectorTitle
        self.eraserSizeRowTitle = eraserSizeRowTitle
        self.layerPanelTitle = layerPanelTitle
        self.layerTextFallbackTitle = layerTextFallbackTitle
        self.layerEmojiFallbackTitle = layerEmojiFallbackTitle
        self.layerStickerFallbackTitle = layerStickerFallbackTitle
        self.layerImageFallbackTitle = layerImageFallbackTitle
        self.layerShapeFallbackTitle = layerShapeFallbackTitle
        self.imagePlaceholderTitle = imagePlaceholderTitle
        self.imageLoadingTitle = imageLoadingTitle
        self.signatureEditorTitle = signatureEditorTitle
        self.signaturePlaceholderTitle = signaturePlaceholderTitle
        self.signaturePlaceholderSubtitle = signaturePlaceholderSubtitle
        self.signatureCancelButtonTitle = signatureCancelButtonTitle
        self.signatureDoneButtonTitle = signatureDoneButtonTitle
        self.signatureAddButtonTitle = signatureAddButtonTitle
        self.signatureNewItemTitle = signatureNewItemTitle
        self.loadingSignaturesMessage = loadingSignaturesMessage
        self.savingSignatureMessage = savingSignatureMessage
        self.loadSignaturesFailureMessage = loadSignaturesFailureMessage
        self.saveSignatureFailureMessage = saveSignatureFailureMessage
        self.deleteSignatureFailureMessage = deleteSignatureFailureMessage
        self.deleteSignatureConfirmationMessage = deleteSignatureConfirmationMessage
        self.pickerTextColorAccessibilityLabel = pickerTextColorAccessibilityLabel
        self.pickerBackgroundColorAccessibilityLabel = pickerBackgroundColorAccessibilityLabel
        self.pickerShadowColorAccessibilityLabel = pickerShadowColorAccessibilityLabel
        self.pickerOutlineColorAccessibilityLabel = pickerOutlineColorAccessibilityLabel
        self.clearBackgroundAccessibilityLabel = clearBackgroundAccessibilityLabel
    }
}

public struct CanvasEditorLayout: Codable, Hashable, Sendable {
    public var toolbarTileHeight: Double
    public var historyButtonSize: Double
    public var canvasToHistorySpacing: Double
    public var historyToBottomPanelSpacing: Double
    public var inspectorMaximumHeight: Double
    public var inspectorMinimumTopMargin: Double
    public var inspectorVisibleOffset: Double
    public var layerPanelHeaderHeight: Double
    public var layerPanelRowHeight: Double
    public var layerPanelBottomInset: Double
    public var layerPanelMinimumHeight: Double
    public var viewportPadding: Double
    public var textContentInset: Double
    public var selectionInset: Double
    public var selectionCornerRadius: Double
    public var overlayHandleSize: Double
    public var overlayHandleCornerRadius: Double
    public var cardCornerRadius: Double
    public var surfaceCornerRadius: Double
    public var floatingPanelCornerRadius: Double
    public var pickerSheetTopInset: Double

    public init(
        toolbarTileHeight: Double = 82,
        historyButtonSize: Double = 58,
        canvasToHistorySpacing: Double = 16,
        historyToBottomPanelSpacing: Double = 16,
        inspectorMaximumHeight: Double = 360,
        inspectorMinimumTopMargin: Double = 44,
        inspectorVisibleOffset: Double = 0,
        layerPanelHeaderHeight: Double = 52,
        layerPanelRowHeight: Double = 56,
        layerPanelBottomInset: Double = 10,
        layerPanelMinimumHeight: Double = 124,
        viewportPadding: Double = 28,
        textContentInset: Double = 8,
        selectionInset: Double = 18,
        selectionCornerRadius: Double = 22,
        overlayHandleSize: Double = 48,
        overlayHandleCornerRadius: Double = 24,
        cardCornerRadius: Double = 20,
        surfaceCornerRadius: Double = 28,
        floatingPanelCornerRadius: Double = 24,
        pickerSheetTopInset: Double = 96
    ) {
        self.toolbarTileHeight = toolbarTileHeight
        self.historyButtonSize = historyButtonSize
        self.canvasToHistorySpacing = canvasToHistorySpacing
        self.historyToBottomPanelSpacing = historyToBottomPanelSpacing
        self.inspectorMaximumHeight = inspectorMaximumHeight
        self.inspectorMinimumTopMargin = inspectorMinimumTopMargin
        self.inspectorVisibleOffset = inspectorVisibleOffset
        self.layerPanelHeaderHeight = layerPanelHeaderHeight
        self.layerPanelRowHeight = layerPanelRowHeight
        self.layerPanelBottomInset = layerPanelBottomInset
        self.layerPanelMinimumHeight = layerPanelMinimumHeight
        self.viewportPadding = viewportPadding
        self.textContentInset = textContentInset
        self.selectionInset = selectionInset
        self.selectionCornerRadius = selectionCornerRadius
        self.overlayHandleSize = overlayHandleSize
        self.overlayHandleCornerRadius = overlayHandleCornerRadius
        self.cardCornerRadius = cardCornerRadius
        self.surfaceCornerRadius = surfaceCornerRadius
        self.floatingPanelCornerRadius = floatingPanelCornerRadius
        self.pickerSheetTopInset = pickerSheetTopInset
    }
}

public struct CanvasEditorResources {
    public var assetBundles: [Bundle]
    public var templateBundles: [Bundle]
    public var fontBundles: [Bundle]

    public init(
        assetBundles: [Bundle]? = nil,
        templateBundles: [Bundle]? = nil,
        fontBundles: [Bundle]? = nil
    ) {
        self.assetBundles = assetBundles ?? Self.defaultAssetBundles
        self.templateBundles = templateBundles ?? Self.defaultTemplateBundles
        self.fontBundles = fontBundles ?? Self.defaultFontBundles
    }

    private static var defaultAssetBundles: [Bundle] { [Bundle.module, .main] }
    private static var defaultTemplateBundles: [Bundle] { [Bundle.module, .main] }
    private static var defaultFontBundles: [Bundle] { [Bundle.module, .main] }
}

public struct CanvasEditorConfiguration {
    public var fonts: CanvasFontCatalog
    public var stickers: [CanvasStickerDescriptor]
    public var signatures: CanvasSignatureConfiguration
    public var colors: [CanvasColor]
    public var exportMaxDimension: Double
    public var features: CanvasEditorFeatures
    public var theme: CanvasEditorTheme
    public var icons: CanvasEditorIconSet
    public var strings: CanvasEditorStrings
    public var layout: CanvasEditorLayout
    public var resources: CanvasEditorResources
    public var templates: CanvasTemplateCatalog

    public init(
        fonts: CanvasFontCatalog,
        stickers: [CanvasStickerDescriptor],
        signatures: CanvasSignatureConfiguration = .init(),
        colors: [CanvasColor],
        exportMaxDimension: Double = 2_048,
        features: CanvasEditorFeatures = .init(),
        theme: CanvasEditorTheme = .init(),
        icons: CanvasEditorIconSet = .init(),
        strings: CanvasEditorStrings = .init(),
        layout: CanvasEditorLayout = .init(),
        resources: CanvasEditorResources = .init(),
        templates: CanvasTemplateCatalog = .init()
    ) {
        self.fonts = fonts
        self.stickers = stickers
        self.signatures = signatures
        self.colors = colors
        self.exportMaxDimension = exportMaxDimension
        self.features = features
        self.theme = theme
        self.icons = icons
        self.strings = strings
        self.layout = layout
        self.resources = resources
        self.templates = templates
    }

    public var fontCatalog: [String] {
        get { fonts.families }
        set { fonts.families = newValue }
    }

    public var stickerCatalog: [CanvasStickerDescriptor] {
        get { stickers }
        set { stickers = newValue }
    }

    public var colorPalette: [CanvasColor] {
        get { colors }
        set { colors = newValue }
    }

    public var enabledTools: [CanvasEditorTool] {
        get { features.enabledTools }
        set { features.enabledTools = newValue }
    }
}

public extension CanvasEditorConfiguration {
    static var demo: CanvasEditorConfiguration {
        CanvasEditorConfiguration(
            fonts: CanvasFontCatalog(
                families: [
                    "Avenir Next",
                    "Helvetica Neue",
                    "Georgia",
                    "Marker Felt",
                    "Futura"
                ]
            ),
            stickers: [
                CanvasStickerDescriptor(id: "sparkles", name: "Sparkles", source: .symbol(named: "sparkles")),
                CanvasStickerDescriptor(id: "star", name: "Star", source: .symbol(named: "star.fill")),
                CanvasStickerDescriptor(id: "heart", name: "Heart", source: .symbol(named: "heart.fill")),
                CanvasStickerDescriptor(id: "flash", name: "Flash", source: .symbol(named: "bolt.fill")),
                CanvasStickerDescriptor(id: "moon", name: "Moon", source: .symbol(named: "moon.stars.fill"))
            ],
            colors: [
                .white,
                .black,
                .accent,
                .sky,
                .mint,
                .sunflower,
                .plum
            ],
            templates: CanvasTemplateCatalog(
                bundledFileNames: [
                    "Poster45",
                    "PortraitStory",
                    "SquareVibes"
                ]
            )
        )
    }

    static var `default`: CanvasEditorConfiguration {
        .demo
    }
}
