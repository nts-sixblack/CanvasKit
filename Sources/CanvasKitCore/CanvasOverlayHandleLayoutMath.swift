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
    private static let minimumHandleSize: CGFloat = 44
    private static let maximumHandleSize: CGFloat = 64
    private static let symbolPointSizeRatio: CGFloat = 0.55

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

        return CanvasOverlayHandleMetrics(
            handleSize: resolvedHandleSize,
            cornerRadius: resolvedHandleSize * cornerRadiusRatio,
            symbolPointSize: resolvedHandleSize * symbolPointSizeRatio
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
}
