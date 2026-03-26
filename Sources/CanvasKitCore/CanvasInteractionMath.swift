import CoreGraphics
import Foundation

package enum CanvasInteractionMath {
    package static func projectScreenDeltaToLocalAxes(
        _ delta: CGPoint,
        rotation: Double
    ) -> (localDeltaX: Double, localDeltaY: Double) {
        let deltaX = Double(delta.x)
        let deltaY = Double(delta.y)
        let cosValue = cos(rotation)
        let sinValue = sin(rotation)

        let localDeltaX = (deltaX * cosValue) + (deltaY * sinValue)
        let localDeltaY = (-deltaX * sinValue) + (deltaY * cosValue)
        return (localDeltaX, localDeltaY)
    }
}
