import CanvasKitCore

enum CanvasKitExampleConfiguration {
    static func makeEditorConfiguration() -> CanvasEditorConfiguration {
        var configuration = CanvasEditorConfiguration.default

        configuration.fonts = CanvasFontCatalog(
            families: [
                "Avenir Next",
                "Georgia",
                "Helvetica Neue"
            ]
        )

        configuration.colors = [
            CanvasColor(hex: "F7F4EF"),
            CanvasColor(hex: "231F20"),
            CanvasColor(hex: "006C67"),
            CanvasColor(hex: "F28F3B"),
            CanvasColor(hex: "3A86FF"),
            CanvasColor(hex: "7A3E65")
        ]

        configuration.features.enabledTools = [
            .addText,
            .addEmoji,
            .addSticker,
            .addImage,
            .filter,
            .addSignature,
            .addBrush,
            .duplicate,
            .delete,
            .undo,
            .redo,
            .export
        ]

        configuration.signatures = CanvasSignatureConfiguration(
            store: CanvasKitExampleSignatureStore.shared,
            defaultColor: .black,
            defaultLineWidth: 4
        )

        configuration.theme = CanvasEditorTheme(
            canvasBackdropColor: CanvasColor(hex: "FFFFFF"),
            sheetSurfaceColor: CanvasColor(hex: "F8F3EE"),
            cardSurfaceColor: .white,
            primaryTextColor: CanvasColor(hex: "1F2933"),
            secondaryTextColor: CanvasColor(hex: "52606D"),
            accentColor: CanvasColor(hex: "006C67"),
            accentMutedColor: CanvasColor(hex: "006C67", alpha: 0.14),
            toolbarLabelFont: .init(familyName: "Avenir Next", pointSize: 14, weight: .semibold),
            sheetTitleFont: .init(familyName: "Avenir Next", pointSize: 17, weight: .heavy),
            inspectorTitleFont: .init(familyName: "Avenir Next", pointSize: 18, weight: .heavy),
            layerTitleFont: .init(familyName: "Avenir Next", pointSize: 14, weight: .bold),
            layerPreviewFont: .init(familyName: "Avenir Next", pointSize: 15, weight: .heavy)
        )

        configuration.icons = CanvasEditorIconSet(
            addTextTool: "character.textbox",
            addEmojiTool: "face.smiling.inverse",
            addStickerTool: "seal.fill",
            addPhotoTool: "photo.stack",
            filterTool: "camera.filters",
            addSignatureTool: "signature",
            brushTool: "paintbrush.pointed.fill",
            duplicateTool: "square.on.square",
            layers: "square.3.stack.3d.top.filled",
            colorPickerFilled: "paintpalette.fill"
        )

        configuration.strings = CanvasEditorStrings(
            closeButtonTitle: "Done",
            exportButtonTitle: "Save",
            resumeProjectTitle: "Resume Draft",
            textInspectorTitle: "Typography",
            editContentButtonTitle: "Edit Copy",
            layerPanelTitle: "Stack"
        )

        return configuration
    }
}
