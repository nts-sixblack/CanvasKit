import CoreGraphics
import Foundation

package struct CanvasOverlayHandleMetrics: Equatable, Sendable {
    package var handleSize: CGFloat
    package var cornerRadius: CGFloat
    package var symbolPointSize: CGFloat

    package init(handleSize: CGFloat, cornerRadius: CGFloat, symbolPointSize: CGFloat) {
        self.handleSize = handleSize
        self.cornerRadius = cornerRadius
        self.symbolPointSize = symbolPointSize
    }
}

package enum CanvasOverlayHandleLayoutMath {
    private static let referenceDisplayedCanvasShortSide: CGFloat = 390
    private static let minimumHandleSize: CGFloat = 36
    private static let maximumHandleSize: CGFloat = 52
    private static let symbolPointSizeRatio: CGFloat = 0.44

    package static func defaultMetrics(layout: CanvasEditorLayout) -> CanvasOverlayHandleMetrics {
        let baseHandleSize = CGFloat(layout.overlayHandleSize)
        let cornerRadiusRatio = baseHandleSize > 0
            ? CGFloat(layout.overlayHandleCornerRadius) / baseHandleSize
            : 0.5
        return makeMetrics(
            handleSize: baseHandleSize,
            cornerRadiusRatio: cornerRadiusRatio
        )
    }

    package static func resolvedMetrics(
        layout: CanvasEditorLayout,
        displayedCanvasShortSide: CGFloat
    ) -> CanvasOverlayHandleMetrics {
        let baseHandleSize = CGFloat(layout.overlayHandleSize)
        let resolvedHandleSize = resolvedHandleSize(
            baseHandleSize: baseHandleSize,
            displayedCanvasShortSide: displayedCanvasShortSide
        )
        let cornerRadiusRatio = baseHandleSize > 0
            ? CGFloat(layout.overlayHandleCornerRadius) / baseHandleSize
            : 0.5

        return makeMetrics(
            handleSize: resolvedHandleSize,
            cornerRadiusRatio: cornerRadiusRatio
        )
    }

    package static func resolvedHandleSize(
        baseHandleSize: CGFloat,
        displayedCanvasShortSide: CGFloat
    ) -> CGFloat {
        let safeDisplayedShortSide = max(displayedCanvasShortSide, 0)
        let scaledHandleSize = baseHandleSize * safeDisplayedShortSide / referenceDisplayedCanvasShortSide
        return min(max(scaledHandleSize, minimumHandleSize), maximumHandleSize)
    }

    private static func makeMetrics(
        handleSize: CGFloat,
        cornerRadiusRatio: CGFloat
    ) -> CanvasOverlayHandleMetrics {
        CanvasOverlayHandleMetrics(
            handleSize: handleSize,
            cornerRadius: handleSize * cornerRadiusRatio,
            symbolPointSize: handleSize * symbolPointSizeRatio
        )
    }
}
