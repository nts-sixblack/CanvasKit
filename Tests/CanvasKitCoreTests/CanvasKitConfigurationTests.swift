import XCTest
@testable import CanvasKitCore

final class CanvasKitConfigurationTests: XCTestCase {
    func testTemplateLoaderLoadsBundledTemplates() {
        let templates = CanvasTemplateLoader.loadTemplates(configuration: .default)

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.contains(where: { $0.id == "masked-frames" }))
        XCTAssertTrue(templates.contains(where: { $0.id == "square-vibes" }))
        XCTAssertTrue(templates.contains(where: { $0.id == "portrait-story" }))
    }

    func testMaskedFramesTemplateIncludesFilledAndEmptyMaskedSlots() throws {
        let templates = CanvasTemplateLoader.loadTemplates(configuration: .default)
        let template = try XCTUnwrap(templates.first(where: { $0.id == "masked-frames" }))
        let maskedNodes = template.nodes.filter { $0.kind == .maskedImage }
        let primaryNode = try XCTUnwrap(template.nodes.first(where: { $0.id == "masked-slot-primary" }))
        let secondaryNode = try XCTUnwrap(template.nodes.first(where: { $0.id == "masked-slot-secondary" }))

        XCTAssertEqual(template.version, 7)
        XCTAssertEqual(maskedNodes.count, 2)
        XCTAssertEqual(maskedNodes.filter { $0.source != nil }.count, 1)
        XCTAssertEqual(maskedNodes.filter { $0.source == nil }.count, 1)
        XCTAssertFalse(primaryNode.maskedImage?.deletesNodeOnDelete ?? true)
        XCTAssertTrue(secondaryNode.maskedImage?.deletesNodeOnDelete ?? false)
        XCTAssertEqual(
            template.nodes.first(where: { $0.id == "masked-title" })?.text,
            "Tap + to add a photo. Deleting the large frame clears its photo; deleting the small frame removes the slot."
        )
    }

    func testConfigurationLegacyAliasesStayInSync() {
        var configuration = CanvasEditorConfiguration.default

        configuration.fontCatalog = ["Avenir Next", "Georgia"]
        configuration.colorPalette = [.white, .black]
        configuration.stickerCatalog = [
            CanvasStickerDescriptor(
                id: "spark",
                name: "Spark",
                source: .symbol(named: "sparkles")
            )
        ]
        configuration.enabledTools = [.addText, .export]

        XCTAssertEqual(configuration.fonts.families, ["Avenir Next", "Georgia"])
        XCTAssertEqual(configuration.colors, [.white, .black])
        XCTAssertEqual(configuration.stickers.count, 1)
        XCTAssertEqual(configuration.features.enabledTools, [.addText, .export])
    }

    func testConfigSubtypesRoundTripThroughJSON() throws {
        let theme = CanvasEditorTheme()
        let strings = CanvasEditorStrings()
        let icons = CanvasEditorIconSet()
        let layout = CanvasEditorLayout()
        let features = CanvasEditorFeatures(
            enabledTools: [.addText, .export],
            allowsColorPicker: false,
            allowsLayerReordering: false,
            showsEmbeddedLayersButton: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(CanvasEditorTheme.self, from: encoder.encode(theme)),
            theme
        )
        XCTAssertEqual(
            try decoder.decode(CanvasEditorStrings.self, from: encoder.encode(strings)),
            strings
        )
        XCTAssertEqual(
            try decoder.decode(CanvasEditorIconSet.self, from: encoder.encode(icons)),
            icons
        )
        XCTAssertEqual(
            try decoder.decode(CanvasEditorLayout.self, from: encoder.encode(layout)),
            layout
        )
        XCTAssertEqual(
            try decoder.decode(CanvasEditorFeatures.self, from: encoder.encode(features)),
            features
        )
    }

    func testFeaturesDecodeLegacyJSONWithEmbeddedLayersButtonDefaultingToTrue() throws {
        let legacyJSON = """
        {
          "enabledTools": ["addText", "export"],
          "allowsColorPicker": true,
          "allowsLayerReordering": false
        }
        """.data(using: .utf8)!

        let features = try JSONDecoder().decode(CanvasEditorFeatures.self, from: legacyJSON)

        XCTAssertEqual(features.enabledTools, [.addText, .export])
        XCTAssertTrue(features.allowsColorPicker)
        XCTAssertFalse(features.allowsLayerReordering)
        XCTAssertTrue(features.showsEmbeddedLayersButton)
    }

    func testSignatureToolIsAvailableInToolCatalog() {
        XCTAssertTrue(CanvasEditorTool.allCases.contains(.addSignature))
    }

    func testSignatureConfigurationDefaults() {
        let signatures = CanvasSignatureConfiguration()

        XCTAssertNil(signatures.store)
        XCTAssertEqual(signatures.defaultColor, .black)
        XCTAssertEqual(signatures.defaultLineWidth, 4)
        XCTAssertEqual(signatures.lineWidthRange, 1...24)
        XCTAssertNil(signatures.palette)
    }
}
