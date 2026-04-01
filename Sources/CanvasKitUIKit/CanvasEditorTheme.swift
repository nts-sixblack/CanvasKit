#if canImport(UIKit)
import UIKit
import CanvasKitCore

@MainActor
enum CanvasEditorUIRuntime {
    static var currentConfiguration: CanvasEditorConfiguration = .default
}

@MainActor
extension CanvasEditorTheme {
    var canvasBackdrop: UIColor { canvasBackdropColor.uiColor }
    var sheetSurface: UIColor { sheetSurfaceColor.uiColor }
    var cardSurface: UIColor { cardSurfaceColor.uiColor }
    var primaryText: UIColor { primaryTextColor.uiColor }
    var secondaryText: UIColor { secondaryTextColor.uiColor }
    var tertiaryText: UIColor { tertiaryTextColor.uiColor }
    var separator: UIColor { separatorColor.uiColor }
    var accent: UIColor { accentColor.uiColor }
    var accentMuted: UIColor { accentMutedColor.uiColor }
    var destructive: UIColor { destructiveColor.uiColor }
    var success: UIColor { successColor.uiColor }
    var scrim: UIColor { scrimColor.uiColor }
    var controlShadow: UIColor { controlShadowColor.uiColor }
    var surfaceShadow: UIColor { surfaceShadowColor.uiColor }
    var selectionBorder: UIColor { selectionBorderColor.uiColor }
    var overlayHandleBackground: UIColor { overlayHandleBackgroundColor.uiColor }
    var overlayHandleTint: UIColor { overlayHandleTintColor.uiColor }
    var overlayHandleShadow: UIColor { overlayHandleShadowColor.uiColor }
    var placeholderBackground: UIColor { placeholderBackgroundColor.uiColor }
    var placeholderBorder: UIColor { placeholderBorderColor.uiColor }
    var placeholderText: UIColor { placeholderTextColor.uiColor }
    var maskedImageEditingBackground: UIColor { maskedImageEditingBackgroundColor.uiColor }
    var loadingOverlayDim: UIColor { loadingOverlayDimColor.uiColor }
    var loadingOverlayText: UIColor { loadingOverlayTextColor.uiColor }
    var layerTextPreviewBackground: UIColor { layerTextPreviewBackgroundColor.uiColor }
    var layerEmojiPreviewBackground: UIColor { layerEmojiPreviewBackgroundColor.uiColor }
    var layerStickerPreviewBackground: UIColor { layerStickerPreviewBackgroundColor.uiColor }
    var layerImagePreviewBackground: UIColor { layerImagePreviewBackgroundColor.uiColor }
    var layerShapePreviewBackground: UIColor { layerShapePreviewBackgroundColor.uiColor }
    var alignmentSelectedText: UIColor { alignmentSelectedTextColor.uiColor }
}

@MainActor
extension CanvasEditorTheme {
    static var current: CanvasEditorTheme {
        CanvasEditorUIRuntime.currentConfiguration.theme
    }

