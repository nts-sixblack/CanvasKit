import XCTest
@testable import CanvasKitCore

final class CanvasKitConfigurationTests: XCTestCase {
    func testTemplateLoaderLoadsBundledTemplates() {
        let templates = CanvasTemplateLoader.loadTemplates(configuration: .default)

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.contains(where: { $0.id == "square-vibes" }))
        XCTAssertTrue(templates.contains(where: { $0.id == "portrait-story" }))
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
        let features = CanvasEditorFeatures(enabledTools: [.addText, .export])

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
}
