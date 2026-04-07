import CoreGraphics
import XCTest
@testable import CanvasKitCore

final class CanvasEditorCoreTests: XCTestCase {
    func testTemplateAndProjectRoundTrip() throws {
        let template = Self.sampleTemplate
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let templateData = try encoder.encode(template)
        let decodedTemplate = try decoder.decode(CanvasTemplate.self, from: templateData)
        XCTAssertEqual(decodedTemplate.id, template.id)
        XCTAssertEqual(decodedTemplate.nodes.count, template.nodes.count)
        XCTAssertEqual(decodedTemplate.canvasSize, template.canvasSize)

        let project = CanvasProject(template: decodedTemplate)
        let projectData = try encoder.encode(project)
        let decodedProject = try decoder.decode(CanvasProject.self, from: projectData)
        XCTAssertEqual(decodedProject.templateID, template.id)
        XCTAssertEqual(decodedProject.nodes.first?.source?.kind, .remoteURL)
    }

    func testStoreSupportsUndoRedoTransformFlow() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        store.addTextNode(text: "Hello")
        let addedID = store.selectedNodeID
        let originalPosition = store.selectedNode?.transform.position

        store.moveSelectedNode(by: CanvasPoint(x: 40, y: -20))
        XCTAssertNotEqual(store.selectedNode?.transform.position, originalPosition)

        store.undo()
        XCTAssertEqual(store.selectedNode?.transform.position, originalPosition)

        store.undo()
        XCTAssertFalse(store.project.nodes.contains(where: { $0.id == addedID }))

