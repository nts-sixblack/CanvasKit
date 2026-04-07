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

    func testMaskedImageRendererClipsPixelsOutsideMask() {
        let contentImage = Self.solidImage(color: .red, size: CGSize(width: 120, height: 120))
        let maskImage = Self.leftHalfMaskImage(size: CGSize(width: 120, height: 120))
        let assetLoader = CanvasAssetLoader()
        let project = CanvasProject(
            templateID: "masked-render",
            canvasSize: CanvasSize(width: 120, height: 120),
            background: .solid(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)),
            nodes: [
                CanvasNode(
                    kind: .maskedImage,
                    name: "Masked",
                    transform: CanvasTransform(position: CanvasPoint(x: 60, y: 60)),
                    size: CanvasSize(width: 120, height: 120),
                    zIndex: 0,
                    source: .inlineImage(data: contentImage.pngData()!, mimeType: "image/png"),
                    maskedImage: CanvasMaskedImagePayload(
                        maskSource: .inlineImage(data: maskImage.pngData()!, mimeType: "image/png")
                    )
                )
            ]
        )

        let renderedImage = CanvasEditorRenderer.renderBaseImage(project: project, assetLoader: assetLoader)

        XCTAssertEqual(Self.pixel(in: renderedImage, x: 24, y: 60).a, 255)
        XCTAssertEqual(Self.pixel(in: renderedImage, x: 96, y: 60).a, 0)
    }

    func testMaskedImageRendererContentTransformChangesOutput() {
        let contentImage = Self.splitImage(
            leftColor: UIColor(red: 0.96, green: 0.42, blue: 0.18, alpha: 1),
            rightColor: UIColor(red: 0.12, green: 0.38, blue: 0.94, alpha: 1),
            size: CGSize(width: 140, height: 140)
        )
        let opaqueMask = Self.opaqueMaskImage(size: CGSize(width: 120, height: 120))
        let assetLoader = CanvasAssetLoader()
        let defaultNode = CanvasNode(
            kind: .maskedImage,
            name: "Masked",
            transform: CanvasTransform(position: CanvasPoint(x: 60, y: 60)),
            size: CanvasSize(width: 120, height: 120),
            zIndex: 0,
            source: .inlineImage(data: contentImage.pngData()!, mimeType: "image/png"),
            maskedImage: CanvasMaskedImagePayload(
                maskSource: .inlineImage(data: opaqueMask.pngData()!, mimeType: "image/png")
            )
        )
        var transformedNode = defaultNode
        transformedNode.maskedImage?.contentTransform = CanvasMaskedImageContentTransform(
            offset: CanvasPoint(x: 18, y: -12),
            rotation: 0.35,
            scale: 1.2
        )

        let defaultImage = CanvasEditorRenderer.renderBaseImage(
            project: CanvasProject(
                templateID: "masked-default",
                canvasSize: CanvasSize(width: 120, height: 120),
                background: .solid(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)),
                nodes: [defaultNode]
            ),
            assetLoader: assetLoader
        )
        let transformedImage = CanvasEditorRenderer.renderBaseImage(
            project: CanvasProject(
                templateID: "masked-transformed",
                canvasSize: CanvasSize(width: 120, height: 120),
                background: .solid(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)),
                nodes: [transformedNode]
            ),
            assetLoader: assetLoader
        )

        XCTAssertNotEqual(defaultImage.pngData(), transformedImage.pngData())
    }

    func testMaskedImageRendererClipsTransformedContentToOpaqueMaskBounds() {
        let contentImage = Self.solidImage(
            color: UIColor(red: 0.18, green: 0.58, blue: 0.92, alpha: 1),
            size: CGSize(width: 160, height: 160)
        )
        let opaqueMask = Self.opaqueMaskImage(size: CGSize(width: 80, height: 80))
        let assetLoader = CanvasAssetLoader()
        let project = CanvasProject(
            templateID: "masked-opaque-clip",
            canvasSize: CanvasSize(width: 160, height: 160),
            background: .solid(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)),
            nodes: [
                CanvasNode(
                    kind: .maskedImage,
                    name: "Masked",
                    transform: CanvasTransform(position: CanvasPoint(x: 80, y: 80)),
                    size: CanvasSize(width: 80, height: 80),
                    zIndex: 0,
                    source: .inlineImage(data: contentImage.pngData()!, mimeType: "image/png"),
                    maskedImage: CanvasMaskedImagePayload(
                        maskSource: .inlineImage(data: opaqueMask.pngData()!, mimeType: "image/png"),
                        contentTransform: CanvasMaskedImageContentTransform(
                            offset: CanvasPoint(x: 0, y: 0),
                            rotation: .pi / 4,
                            scale: 1.6
                        )
                    )
                )
            ]
        )

        let renderedImage = CanvasEditorRenderer.renderBaseImage(project: project, assetLoader: assetLoader)

        XCTAssertEqual(Self.pixel(in: renderedImage, x: 80, y: 80).a, 255)
        XCTAssertEqual(Self.pixel(in: renderedImage, x: 20, y: 20).a, 0)
        XCTAssertEqual(Self.pixel(in: renderedImage, x: 140, y: 140).a, 0)
    }

    func testMaskedImageRendererMatchesNodeViewSnapshotForBundledMask() {
        let assetLoader = CanvasAssetLoader()
        let contentImage = Self.quadrantImage(size: CGSize(width: 320, height: 420))
        let contentSource = assetLoader.inlineSource(from: contentImage)!
        let node = CanvasNode(
            kind: .maskedImage,
            name: "Masked",
            transform: CanvasTransform(position: CanvasPoint(x: 239, y: 356)),
            size: CanvasSize(width: 478, height: 712),
            zIndex: 0,
            source: contentSource,
            maskedImage: CanvasMaskedImagePayload(
                maskSource: .bundleImage(named: "theme-mask-1"),
                contentTransform: CanvasMaskedImageContentTransform(
                    offset: CanvasPoint(x: -34, y: 58),
                    rotation: .pi / 7,
                    scale: 1.34
                )
            )
        )

        let rendererImage = CanvasEditorRenderer.renderBaseImage(
            project: CanvasProject(
                templateID: "bundled-mask-match",
                canvasSize: CanvasSize(width: 478, height: 712),
                background: .solid(CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)),
                nodes: [node]
            ),
            assetLoader: assetLoader
        )

        let view = CanvasNodeView(frame: CGRect(origin: .zero, size: node.size.cgSize))
        view.apply(node: node, assetLoader: assetLoader)
        view.layoutIfNeeded()
        let viewImage = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
            view.layer.render(in: context.cgContext)
        }

        XCTAssertEqual(
            Self.pixel(in: rendererImage, x: 180, y: 180),
            Self.pixel(in: viewImage, x: 180, y: 180)
        )
        XCTAssertEqual(
            Self.pixel(in: rendererImage, x: 420, y: 560),
            Self.pixel(in: viewImage, x: 420, y: 560)
        )
        XCTAssertEqual(
            Self.pixel(in: rendererImage, x: 130, y: 640),
            Self.pixel(in: viewImage, x: 130, y: 640)
        )
    }

    func testBundleMaskedFrameAssetsLoadFromPackageResources() {
        let assetLoader = CanvasAssetLoader()

        XCTAssertNotNil(assetLoader.imageSynchronously(for: .bundleImage(named: "theme-mask-1")))
        XCTAssertNotNil(assetLoader.imageSynchronously(for: .bundleImage(named: "theme-mask-2")))
    }

    func testMaskedImageEmptyPlaceholderShowsPlusAffordanceOnlyWhenSourceIsMissing() throws {
        let assetLoader = CanvasAssetLoader()
        let emptyNode = CanvasNode(
            kind: .maskedImage,
            name: "Empty Masked",
            transform: CanvasTransform(position: CanvasPoint(x: 80, y: 80)),
            size: CanvasSize(width: 120, height: 160),
            zIndex: 0,
            maskedImage: CanvasMaskedImagePayload(
                maskSource: .bundleImage(named: "theme-mask-1")
            )
        )
        let filledNode = CanvasNode(
            kind: .maskedImage,
            name: "Filled Masked",
            transform: CanvasTransform(position: CanvasPoint(x: 80, y: 80)),
            size: CanvasSize(width: 120, height: 160),
            zIndex: 0,
            source: .remoteURL("invalid url"),
            maskedImage: CanvasMaskedImagePayload(
                maskSource: .bundleImage(named: "theme-mask-1")
            )
        )

        let view = CanvasNodeView(frame: CGRect(origin: .zero, size: emptyNode.size.cgSize))

        view.apply(node: emptyNode, assetLoader: assetLoader)
        view.layoutIfNeeded()
        let plusView = try XCTUnwrap(
            Self.findSubview(
                in: view,
                accessibilityIdentifier: "canvas-node-masked-placeholder-plus"
            )
        )
        XCTAssertFalse(plusView.isHidden)
        XCTAssertEqual(plusView.bounds.width, 34, accuracy: 0.001)
        XCTAssertEqual(plusView.bounds.height, 34, accuracy: 0.001)

        view.viewportScale = 0.2
        view.layoutIfNeeded()
        XCTAssertGreaterThan(plusView.bounds.width, 80)
        XCTAssertGreaterThan(plusView.bounds.height, 80)

        view.apply(node: filledNode, assetLoader: assetLoader)
        view.layoutIfNeeded()
        XCTAssertTrue(plusView.isHidden)
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

    private static func solidImage(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func splitImage(leftColor: UIColor, rightColor: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            leftColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            rightColor.setFill()
            context.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
        }
    }

    private static func quadrantImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor(red: 0.98, green: 0.42, blue: 0.20, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
            UIColor(red: 0.16, green: 0.54, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height / 2))
            UIColor(red: 0.22, green: 0.74, blue: 0.44, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: size.height / 2, width: size.width / 2, height: size.height / 2))
            UIColor(red: 0.96, green: 0.84, blue: 0.24, alpha: 1).setFill()
            context.fill(CGRect(x: size.width / 2, y: size.height / 2, width: size.width / 2, height: size.height / 2))
        }
    }

    private static func leftHalfMaskImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
        }
    }

    private static func opaqueMaskImage(size: CGSize) -> UIImage {
        solidImage(color: .white, size: size)
    }

    private static func pixel(in image: UIImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        guard let cgImage = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return (0, 0, 0, 0)
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return (0, 0, 0, 0)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let clampedX = min(max(x, 0), width - 1)
        let clampedY = min(max(y, 0), height - 1)
        let sampleY = height - 1 - clampedY
        let index = (sampleY * bytesPerRow) + (clampedX * 4)

        return (
            r: data[index],
            g: data[index + 1],
            b: data[index + 2],
            a: data[index + 3]
        )
    }

    private static func findSubview(in view: UIView, accessibilityIdentifier: String) -> UIView? {
        if view.accessibilityIdentifier == accessibilityIdentifier {
            return view
        }

        for subview in view.subviews {
            if let match = findSubview(in: subview, accessibilityIdentifier: accessibilityIdentifier) {
                return match
            }
        }

        return nil
    }
}
#endif