    static var canvasBackdrop: UIColor { current.canvasBackdrop }
    static var sheetSurface: UIColor { current.sheetSurface }
    static var cardSurface: UIColor { current.cardSurface }
    static var primaryText: UIColor { current.primaryText }
    static var secondaryText: UIColor { current.secondaryText }
    static var tertiaryText: UIColor { current.tertiaryText }
    static var separator: UIColor { current.separator }
    static var accent: UIColor { current.accent }
    static var accentMuted: UIColor { current.accentMuted }
    static var destructive: UIColor { current.destructive }
    static var success: UIColor { current.success }
    static var scrim: UIColor { current.scrim }
    static var controlShadow: UIColor { current.controlShadow }
    static var surfaceShadow: UIColor { current.surfaceShadow }
    static var selectionBorder: UIColor { current.selectionBorder }
    static var overlayHandleBackground: UIColor { current.overlayHandleBackground }
    static var overlayHandleTint: UIColor { current.overlayHandleTint }
    static var overlayHandleShadow: UIColor { current.overlayHandleShadow }
    static var placeholderBackground: UIColor { current.placeholderBackground }
    static var placeholderBorder: UIColor { current.placeholderBorder }
    static var placeholderText: UIColor { current.placeholderText }
    static var maskedImageEditingBackground: UIColor { current.maskedImageEditingBackground }
    static var loadingOverlayDim: UIColor { current.loadingOverlayDim }
    static var loadingOverlayText: UIColor { current.loadingOverlayText }
    static var layerTextPreviewBackground: UIColor { current.layerTextPreviewBackground }
    static var layerEmojiPreviewBackground: UIColor { current.layerEmojiPreviewBackground }
    static var layerStickerPreviewBackground: UIColor { current.layerStickerPreviewBackground }
    static var layerImagePreviewBackground: UIColor { current.layerImagePreviewBackground }
    static var layerShapePreviewBackground: UIColor { current.layerShapePreviewBackground }
    static var alignmentSelectedText: UIColor { current.alignmentSelectedText }
}

extension CanvasFontDescriptor {
    func resolvedUIFont() -> UIFont {
        let pointSize = CGFloat(pointSize)
        let baseFont: UIFont

        if let familyName,
           let resolved = Self.resolveCustomFont(
               familyName: familyName,
               pointSize: pointSize,
               weight: weight
           ) {
            baseFont = resolved
        } else if usesMonospacedDigits {
            baseFont = UIFont.monospacedDigitSystemFont(
                ofSize: pointSize,
                weight: weight.uiFontWeight
            )
        } else {
            baseFont = UIFont.systemFont(
                ofSize: pointSize,
                weight: weight.uiFontWeight
            )
        }

        guard isItalic else {
            return baseFont
        }

        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(
            baseFont.fontDescriptor.symbolicTraits.union(.traitItalic)
        ) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }

        return baseFont
    }

    private static func resolveCustomFont(
        familyName: String,
        pointSize: CGFloat,
        weight: CanvasFontWeight
    ) -> UIFont? {
        let familyFonts = UIFont.fontNames(forFamilyName: familyName)
        if let matchedFontName = bestMatchingFontName(
            in: familyFonts,
            weight: weight
        ),
           let font = UIFont(name: matchedFontName, size: pointSize) {
            return font
        }

        return UIFont(name: familyName, size: pointSize)
    }

    private static func bestMatchingFontName(
        in fontNames: [String],
        weight: CanvasFontWeight
    ) -> String? {
        guard !fontNames.isEmpty else {
            return nil
        }

        let weightKeywords: [String]
        switch weight {
        case .regular:
            weightKeywords = ["regular", "book", "roman"]
        case .medium:
            weightKeywords = ["medium"]
        case .semibold:
            weightKeywords = ["semibold", "demi"]
        case .bold:
            weightKeywords = ["bold"]
        case .heavy:
            weightKeywords = ["heavy", "black", "ultra"]
        }

        return fontNames.first { fontName in
            let lowercase = fontName.lowercased()
            return weightKeywords.contains { lowercase.contains($0) }
        } ?? fontNames.first
    }
}

extension CanvasEditorIconSet {
    func systemImageName(for shapeType: CanvasShapeType) -> String {
        switch shapeType {
        case .brush:
            return shapeBrush
        case .line:
            return shapeLine
        case .arrow:
            return shapeArrow
        case .oval:
            return shapeOval
        case .rectangle:
            return shapeRectangle
        }
    }
}

extension UIView {
    func applyCanvasEditorCardStyle(
        backgroundColor: UIColor,
        cornerRadius: CGFloat,
        borderColor: UIColor,
        borderWidth: CGFloat = 1,
        shadowColor: UIColor,
        shadowOpacity: Float = 1,
        shadowRadius: CGFloat = 14,
        shadowOffset: CGSize = CGSize(width: 0, height: 8)
    ) {
        self.backgroundColor = backgroundColor
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = shadowOffset
    }
}
#endif
