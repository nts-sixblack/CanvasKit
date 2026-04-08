#if canImport(UIKit)
import UIKit
import CanvasKitCore

public enum CanvasEditorPresentationMode: Sendable {
    case fullscreen
    case embedded
}

public struct CanvasEditorExportOutput {
    public var result: CanvasEditorResult
    public var previewImage: UIImage

    public init(
        result: CanvasEditorResult,
        previewImage: UIImage
    ) {
        self.result = result
        self.previewImage = previewImage
    }
}

public enum CanvasEditorExportError: LocalizedError, Sendable, Equatable {
    case exportDisabled
    case editorUnavailable
    case pngEncodingFailed
    case exportPreparationFailed
    case previewImagePreparationFailed

    public var errorDescription: String? {
        switch self {
        case .exportDisabled:
            return "Export is disabled in the current canvas configuration."
        case .editorUnavailable:
            return "The embedded canvas editor is not currently available."
        case .pngEncodingFailed:
            return "Unable to encode PNG output for the current canvas."
        case .exportPreparationFailed:
            return "Unable to prepare the current canvas export."
        case .previewImagePreparationFailed:
            return "Unable to create a preview image for the current canvas export."
        }
    }
}
#endif
