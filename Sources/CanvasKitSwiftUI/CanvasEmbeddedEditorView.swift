#if canImport(UIKit)
import SwiftUI
import CanvasKitCore
import CanvasKitUIKit

@MainActor
public final class CanvasEmbeddedEditorHandle {
    private weak var viewController: CanvasEditorViewController?

    public init() {}

    public func exportCurrentCanvas(
        completion: @escaping (Result<CanvasEditorExportOutput, CanvasEditorExportError>) -> Void
    ) {
        guard let viewController else {
            completion(.failure(.editorUnavailable))
            return
        }

        viewController.exportCurrentCanvas(completion: completion)
    }

    fileprivate func attach(to viewController: CanvasEditorViewController) {
        self.viewController = viewController
    }

    fileprivate func detach(from viewController: CanvasEditorViewController) {
        guard self.viewController === viewController else {
            return
        }

        self.viewController = nil
    }
}

public struct CanvasEmbeddedEditorView: View {
    public let input: CanvasEditorInput
    public let configuration: CanvasEditorConfiguration
    public let handle: CanvasEmbeddedEditorHandle?

    public init(
        input: CanvasEditorInput,
        configuration: CanvasEditorConfiguration = .default,
        handle: CanvasEmbeddedEditorHandle? = nil
    ) {
        self.input = input
        self.configuration = configuration
        self.handle = handle
    }

    public var body: some View {
        CanvasEmbeddedEditorContainerView(
            input: input,
            configuration: configuration,
            handle: handle
        )
        .ignoresSafeArea(.keyboard)
    }
}

@MainActor
private struct CanvasEmbeddedEditorContainerView: UIViewControllerRepresentable {
    let input: CanvasEditorInput
    let configuration: CanvasEditorConfiguration
    let handle: CanvasEmbeddedEditorHandle?

    func makeCoordinator() -> Coordinator {
        Coordinator(handle: handle)
    }

    func makeUIViewController(context: Context) -> CanvasEditorViewController {
        let viewController = CanvasEditorViewController(
            input: input,
            configuration: configuration,
            mode: .embedded
        )
        context.coordinator.update(handle: handle, attachedTo: viewController)
        return viewController
    }

    func updateUIViewController(
        _ uiViewController: CanvasEditorViewController,
        context: Context
    ) {
        context.coordinator.update(handle: handle, attachedTo: uiViewController)
    }

    @MainActor
    static func dismantleUIViewController(
        _ uiViewController: CanvasEditorViewController,
        coordinator: Coordinator
    ) {
        coordinator.handle?.detach(from: uiViewController)
    }

    @MainActor
    final class Coordinator {
        var handle: CanvasEmbeddedEditorHandle?

        init(handle: CanvasEmbeddedEditorHandle?) {
            self.handle = handle
        }

        func update(
            handle: CanvasEmbeddedEditorHandle?,
            attachedTo viewController: CanvasEditorViewController
        ) {
            if let existingHandle = self.handle,
               let handle,
               existingHandle !== handle {
                existingHandle.detach(from: viewController)
            } else if handle == nil {
                self.handle?.detach(from: viewController)
            }

            self.handle = handle
            self.handle?.attach(to: viewController)
        }
    }
}
#endif
