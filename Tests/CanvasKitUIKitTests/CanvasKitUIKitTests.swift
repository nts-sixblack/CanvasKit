#if canImport(UIKit)
import XCTest
import UIKit
@testable import CanvasKitCore
@testable import CanvasKitUIKit

final class CanvasKitUIKitTests: XCTestCase {
    func testNormalFilterReturnsOriginalImagePixels() {
        let baseImage = Self.sampleImage()
        let filteredImage = CanvasFilterProcessor.apply(.normal, to: baseImage)

        XCTAssertEqual(filteredImage.pngData(), baseImage.pngData())
    }

    func testPresetFilterProducesImageDifferentFromBase() {
        let baseImage = Self.sampleImage()
        let filteredImage = CanvasFilterProcessor.apply(.mono, to: baseImage)

        XCTAssertNotEqual(filteredImage.pngData(), baseImage.pngData())
    }

    func testEveryPresetWithImageFilteringProducesChangedImage() {
        let baseImage = Self.sampleImage()

        for preset in CanvasFilterPreset.allCases where preset.usesImageFiltering {
            let filteredImage = CanvasFilterProcessor.apply(preset, to: baseImage)

            XCTAssertEqual(filteredImage.size, baseImage.size, "Unexpected size for \(preset.rawValue)")
            XCTAssertNotEqual(
                filteredImage.pngData(),
                baseImage.pngData(),
                "Expected \(preset.rawValue) to change the rendered output"
            )
        }
    }

    func testRendererAppliesCanvasFilterToRenderedProject() {
        let project = CanvasProject(
            templateID: "filter-render",
            canvasSize: CanvasSize(width: 640, height: 640),
            background: .solid(.white),
            nodes: [
                CanvasNode(
                    kind: .image,
                    name: "Image",
                    transform: CanvasTransform(position: CanvasPoint(x: 320, y: 320)),
                    size: CanvasSize(width: 360, height: 240),
                    zIndex: 0,
                    source: .inlineImage(data: Self.sampleImage().pngData()!, mimeType: "image/png")
                )
            ],
            canvasFilter: .vibrant
        )
        let assetLoader = CanvasAssetLoader()

        let baseImage = CanvasEditorRenderer.renderBaseImage(project: project, assetLoader: assetLoader)
        let exportImage = CanvasEditorRenderer.render(project: project, assetLoader: assetLoader)

        XCTAssertNotEqual(exportImage.pngData(), baseImage.pngData())
    }

    private static func sampleImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 180))
        return renderer.image { context in
            UIColor(red: 0.96, green: 0.42, blue: 0.18, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 90, height: 180))

            UIColor(red: 0.12, green: 0.38, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(x: 90, y: 0, width: 90, height: 180))

            UIColor(red: 0.98, green: 0.84, blue: 0.20, alpha: 1).setFill()
            context.fill(CGRect(x: 36, y: 36, width: 108, height: 36))
        }
    }
}
#endif
