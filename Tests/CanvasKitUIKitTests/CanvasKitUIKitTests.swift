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

    func testInlineSourceEncodesTransparentImagesAsPNG() {
        let size = CGSize(width: 120, height: 80)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 40, y: 20, width: 40, height: 40))
        }

        let assetLoader = CanvasAssetLoader()
        guard let source = assetLoader.inlineSource(from: image) else {
            XCTFail("Expected inline source")
            return
        }

        XCTAssertEqual(source.mimeType, "image/png")

        guard let encoded = source.dataBase64,
              let data = Data(base64Encoded: encoded),
              let decoded = UIImage(data: data) else {
            XCTFail("Expected inline image data")
            return
        }

        XCTAssertEqual(Self.pixel(in: decoded, x: 0, y: 0).a, 0)
        XCTAssertEqual(Self.pixel(in: decoded, x: 60, y: 40).a, 255)
    }

    @MainActor
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

    @MainActor
    func testInspectorColorChipAddsDefaultBorderToVisibleSwatches() throws {
        let button = InspectorColorChipButton()
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)

        button.configure(kind: .color(.white))
        button.layoutIfNeeded()

        let swatchView = try XCTUnwrap(Self.findColorChipSwatch(in: button))
        XCTAssertEqual(swatchView.layer.borderWidth, 1, accuracy: 0.001)
        XCTAssertTrue(Self.colorsMatch(swatchView.layer.borderColor, CanvasEditorTheme.separator.cgColor))

        button.configure(kind: .picker)
        button.setDisplayedColor(.white)
        button.layoutIfNeeded()

        XCTAssertEqual(swatchView.layer.borderWidth, 1, accuracy: 0.001)
        XCTAssertTrue(Self.colorsMatch(swatchView.layer.borderColor, CanvasEditorTheme.separator.cgColor))

        button.setDisplayedColor(nil)
        button.layoutIfNeeded()

        XCTAssertEqual(swatchView.layer.borderWidth, 0, accuracy: 0.001)
    }

    @MainActor
    func testBrushInspectorPickerChipRequestsColorPickerAndTracksCustomColor() throws {
        let brushInspectorView = CanvasBrushInspectorView()
        let delegate = BrushInspectorDelegateSpy()
        brushInspectorView.delegate = delegate
        brushInspectorView.frame = CGRect(x: 0, y: 0, width: 320, height: 280)
        brushInspectorView.configure(
            palette: [.black, CanvasColor(red: 0.12, green: 0.38, blue: 0.94, alpha: 1)],
            showsColorPicker: true
        )

        let customColor = CanvasColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        brushInspectorView.apply(
            configuration: CanvasBrushConfiguration(
                type: .brush,
                strokeWidth: 18,
                opacity: 1,
                color: customColor
            )
        )
        brushInspectorView.layoutIfNeeded()

        let pickerButton = try XCTUnwrap(
            Self.findSubview(
                in: brushInspectorView,
                accessibilityIdentifier: "canvas-brush-color-picker-button"
            ) as? UIButton
        )
        XCTAssertTrue(pickerButton.isSelected)

        pickerButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(delegate.didRequestColorPicker)

        let updatedColor = CanvasColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1)
        brushInspectorView.applySelectedColor(updatedColor)

        XCTAssertEqual(delegate.lastConfiguration?.color, updatedColor)
        XCTAssertTrue(pickerButton.isSelected)
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

        XCTAssertTrue(
            Self.pixel(in: rendererImage, x: 180, y: 180) == Self.pixel(in: viewImage, x: 180, y: 180)
        )
        XCTAssertTrue(
            Self.pixel(in: rendererImage, x: 420, y: 560) == Self.pixel(in: viewImage, x: 420, y: 560)
        )
        XCTAssertTrue(
            Self.pixel(in: rendererImage, x: 130, y: 640) == Self.pixel(in: viewImage, x: 130, y: 640)
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

    @MainActor
    func testFullscreenEditorKeepsNavigationButtons() {
        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: .default
        )

        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.navigationItem.leftBarButtonItem)
        XCTAssertNotNil(viewController.navigationItem.rightBarButtonItem)
    }

    @MainActor
    func testEmbeddedEditorDoesNotInstallNavigationButtons() {
        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: .default,
            mode: .embedded
        )

        viewController.loadViewIfNeeded()

        XCTAssertNil(viewController.navigationItem.leftBarButtonItem)
        XCTAssertNil(viewController.navigationItem.rightBarButtonItem)
    }

    @MainActor
    func testEmbeddedEditorOmitsHistoryButtonsWhenDisabledInEnabledTools() {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.enabledTools.removeAll { $0 == .undo || $0 == .redo }

        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration,
            mode: .embedded
        )

        viewController.loadViewIfNeeded()

        XCTAssertNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-undo-button"))
        XCTAssertNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-redo-button"))
    }

    @MainActor
    func testEmbeddedEditorOmitsLayersButtonWhenFeatureFlagIsDisabled() {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.showsEmbeddedLayersButton = false

        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration,
            mode: .embedded
        )

        viewController.loadViewIfNeeded()

        XCTAssertNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-layers-button"))
    }

    @MainActor
    func testEmbeddedEditorCollapsesBottomToolbarWhenNoPrimaryToolsAreAvailable() throws {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.enabledTools = [.undo, .redo, .export]

        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration,
            mode: .embedded
        )

        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        XCTAssertNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-bottom-panel"))

        let historyContainer = try XCTUnwrap(
            Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-history-container")
        )
        XCTAssertFalse(historyContainer.isHidden)
        XCTAssertEqual(
            historyContainer.frame.maxY,
            viewController.view.safeAreaLayoutGuide.layoutFrame.maxY - CGFloat(configuration.layout.historyToBottomPanelSpacing),
            accuracy: 0.5
        )
    }

    @MainActor
    func testFullscreenEditorCollapsesBottomToolbarWhenNoPrimaryToolsAreAvailable() throws {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.enabledTools = []

        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration
        )

        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        XCTAssertNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-bottom-panel"))

        let historyContainer = try XCTUnwrap(
            Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-history-container")
        )
        XCTAssertFalse(historyContainer.isHidden)
        XCTAssertEqual(
            historyContainer.frame.maxY,
            viewController.view.safeAreaLayoutGuide.layoutFrame.maxY - CGFloat(configuration.layout.historyToBottomPanelSpacing),
            accuracy: 0.5
        )
    }

    @MainActor
    func testFullscreenEditorKeepsHistoryAndLayersChromeUnchanged() {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.enabledTools.removeAll { $0 == .undo || $0 == .redo }
        configuration.features.showsEmbeddedLayersButton = false

        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration
        )

        viewController.loadViewIfNeeded()

        XCTAssertNotNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-undo-button"))
        XCTAssertNotNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-redo-button"))
        XCTAssertNotNil(Self.findSubview(in: viewController.view, accessibilityIdentifier: "canvas-editor-layers-button"))
    }

    @MainActor
    func testEmbeddedExportReturnsPreviewImageAndProjectData() {
        let expectation = expectation(description: "embedded export completes")
        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: .default,
            mode: .embedded
        )

        viewController.loadViewIfNeeded()
        viewController.exportCurrentCanvas { result in
            switch result {
            case .success(let output):
                XCTAssertFalse(output.result.imageData.isEmpty)
                XCTAssertFalse(output.result.projectData.isEmpty)
                XCTAssertGreaterThan(output.previewImage.size.width, 0)
                XCTAssertGreaterThan(output.previewImage.size.height, 0)
            case .failure(let error):
                XCTFail("Expected export to succeed, got \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    @MainActor
    func testEmbeddedExportFailsWhenExportToolIsDisabled() {
        var configuration = CanvasEditorConfiguration.default
        configuration.features.enabledTools.removeAll { $0 == .export }

        let expectation = expectation(description: "embedded export fails")
        let viewController = CanvasEditorViewController(
            input: .template(Self.exportTemplate),
            configuration: configuration,
            mode: .embedded
        )

        viewController.exportCurrentCanvas { result in
            switch result {
            case .success:
                XCTFail("Expected export to be disabled")
            case .failure(let error):
                XCTAssertEqual(error, .exportDisabled)
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    @MainActor
    func testLayersButtonHiddenUnlessAtLeastTwoLayers() {
        func assertLayersButtonHidden(_ project: CanvasProject, isHidden expectedHidden: Bool, file: StaticString = #filePath, line: UInt = #line) {
            let viewController = CanvasEditorViewController(
                input: .project(project),
                configuration: .default,
                mode: .fullscreen
            )
            viewController.loadViewIfNeeded()

            guard let button = Self.findSubview(
                in: viewController.view,
                accessibilityIdentifier: "canvas-editor-layers-button"
            ) as? UIButton else {
                XCTFail("Expected to find layers button", file: file, line: line)
                return
            }

            XCTAssertEqual(button.isHidden, expectedHidden, file: file, line: line)
        }

        assertLayersButtonHidden(Self.layersTestProject(nodeCount: 0), isHidden: true)
        assertLayersButtonHidden(Self.layersTestProject(nodeCount: 1), isHidden: true)
        assertLayersButtonHidden(Self.layersTestProject(nodeCount: 2), isHidden: false)
    }

    @MainActor
    func testLayersButtonHidesWhenProjectDropsBelowTwoLayers() {
        let viewController = CanvasEditorViewController(
            input: .project(Self.layersTestProject(nodeCount: 2)),
            configuration: .default,
            mode: .fullscreen
        )
        viewController.loadViewIfNeeded()

        guard let button = Self.findSubview(
            in: viewController.view,
            accessibilityIdentifier: "canvas-editor-layers-button"
        ) as? UIButton else {
            XCTFail("Expected to find layers button")
            return
        }

        XCTAssertFalse(button.isHidden)

        viewController.store.replaceProject(Self.layersTestProject(nodeCount: 1))
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertTrue(button.isHidden)
    }

    private static func layersTestProject(nodeCount: Int) -> CanvasProject {
        let nodes = (0..<nodeCount).map { index in
            CanvasNode(
                kind: .text,
                name: "Node \(index)",
                transform: CanvasTransform(position: CanvasPoint(x: 50, y: 50)),
                size: CanvasSize(width: 60, height: 30),
                zIndex: index,
                text: "Test \(index)",
                style: .defaultText
            )
        }
        return CanvasProject(
            templateID: "layers-ui-test-\(nodeCount)",
            canvasSize: CanvasSize(width: 100, height: 100),
            background: .solid(.white),
            nodes: nodes
        )
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

    private static var exportTemplate: CanvasTemplate {
        CanvasTemplate(
            id: "export-template",
            name: "Export Template",
            canvasSize: CanvasSize(width: 640, height: 640),
            background: .solid(CanvasColor(hex: "122034")),
            nodes: [
                CanvasNode(
                    kind: .text,
                    name: "Title",
                    transform: CanvasTransform(position: CanvasPoint(x: 320, y: 320)),
                    size: CanvasSize(width: 360, height: 160),
                    zIndex: 0,
                    text: "CanvasKit",
                    style: .defaultText
                )
            ]
        )
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

    private static func findColorChipSwatch(in button: UIButton) -> UIView? {
        button.subviews.first { subview in
            abs(subview.bounds.width - 34) < 0.001 &&
            abs(subview.bounds.height - 34) < 0.001 &&
            abs(subview.layer.cornerRadius - 17) < 0.001
        }
    }

    private static func colorsMatch(_ lhs: CGColor?, _ rhs: CGColor) -> Bool {
        guard let lhs,
              let lhsComponents = UIColor(cgColor: lhs).rgbaComponents,
              let rhsComponents = UIColor(cgColor: rhs).rgbaComponents else {
            return false
        }

        return abs(lhsComponents.red - rhsComponents.red) < 0.001 &&
            abs(lhsComponents.green - rhsComponents.green) < 0.001 &&
            abs(lhsComponents.blue - rhsComponents.blue) < 0.001 &&
            abs(lhsComponents.alpha - rhsComponents.alpha) < 0.001
    }
}

private extension UIColor {
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return (red, green, blue, alpha)
    }
}

@MainActor
private final class BrushInspectorDelegateSpy: CanvasBrushInspectorViewDelegate {
    private(set) var didRequestColorPicker = false
    private(set) var lastConfiguration: CanvasBrushConfiguration?

    func canvasBrushInspectorViewDidCancel(_ brushInspectorView: CanvasBrushInspectorView) {}

    func canvasBrushInspectorView(_ brushInspectorView: CanvasBrushInspectorView, didChange configuration: CanvasBrushConfiguration) {
        lastConfiguration = configuration
    }

    func canvasBrushInspectorView(_ brushInspectorView: CanvasBrushInspectorView, didConfirm configuration: CanvasBrushConfiguration) {}

    func canvasBrushInspectorViewDidRequestColorPicker(_ brushInspectorView: CanvasBrushInspectorView) {
        didRequestColorPicker = true
    }
}
#endif
