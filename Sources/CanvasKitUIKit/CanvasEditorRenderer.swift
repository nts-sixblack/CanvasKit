#if canImport(UIKit)
import UIKit
import CanvasKitCore

enum CanvasEditorRenderer {
    @MainActor
    static func render(
        project: CanvasProject,
        assetLoader: CanvasAssetLoader,
        excludingNodeIDs: Set<String> = [],
        imageScale: CGFloat = 1
    ) -> UIImage {
        let baseImage = renderBaseImage(
            project: project,
            assetLoader: assetLoader,
            excludingNodeIDs: excludingNodeIDs,
            imageScale: imageScale
        )
        return applyFilter(project.canvasFilter, to: baseImage)
    }

    @MainActor
    static func renderBaseImage(
        project: CanvasProject,
        assetLoader: CanvasAssetLoader,
        excludingNodeIDs: Set<String> = [],
        imageScale: CGFloat = 1
    ) -> UIImage {
        let renderSize = project.canvasSize.cgSize
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = max(imageScale, 0.1)
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        return renderer.image { context in
            let canvasRect = CGRect(origin: .zero, size: renderSize)
            let cgContext = context.cgContext
            cgContext.interpolationQuality = .high

            drawBackground(project.background, in: canvasRect, assetLoader: assetLoader)

            for node in project.sortedNodes {
                guard !excludingNodeIDs.contains(node.id) else {
                    continue
                }
                draw(node: node, assetLoader: assetLoader, in: cgContext)
            }

            CanvasEraserPathBuilder.applyClearStrokes(project.eraserStrokes, in: cgContext)
        }
    }

    @MainActor
    static func applyFilter(_ filter: CanvasFilterPreset, to image: UIImage) -> UIImage {
        CanvasFilterProcessor.apply(filter, to: image)
    }

    private static func drawBackground(_ background: CanvasBackground, in rect: CGRect, assetLoader: CanvasAssetLoader) {
        background.color?.uiColor.setFill()
        UIRectFill(rect)

        guard background.kind == .image,
              let image = assetLoader.imageSynchronously(for: background.source) else {
            return
        }

        image.draw(in: CanvasAspectRatioLayout.aspectFillRect(for: image.size, in: rect))
    }

    private static func draw(node: CanvasNode, assetLoader: CanvasAssetLoader, in context: CGContext) {
        let nodeRect = CGRect(
            x: -node.size.width / 2,
            y: -node.size.height / 2,
            width: node.size.width,
            height: node.size.height
        )

        context.saveGState()
        context.translateBy(x: node.transform.position.x, y: node.transform.position.y)
        context.rotate(by: node.transform.rotation)
        context.scaleBy(x: node.transform.scale, y: node.transform.scale)
        context.setAlpha(node.opacity)

        switch node.kind {
        case .text, .emoji:
            drawTextNode(node, in: nodeRect)
        case .sticker, .image:
            drawImageNode(node, assetLoader: assetLoader, in: nodeRect)
        case .maskedImage:
            drawMaskedImageNode(node, assetLoader: assetLoader, in: nodeRect)
        case .shape:
            drawShapeNode(node, in: context)
        }

        context.restoreGState()
    }

    private static func drawTextNode(_ node: CanvasNode, in rect: CGRect) {
        let style = node.style ?? (node.kind == .emoji ? .defaultEmoji : .defaultText)
        let textRect = rect.insetBy(dx: 8, dy: 8)

        if let backgroundColor = style.resolvedBackgroundUIColor {
            backgroundColor.setFill()
            UIBezierPath(roundedRect: textRect, cornerRadius: 16).fill()
        }

        let text = node.text ?? ""
        style.attributedString(text: text).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }

    private static func drawImageNode(_ node: CanvasNode, assetLoader: CanvasAssetLoader, in rect: CGRect) {
        guard let image = assetLoader.imageSynchronously(for: node.source) else {
            let placeholderRect = rect.insetBy(dx: 4, dy: 4)
            UIColor.white.withAlphaComponent(0.12).setFill()
            UIColor.white.withAlphaComponent(0.3).setStroke()
            let placeholderPath = UIBezierPath(roundedRect: placeholderRect, cornerRadius: 18)
            placeholderPath.lineWidth = 1
            placeholderPath.fill()
            placeholderPath.stroke()
            return
        }

        if node.source?.kind == .symbol {
            let symbolConfig = UIImage.SymbolConfiguration(
                pointSize: CanvasSymbolNodeLayout.symbolPointSize(for: node),
                weight: .bold
            )
            let tintedSymbol = image
                .applyingSymbolConfiguration(symbolConfig)?
                .withTintColor(node.style?.foregroundColor.uiColor ?? .white, renderingMode: .alwaysOriginal)

            let renderedSymbol = tintedSymbol ?? image
            renderedSymbol.draw(in: CanvasAspectRatioLayout.aspectFitRect(for: renderedSymbol.size, in: rect))
            return
        }

        image.draw(in: CanvasAspectRatioLayout.aspectFitRect(for: image.size, in: rect))
    }

    private static func drawMaskedImageNode(_ node: CanvasNode, assetLoader: CanvasAssetLoader, in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let image = renderer.image { rendererContext in
            let nodeView = CanvasNodeView(frame: CGRect(origin: .zero, size: rect.size))
            nodeView.showsMaskedEmptyAffordance = false
            nodeView.apply(node: node, assetLoader: assetLoader)
            nodeView.setMaskedImageEditingState(false)
            nodeView.layoutIfNeeded()
            nodeView.layer.render(in: rendererContext.cgContext)
        }

        image.draw(in: rect)
    }

    private static func drawShapeNode(_ node: CanvasNode, in context: CGContext) {
        guard let payload = node.shape else {
            return
        }

        let path = payload.bezierPath()
        context.saveGState()
        context.translateBy(x: -node.size.width / 2, y: -node.size.height / 2)
        context.addPath(path.cgPath)
        context.setStrokeColor(payload.strokeColor.uiColor.cgColor)
        context.setLineWidth(payload.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        context.restoreGState()
    }

}
#endif