        store.redo()
        XCTAssertTrue(store.project.nodes.contains(where: { $0.id == addedID }))
    }

    func testAddTextNodeScalesDefaultLayoutForSmallCanvas() {
        let store = CanvasEditorStore(
            template: Self.emptyTemplate(canvasSize: CanvasSize(width: 540, height: 720)),
            configuration: .demo
        )

        store.addTextNode(text: "Hello")

        XCTAssertEqual(store.selectedNode?.size, CanvasSize(width: 220, height: 112))
        XCTAssertEqual(store.selectedNode?.style?.fontSize, 30)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.radius, 8)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.offsetY, 6)
    }

    func testAddTextNodeKeepsBaselineLayoutForReferenceCanvas() {
        let store = CanvasEditorStore(
            template: Self.emptyTemplate(canvasSize: CanvasSize(width: 1080, height: 1350)),
            configuration: .demo
        )

        store.addTextNode(text: "Hello")

        XCTAssertEqual(store.selectedNode?.size, CanvasSize(width: 320, height: 168))
        XCTAssertEqual(store.selectedNode?.style?.fontSize, 54)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.radius, 14)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.offsetY, 10)
    }

    func testAddTextNodeScalesDefaultLayoutForLargeCanvas() {
        let store = CanvasEditorStore(
            template: Self.emptyTemplate(canvasSize: CanvasSize(width: 2160, height: 2700)),
            configuration: .demo
        )

        store.addTextNode(text: "Hello")

        XCTAssertEqual(store.selectedNode?.size, CanvasSize(width: 640, height: 336))
        XCTAssertEqual(store.selectedNode?.style?.fontSize, 108)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.radius, 28)
        XCTAssertEqual(store.selectedNode?.style?.shadow?.offsetY, 20)
    }

    func testStoreNormalizesZOrderWhenReordering() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let middleNodeID = store.project.sortedNodes[1].id
        store.selectNode(middleNodeID)
        store.bringSelectedNodeToFront()

        let frontNode = store.project.sortedNodes.last
        XCTAssertEqual(frontNode?.id, middleNodeID)
        XCTAssertEqual(store.project.sortedNodes.map(\.zIndex), Array(0..<store.project.nodes.count))

        store.sendSelectedNodeToBack()
        let backNode = store.project.sortedNodes.first
        XCTAssertEqual(backNode?.id, middleNodeID)
        XCTAssertEqual(store.project.sortedNodes.map(\.zIndex), Array(0..<store.project.nodes.count))
    }

    func testCanvasNodeDecodesMissingIsEditableAsTrue() throws {
        let data = Data(
            """
            {
              "id": "legacy-node",
              "kind": "text",
              "transform": {
                "position": { "x": 120, "y": 180 },
                "rotation": 0,
                "scale": 1
              },
              "size": {
                "width": 240,
                "height": 80
              },
              "zIndex": 1,
              "opacity": 1,
              "text": "Legacy"
            }
            """.utf8
        )

        let decodedNode = try JSONDecoder().decode(CanvasNode.self, from: data)

        XCTAssertTrue(decodedNode.isEditable)
    }

    func testToggleNodeLockPersistsAcrossEncoding() throws {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let nodeID = store.project.sortedNodes[0].id

        store.toggleNodeLock(nodeID)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedProject = try decoder.decode(CanvasProject.self, from: store.encodedProjectData(prettyPrinted: false))

        XCTAssertEqual(decodedProject.nodes.first(where: { $0.id == nodeID })?.isEditable, false)
    }

    func testMoveNodeInLayerPanelReordersTopmostFirstAndNormalizesZIndexes() {
        let store = CanvasEditorStore(template: Self.layerTemplate, configuration: .demo)

        XCTAssertEqual(Array(store.project.sortedNodes.reversed()).map(\.id), ["node-3", "node-2", "node-1", "node-0"])

        store.moveNodeInLayerPanel(from: 0, to: 2)

        XCTAssertEqual(Array(store.project.sortedNodes.reversed()).map(\.id), ["node-2", "node-1", "node-3", "node-0"])
        XCTAssertEqual(store.project.sortedNodes.map(\.zIndex), Array(0..<store.project.nodes.count))
    }

    func testLockedLayerCanMoveWithinPanelOrder() {
        let store = CanvasEditorStore(template: Self.lockedLayerTemplate, configuration: .demo)

        XCTAssertEqual(Array(store.project.sortedNodes.reversed()).map(\.id), ["node-3", "node-2", "node-1", "node-0"])

        store.moveNodeInLayerPanel(from: 2, to: 0)

        XCTAssertEqual(Array(store.project.sortedNodes.reversed()).map(\.id), ["node-1", "node-3", "node-2", "node-0"])
        XCTAssertEqual(store.project.sortedNodes.map(\.zIndex), Array(0..<store.project.nodes.count))
        XCTAssertEqual(store.project.nodes.first(where: { $0.id == "node-1" })?.isEditable, false)
    }

    func testUnlockedLayerCanMoveAcrossLockedLayerInPanelOrder() {
        let store = CanvasEditorStore(template: Self.lockedLayerTemplate, configuration: .demo)

        store.moveNodeInLayerPanel(from: 0, to: 3)

        XCTAssertEqual(Array(store.project.sortedNodes.reversed()).map(\.id), ["node-2", "node-1", "node-0", "node-3"])
        XCTAssertEqual(store.project.sortedNodes.map(\.zIndex), Array(0..<store.project.nodes.count))
    }

    func testLockingSelectedNodeClearsSelectionAndPreventsReselect() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let textNodeID = store.project.sortedNodes[1].id

        store.selectNode(textNodeID)
        store.toggleNodeLock(textNodeID)

        XCTAssertNil(store.selectedNodeID)

        store.selectNode(textNodeID)
        XCTAssertNil(store.selectedNodeID)
    }

    func testTextStyleSerializationPreservesAdvancedFields() throws {
        let style = CanvasTextStyle(
            fontFamily: "Avenir Next",
            weight: .heavy,
            isItalic: true,
            fontSize: 58,
            foregroundColor: .accent,
            alignment: .trailing,
            letterSpacing: 3.5,
            lineSpacing: 11,
            shadow: CanvasShadowStyle(color: .black, radius: 12, offsetX: 2, offsetY: 6),
            outline: CanvasOutlineStyle(color: .white, width: 8),
            backgroundFill: CanvasFillStyle(color: .plum),
            opacity: 0.86
        )

        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(CanvasTextStyle.self, from: data)

        XCTAssertEqual(decoded, style)
    }

    func testAdjustSelectedTextWidthOnlyChangesWidth() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let textNodeID = store.project.sortedNodes[1].id
        store.selectNode(textNodeID)

        let before = store.selectedNode
        store.adjustSelectedTextWidth(by: 120)
        let after = store.selectedNode

        XCTAssertEqual(after?.size.height, before?.size.height)
        XCTAssertNotNil(after)
        XCTAssertNotNil(before)
        XCTAssertEqual(after!.size.width, before!.size.width + 120, accuracy: 0.001)
        XCTAssertGreaterThan(after?.transform.position.x ?? 0, before?.transform.position.x ?? 0)
    }

    func testProjectScreenDeltaToLocalAxesAtZeroRotationPreservesAxes() {
        let projected = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
            CGPoint(x: 30, y: -12),
            rotation: 0
        )

        XCTAssertEqual(projected.localDeltaX, 30, accuracy: 0.001)
        XCTAssertEqual(projected.localDeltaY, -12, accuracy: 0.001)
    }

    func testProjectScreenDeltaToLocalAxesAtQuarterTurnMatchesRotatedWidthAndHeightAxes() {
        let horizontalDrag = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
            CGPoint(x: 40, y: 0),
            rotation: .pi / 2
        )
        let verticalDrag = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
            CGPoint(x: 0, y: 25),
            rotation: .pi / 2
        )

        XCTAssertEqual(horizontalDrag.localDeltaX, 0, accuracy: 0.001)
        XCTAssertEqual(horizontalDrag.localDeltaY, -40, accuracy: 0.001)
        XCTAssertEqual(verticalDrag.localDeltaX, 25, accuracy: 0.001)
        XCTAssertEqual(verticalDrag.localDeltaY, 0, accuracy: 0.001)
    }

    func testProjectScreenDeltaToLocalAxesMatchesWidthAndHeightBasisAtArbitraryRotation() {
        let rotation = 0.35
        let cosValue = cos(rotation)
        let sinValue = sin(rotation)

        let widthBasisDrag = CGPoint(x: 24 * cosValue, y: 24 * sinValue)
        let heightBasisDrag = CGPoint(x: -52 * sinValue, y: 52 * cosValue)

        let projectedWidth = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
            widthBasisDrag,
            rotation: rotation
        )
        let projectedHeight = CanvasInteractionMath.projectScreenDeltaToLocalAxes(
            heightBasisDrag,
            rotation: rotation
        )

        XCTAssertEqual(projectedWidth.localDeltaX, 24, accuracy: 0.001)
        XCTAssertEqual(projectedWidth.localDeltaY, 0, accuracy: 0.001)
        XCTAssertEqual(projectedHeight.localDeltaX, 0, accuracy: 0.001)
        XCTAssertEqual(projectedHeight.localDeltaY, 52, accuracy: 0.001)
    }

    func testAddImageNodePreservesIntrinsicAspectRatio() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)

        store.addImageNode(
            source: .inlineImage(data: Data([0x00])),
            intrinsicSize: CanvasSize(width: 1600, height: 900)
        )

        guard let imageNode = store.selectedNode else {
            XCTFail("Expected imported image node to be selected")
            return
        }

        XCTAssertEqual(imageNode.kind, .image)
        XCTAssertEqual(imageNode.size.width / imageNode.size.height, 1600.0 / 900.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(imageNode.size.width, store.project.canvasSize.width * 0.42 + 0.001)
        XCTAssertLessThanOrEqual(imageNode.size.height, store.project.canvasSize.height * 0.42 + 0.001)
    }

    func testMaskedImageNodeRoundTripPreservesPayload() throws {
        let originalNode = Self.maskedImageTemplate.nodes[0]
        let project = CanvasProject(template: Self.maskedImageTemplate)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(CanvasProject.self, from: data)

        XCTAssertEqual(decoded.nodes.first?.kind, .maskedImage)
        XCTAssertEqual(decoded.nodes.first?.source, originalNode.source)
        XCTAssertEqual(decoded.nodes.first?.maskedImage, originalNode.maskedImage)
    }

    func testMaskedImagePayloadDecodesMissingDeleteFlagAsKeepingMask() throws {
        let legacyData = Data(
            """
            {
              "maskSource": {
                "kind": "bundleImage",
                "name": "theme-mask-1"
              }
            }
            """.utf8
        )

        let payload = try JSONDecoder().decode(CanvasMaskedImagePayload.self, from: legacyData)

        XCTAssertFalse(payload.deletesNodeOnDelete)
        XCTAssertEqual(payload.contentTransform, CanvasMaskedImageContentTransform())
    }

    func testUpdateSelectedMaskedImageSourceResetsContentTransformAndSupportsUndoRedo() {
        let store = CanvasEditorStore(template: Self.maskedImageTemplate, configuration: .demo)
        let maskedNodeID = Self.maskedImageTemplate.nodes[0].id

        store.selectNode(maskedNodeID)
        let originalSource = store.selectedNode?.source
        let originalPayload = store.selectedNode?.maskedImage
        let replacementSource = CanvasAssetSource.inlineImage(data: Data([0xAA, 0xBB, 0xCC]))

        store.updateSelectedSource(replacementSource)

        XCTAssertEqual(store.selectedNode?.source, replacementSource)
        XCTAssertEqual(store.selectedNode?.maskedImage?.contentTransform, CanvasMaskedImageContentTransform())

        store.undo()

        XCTAssertEqual(store.selectedNode?.source, originalSource)
        XCTAssertEqual(store.selectedNode?.maskedImage, originalPayload)

        store.redo()

        XCTAssertEqual(store.selectedNode?.source, replacementSource)
        XCTAssertEqual(store.selectedNode?.maskedImage?.contentTransform, CanvasMaskedImageContentTransform())
    }

    func testDeleteSelectedNodeClearsPersistentMaskedImageContentAndSupportsUndoRedo() {
        let store = CanvasEditorStore(template: Self.maskedImageTemplate, configuration: .demo)
        let maskedNodeID = Self.maskedImageTemplate.nodes[0].id
        let originalNodeCount = store.project.nodes.count
        let originalPayload = Self.maskedImageTemplate.nodes[0].maskedImage
        let originalSource = Self.maskedImageTemplate.nodes[0].source

        store.selectNode(maskedNodeID)
        XCTAssertTrue(store.canDeleteSelectedContent)

        store.deleteSelectedNode()

        XCTAssertEqual(store.project.nodes.count, originalNodeCount)
        XCTAssertEqual(store.selectedNodeID, maskedNodeID)
        XCTAssertNil(store.selectedNode?.source)
        XCTAssertEqual(store.selectedNode?.maskedImage?.contentTransform, CanvasMaskedImageContentTransform())
        XCTAssertFalse(store.canDeleteSelectedContent)

        store.undo()

        XCTAssertEqual(store.project.nodes.count, originalNodeCount)
        XCTAssertEqual(store.selectedNodeID, maskedNodeID)
        XCTAssertEqual(store.selectedNode?.source, originalSource)
        XCTAssertEqual(store.selectedNode?.maskedImage, originalPayload)
        XCTAssertTrue(store.canDeleteSelectedContent)

        store.redo()

        XCTAssertEqual(store.project.nodes.count, originalNodeCount)
        XCTAssertEqual(store.selectedNodeID, maskedNodeID)
        XCTAssertNil(store.selectedNode?.source)
        XCTAssertEqual(store.selectedNode?.maskedImage?.contentTransform, CanvasMaskedImageContentTransform())
        XCTAssertFalse(store.canDeleteSelectedContent)
    }

    func testPersistentMaskedImageWithoutSourceCannotBeDeleted() {
        var template = Self.maskedImageTemplate
        template.nodes[0].source = nil

        let store = CanvasEditorStore(template: template, configuration: .demo)
        let maskedNodeID = template.nodes[0].id

        store.selectNode(maskedNodeID)

        XCTAssertFalse(store.canDeleteSelectedContent)

        store.deleteSelectedContent()

        XCTAssertEqual(store.project.nodes.count, 1)
        XCTAssertEqual(store.selectedNodeID, maskedNodeID)
    }

    func testDeleteSelectedContentRemovesMaskedNodeWhenConfiguredToDeleteNode() {
        let store = CanvasEditorStore(template: Self.removableMaskedImageTemplate, configuration: .demo)
        let maskedNodeID = Self.removableMaskedImageTemplate.nodes[0].id
        let originalCount = store.project.nodes.count

        store.selectNode(maskedNodeID)
        XCTAssertTrue(store.canDeleteSelectedContent)

        store.deleteSelectedContent()

        XCTAssertEqual(store.project.nodes.count, originalCount - 1)
        XCTAssertNil(store.selectedNodeID)
        XCTAssertFalse(store.project.nodes.contains(where: { $0.id == maskedNodeID }))

        store.undo()

        XCTAssertEqual(store.project.nodes.count, originalCount)
        XCTAssertTrue(store.project.nodes.contains(where: { $0.id == maskedNodeID }))

        store.redo()

        XCTAssertEqual(store.project.nodes.count, originalCount - 1)
        XCTAssertFalse(store.project.nodes.contains(where: { $0.id == maskedNodeID }))
    }

    func testMaskedImageContentTransformDoesNotChangeNodeTransform() {
        let store = CanvasEditorStore(template: Self.maskedImageTemplate, configuration: .demo)
        let maskedNodeID = Self.maskedImageTemplate.nodes[0].id

        store.selectNode(maskedNodeID)
        let originalNodeTransform = store.selectedNode?.transform

        store.moveSelectedMaskedImageContent(by: CanvasPoint(x: 30, y: -18))
        store.scaleSelectedMaskedImageContent(by: 1.3)
        store.rotateSelectedMaskedImageContent(by: 0.42)

        XCTAssertEqual(store.selectedNode?.transform, originalNodeTransform)
        XCTAssertNotEqual(
            store.selectedNode?.maskedImage?.contentTransform,
            Self.maskedImageTemplate.nodes[0].maskedImage?.contentTransform
        )
    }

    func testOverlayHandleSizeClampsToMinimumForSmallDisplayedCanvas() {
        let resolved = CanvasOverlayHandleLayoutMath.resolvedHandleSize(
            baseHandleSize: 60,
            displayedCanvasShortSide: 180
        )

        XCTAssertEqual(resolved, 36, accuracy: 0.001)
    }

    func testOverlayHandleSizeClampsToMaximumForLargeDisplayedCanvas() {
        let resolved = CanvasOverlayHandleLayoutMath.resolvedHandleSize(
            baseHandleSize: 60,
            displayedCanvasShortSide: 520
        )

        XCTAssertEqual(resolved, 52, accuracy: 0.001)
    }

    func testOverlayHandleSizeScalesFromBaseSizeAtReferenceCanvas() {
        let resolved = CanvasOverlayHandleLayoutMath.resolvedHandleSize(
            baseHandleSize: 48,
            displayedCanvasShortSide: 390
        )

        XCTAssertEqual(resolved, 48, accuracy: 0.001)
    }

    func testOverlayHandleMetricsUseSmallerSymbolRatio() {
        let metrics = CanvasOverlayHandleLayoutMath.resolvedMetrics(
            layout: CanvasEditorLayout(),
            displayedCanvasShortSide: 390
        )

        XCTAssertEqual(metrics.handleSize, 48, accuracy: 0.001)
        XCTAssertEqual(metrics.cornerRadius, 24, accuracy: 0.001)
        XCTAssertEqual(metrics.symbolPointSize, 21.12, accuracy: 0.001)
    }

    func testBatchEmojiInsertUsesSingleUndoAndStaggersPositions() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let initialCount = store.project.nodes.count

        store.addEmojiNodes(texts: ["😀", "🥳", "🤩"])

        XCTAssertEqual(store.project.nodes.count, initialCount + 3)

        let insertedNodes = Array(store.project.sortedNodes.suffix(3))
        XCTAssertEqual(insertedNodes.map(\.kind), [.emoji, .emoji, .emoji])
        XCTAssertEqual(insertedNodes.last?.id, store.selectedNodeID)
        XCTAssertEqual(Set(insertedNodes.map(\.transform.position)).count, 3)

        store.undo()

        XCTAssertEqual(store.project.nodes.count, initialCount)
    }

    func testShapeNodeRoundTripAndLegacyProjectDecode() throws {
        let project = CanvasProject(
            templateID: "shape-template",
            canvasSize: CanvasSize(width: 1080, height: 1920),
            background: .solid(.black),
            nodes: [
                CanvasNode(
                    kind: .shape,
                    name: "Arrow",
                    transform: CanvasTransform(position: CanvasPoint(x: 540, y: 960), rotation: 0.35, scale: 1.2),
                    size: CanvasSize(width: 320, height: 120),
                    zIndex: 0,
                    opacity: 0.72,
                    shape: CanvasShapePayload(
                        type: .arrow,
                        points: [
                            CanvasPoint(x: 20, y: 60),
                            CanvasPoint(x: 300, y: 60)
                        ],
                        strokeColor: .accent,
                        strokeWidth: 18
                    )
                )
            ]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(project)
        let decoded = try decoder.decode(CanvasProject.self, from: data)

        XCTAssertEqual(decoded.version, CanvasSchemaVersion.current)
        XCTAssertEqual(decoded.nodes.first?.kind, .shape)
        XCTAssertEqual(decoded.nodes.first?.shape?.type, .arrow)
        XCTAssertEqual(decoded.nodes.first?.shape?.strokeColor, .accent)

        let legacyData = Data(
            """
            {
              "version": 1,
              "templateID": "legacy-template",
              "canvasSize": { "width": 1080, "height": 1920 },
              "background": { "kind": "solidColor", "color": { "red": 0, "green": 0, "blue": 0, "alpha": 1 } },
              "nodes": [
                {
                  "id": "legacy-text",
                  "kind": "text",
                  "transform": {
                    "position": { "x": 120, "y": 180 },
                    "rotation": 0,
                    "scale": 1
                  },
                  "size": { "width": 240, "height": 80 },
                  "zIndex": 0,
                  "opacity": 1,
                  "text": "Legacy",
                  "style": {
                    "fontFamily": "Avenir Next",
                    "weight": "bold",
                    "isItalic": false,
                    "fontSize": 42,
                    "foregroundColor": { "red": 1, "green": 1, "blue": 1, "alpha": 1 },
                    "alignment": "center",
                    "letterSpacing": 0,
                    "lineSpacing": 0,
                    "opacity": 1
                  }
                }
              ],
              "metadata": {}
            }
            """.utf8
        )

        let legacyProject = try decoder.decode(CanvasProject.self, from: legacyData)
        XCTAssertEqual(legacyProject.version, 1)
        XCTAssertEqual(legacyProject.nodes.first?.kind, .text)
        XCTAssertNil(legacyProject.nodes.first?.shape)
        XCTAssertTrue(legacyProject.eraserStrokes.isEmpty)
    }

    func testProjectEraserStrokesRoundTripPreservesData() throws {
        let project = CanvasProject(
            templateID: "eraser-template",
            canvasSize: CanvasSize(width: 1080, height: 1920),
            background: .solid(.black),
            nodes: [],
            eraserStrokes: [
                CanvasEraserStroke(
                    points: [
                        CanvasPoint(x: 120, y: 220),
                        CanvasPoint(x: 240, y: 360)
                    ],
                    strokeWidth: 22
                )
            ]
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(CanvasProject.self, from: data)

        XCTAssertEqual(decoded.version, CanvasSchemaVersion.current)
        XCTAssertEqual(decoded.eraserStrokes, project.eraserStrokes)
    }

    func testProjectCanvasFilterRoundTripPreservesData() throws {
        let project = CanvasProject(
            templateID: "filter-template",
            canvasSize: CanvasSize(width: 1080, height: 1920),
            background: .solid(.black),
            nodes: [],
            canvasFilter: .vibrant
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(CanvasProject.self, from: data)

        XCTAssertEqual(decoded.version, CanvasSchemaVersion.current)
        XCTAssertEqual(decoded.canvasFilter, .vibrant)
    }

    func testLegacyProjectDecodesMissingCanvasFilterAsNormal() throws {
        let legacyData = Data(
            """
            {
              "version": 3,
              "templateID": "legacy-template",
              "canvasSize": { "width": 1080, "height": 1920 },
              "background": { "kind": "solidColor", "color": { "red": 0, "green": 0, "blue": 0, "alpha": 1 } },
              "nodes": [],
              "eraserStrokes": [],
              "metadata": {}
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(CanvasProject.self, from: legacyData)

        XCTAssertEqual(decoded.canvasFilter, .normal)
    }

    func testStoreUpdateCanvasFilterSupportsUndoRedo() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)

        XCTAssertEqual(store.project.canvasFilter, .normal)

        store.updateCanvasFilter(.mono)
        XCTAssertEqual(store.project.canvasFilter, .mono)

        store.undo()
        XCTAssertEqual(store.project.canvasFilter, .normal)

        store.redo()
        XCTAssertEqual(store.project.canvasFilter, .mono)
    }

    func testStoreAddShapeNodeSupportsUndoRedo() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let draft = CanvasShapeDraft(
            type: .brush,
            points: [
                CanvasPoint(x: 120, y: 220),
                CanvasPoint(x: 180, y: 260),
                CanvasPoint(x: 260, y: 300)
            ],
            strokeColor: .sky,
            strokeWidth: 24,
            opacity: 0.8
        )

        store.addShapeNode(from: draft)

        guard let shapeNode = store.selectedNode else {
            XCTFail("Expected shape node to be selected after creation")
            return
        }

        XCTAssertEqual(shapeNode.kind, .shape)
        XCTAssertEqual(shapeNode.shape?.type, .brush)
        XCTAssertEqual(shapeNode.shape?.strokeColor, .sky)
        XCTAssertEqual(shapeNode.opacity, 0.8, accuracy: 0.001)
        XCTAssertGreaterThan(shapeNode.size.width, 0)
        XCTAssertGreaterThan(shapeNode.size.height, 0)

        let createdID = shapeNode.id

        store.undo()
        XCTAssertFalse(store.project.nodes.contains(where: { $0.id == createdID }))

        store.redo()
        XCTAssertTrue(store.project.nodes.contains(where: { $0.id == createdID }))
    }

    func testStoreAddEraserStrokeSupportsUndoRedo() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        let stroke = CanvasEraserStroke(
            points: [
                CanvasPoint(x: 90, y: 120),
                CanvasPoint(x: 210, y: 180),
                CanvasPoint(x: 320, y: 260)
            ],
            strokeWidth: 20
        )

        store.addEraserStroke(stroke)

        XCTAssertEqual(store.project.eraserStrokes, [stroke])

        store.undo()
        XCTAssertTrue(store.project.eraserStrokes.isEmpty)

        store.redo()
        XCTAssertEqual(store.project.eraserStrokes, [stroke])
    }

    func testUpdateSelectedShapeStylePreservesTransform() {
        let store = CanvasEditorStore(template: Self.sampleTemplate, configuration: .demo)
        store.addShapeNode(
            from: CanvasShapeDraft(
                type: .line,
                points: [
                    CanvasPoint(x: 160, y: 240),
                    CanvasPoint(x: 420, y: 520)
                ],
                strokeColor: .white,
                strokeWidth: 10,
                opacity: 1
            )
        )

        guard let before = store.selectedNode else {
            XCTFail("Expected created shape node")
            return
        }

        store.updateSelectedShapeStyle(
            type: .rectangle,
            strokeColor: .sunflower,
            strokeWidth: 28,
            opacity: 0.64
        )

        guard let after = store.selectedNode else {
            XCTFail("Expected selected shape node after style update")
            return
        }

        XCTAssertEqual(after.kind, .shape)
        XCTAssertEqual(after.transform, before.transform)
        XCTAssertEqual(after.shape?.type, .rectangle)
        XCTAssertEqual(after.shape?.strokeColor, .sunflower)
        XCTAssertEqual(after.shape?.strokeWidth ?? 0, 28, accuracy: 0.001)
        XCTAssertEqual(after.opacity, 0.64, accuracy: 0.001)
    }

    func testProjectSummaryIncludesCanvasAndInlineImageMetadata() {
        let project = CanvasProject(
            templateID: "summary-template",
            canvasSize: CanvasSize(width: 1080, height: 1920),
            background: .image(.inlineImage(data: Data([0x01, 0x02, 0x03]))),
            nodes: [
                CanvasNode(
                    kind: .image,
                    name: "Inline",
                    transform: CanvasTransform(position: CanvasPoint(x: 540, y: 960)),
                    size: CanvasSize(width: 600, height: 600),
                    zIndex: 0,
                    source: .inlineImage(data: Data([0x04, 0x05]))
                ),
                CanvasNode(
                    kind: .text,
                    name: "Label",
                    transform: CanvasTransform(position: CanvasPoint(x: 540, y: 220)),
                    size: CanvasSize(width: 700, height: 160),
                    zIndex: 1,
                    text: "Summary",
                    style: .defaultText
                )
            ]
        )

        let summary = project.summary

        XCTAssertEqual(summary.nodeCount, 2)
        XCTAssertEqual(summary.canvasSize, CanvasSize(width: 1080, height: 1920))
        XCTAssertTrue(summary.containsInlineImages)
    }

    func testEraserPathBuilderClearsPixelsInsideStroke() {
        guard let context = Self.makeBitmapContext(width: 64, height: 64) else {
            XCTFail("Expected bitmap context")
            return
        }

        context.setFillColor(CGColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))

        CanvasEraserPathBuilder.applyClearStrokes(
            [
                CanvasEraserStroke(
                    points: [
                        CanvasPoint(x: 8, y: 48),
                        CanvasPoint(x: 32, y: 16),
                        CanvasPoint(x: 56, y: 48)
                    ],
                    strokeWidth: 24
                )
            ],
            in: context
        )

        XCTAssertEqual(Self.alpha(in: context, x: 32, y: 28), 0)
        XCTAssertEqual(Self.alpha(in: context, x: 32, y: 0), 255)
    }

    func testEraserMaskPathCreatesTransparentHoleWithEvenOddFill() {
        guard let context = Self.makeBitmapContext(width: 64, height: 64) else {
            XCTFail("Expected bitmap context")
            return
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.addPath(
            CanvasEraserPathBuilder.makeMaskPath(
                in: CGRect(x: 0, y: 0, width: 64, height: 64),
                strokes: [
                    CanvasEraserStroke(
                        points: [
                            CanvasPoint(x: 8, y: 48),
                            CanvasPoint(x: 32, y: 16),
                            CanvasPoint(x: 56, y: 48)
                        ],
                        strokeWidth: 24
                    )
                ]
            )
        )
        context.drawPath(using: .eoFill)

        XCTAssertEqual(Self.alpha(in: context, x: 32, y: 28), 0)
        XCTAssertEqual(Self.alpha(in: context, x: 32, y: 0), 255)
    }

    func testProjectSummaryDetectsProjectsWithoutInlineImages() {
        let project = CanvasProject(template: Self.sampleTemplate)

        let summary = project.summary

        XCTAssertEqual(summary.nodeCount, project.nodes.count)
        XCTAssertEqual(summary.canvasSize, project.canvasSize)
        XCTAssertFalse(summary.containsInlineImages)
    }

    func testProjectSummaryDetectsInlineMaskedAssets() {
        let project = CanvasProject(
            templateID: "masked-inline-summary",
            canvasSize: CanvasSize(width: 640, height: 640),
            background: .solid(.white),
            nodes: [
                CanvasNode(
                    kind: .maskedImage,
                    name: "Masked",
                    transform: CanvasTransform(position: CanvasPoint(x: 320, y: 320)),
                    size: CanvasSize(width: 280, height: 280),
                    zIndex: 0,
                    maskedImage: CanvasMaskedImagePayload(
                        maskSource: .inlineImage(data: Data([0x01, 0x02, 0x03]))
                    )
                )
            ]
        )

        XCTAssertTrue(project.summary.containsInlineImages)
    }

    func testFreehandPathBuilderCreatesVisibleDotForSinglePoint() {
        guard let context = Self.makeBitmapContext(width: 32, height: 32) else {
            XCTFail("Expected bitmap context")
            return
        }

        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(12)
        context.addPath(
            CanvasFreehandPathBuilder.makePath(
                points: [CGPoint(x: 16, y: 16)]
            )
        )
        context.strokePath()

        XCTAssertEqual(Self.alpha(in: context, x: 16, y: 16), 255)
        XCTAssertEqual(Self.alpha(in: context, x: 2, y: 2), 0)
    }

    func testFreehandPathBuilderKeepsSmoothedPathInsidePointBounds() {
        let points = [
            CGPoint(x: 8, y: 22),
            CGPoint(x: 20, y: 6),
            CGPoint(x: 36, y: 34),
            CGPoint(x: 52, y: 12),
            CGPoint(x: 72, y: 28)
        ]

        let pathBounds = CanvasFreehandPathBuilder.makePath(points: points).boundingBoxOfPath
        let pointBounds = points.reduce(into: CGRect.null) { partialResult, point in
            partialResult = partialResult.union(CGRect(origin: point, size: .zero))
        }

        XCTAssertGreaterThanOrEqual(pathBounds.minX, pointBounds.minX - 0.001)
        XCTAssertGreaterThanOrEqual(pathBounds.minY, pointBounds.minY - 0.001)
        XCTAssertLessThanOrEqual(pathBounds.maxX, pointBounds.maxX + 0.001)
        XCTAssertLessThanOrEqual(pathBounds.maxY, pointBounds.maxY + 0.001)
    }

    func testViewportMathFitsCanvasWithinBounds() {
        let layout = CanvasViewportMath.fit(
            canvasSize: CGSize(width: 1080, height: 1920),
            in: CGRect(x: 0, y: 0, width: 390, height: 844),
            padding: 20
        )

        XCTAssertEqual(layout.canvasFrame.midX, 195, accuracy: 0.001)
        XCTAssertEqual(layout.canvasFrame.midY, 422, accuracy: 0.001)
        XCTAssertLessThanOrEqual(layout.canvasFrame.width, 350.001)
        XCTAssertLessThanOrEqual(layout.canvasFrame.height, 804.001)
        XCTAssertGreaterThan(layout.scale, 0)
    }

    private static var sampleTemplate: CanvasTemplate {
        CanvasTemplate(
            id: "unit-template",
            name: "Unit Template",
            canvasSize: CanvasSize(width: 1080, height: 1350),
            background: .solid(CanvasColor(hex: "122034")),
            nodes: [
                CanvasNode(
                    kind: .image,
                    name: "Image",
                    transform: CanvasTransform(position: CanvasPoint(x: 540, y: 640)),
                    size: CanvasSize(width: 600, height: 600),
                    zIndex: 0,
                    source: .remoteURL("https://example.com/demo.png")
                ),
                CanvasNode(
                    kind: .text,
                    name: "Text",
                    transform: CanvasTransform(position: CanvasPoint(x: 540, y: 180)),
                    size: CanvasSize(width: 720, height: 180),
                    zIndex: 1,
                    text: "Launch",
                    style: .defaultText
                )
            ]
        )
    }

    private static func emptyTemplate(canvasSize: CanvasSize) -> CanvasTemplate {
        CanvasTemplate(
            id: "empty-template-\(Int(canvasSize.width))x\(Int(canvasSize.height))",
            name: "Empty Template",
            canvasSize: canvasSize,
            background: .solid(CanvasColor(hex: "122034")),
            nodes: []
        )
    }

    private static var layerTemplate: CanvasTemplate {
        CanvasTemplate(
            id: "layer-template",
            name: "Layer Template",
            canvasSize: CanvasSize(width: 1080, height: 1080),
            background: .solid(CanvasColor(hex: "122034")),
            nodes: (0..<4).map { index in
                CanvasNode(
                    id: "node-\(index)",
                    kind: .text,
                    name: "Node \(index)",
                    transform: CanvasTransform(position: CanvasPoint(x: 160 + Double(index * 120), y: 200 + Double(index * 80))),
                    size: CanvasSize(width: 220, height: 100),
                    zIndex: index,
                    text: "Node \(index)",
                    style: .defaultText
                )
            }
        )
    }

    private static var maskedImageTemplate: CanvasTemplate {
        CanvasTemplate(
            id: "masked-image-template",
            name: "Masked Image Template",
            canvasSize: CanvasSize(width: 900, height: 1600),
            background: .solid(CanvasColor(hex: "F7F4EF")),
            nodes: [
                CanvasNode(
                    id: "masked-node-0",
                    kind: .maskedImage,
                    name: "Masked Slot",
                    transform: CanvasTransform(position: CanvasPoint(x: 570, y: 602)),
                    size: CanvasSize(width: 478, height: 712),
                    zIndex: 0,
                    source: .remoteURL("https://example.com/masked.png"),
                    maskedImage: CanvasMaskedImagePayload(
                        maskSource: .bundleImage(named: "theme-mask-1"),
                        contentTransform: CanvasMaskedImageContentTransform(
                            offset: CanvasPoint(x: 24, y: -18),
                            rotation: 0.28,
                            scale: 1.24
                        ),
                        deletesNodeOnDelete: false
                    )
                )
            ]
        )
    }

    private static var removableMaskedImageTemplate: CanvasTemplate {
        CanvasTemplate(
            id: "removable-masked-image-template",
            name: "Removable Masked Image Template",
            canvasSize: CanvasSize(width: 900, height: 1600),
            background: .solid(CanvasColor(hex: "F7F4EF")),
            nodes: [
                CanvasNode(
                    id: "removable-masked-node-0",
                    kind: .maskedImage,
                    name: "Removable Masked Slot",
                    transform: CanvasTransform(position: CanvasPoint(x: 570, y: 602)),
                    size: CanvasSize(width: 478, height: 712),
                    zIndex: 0,
                    source: .remoteURL("https://example.com/removable-masked.png"),
                    maskedImage: CanvasMaskedImagePayload(
                        maskSource: .bundleImage(named: "theme-mask-1"),
                        deletesNodeOnDelete: true
                    )
                )
            ]
        )
    }

    private static var lockedLayerTemplate: CanvasTemplate {
        var template = layerTemplate
        if let lockedIndex = template.nodes.firstIndex(where: { $0.id == "node-1" }) {
            template.nodes[lockedIndex].isEditable = false
        }
        return template
    }

    private static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
    }

    private static func alpha(in context: CGContext, x: Int, y: Int) -> UInt8 {
        guard let data = context.data else {
            return 0
        }

        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * context.height)
        let offset = (y * context.bytesPerRow) + (x * 4) + 3
        return bytes[offset]
    }
}
