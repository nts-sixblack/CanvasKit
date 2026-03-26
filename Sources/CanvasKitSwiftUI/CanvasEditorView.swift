#if canImport(UIKit)
import SwiftUI
import UIKit
import CanvasKitCore
import CanvasKitUIKit

public struct CanvasEditorView: View {
    public let input: CanvasEditorInput
    public let configuration: CanvasEditorConfiguration
    public let onCancel: () -> Void
    public let onExport: (CanvasEditorResult, UIImage) -> Void

    public init(
        input: CanvasEditorInput,
        configuration: CanvasEditorConfiguration = .default,
        onCancel: @escaping () -> Void,
        onExport: @escaping (CanvasEditorResult, UIImage) -> Void
    ) {
        self.input = input
        self.configuration = configuration
        self.onCancel = onCancel
        self.onExport = onExport
    }

    public var body: some View {
        CanvasEditorContainerView(
            input: input,
            configuration: configuration,
            onCancel: onCancel,
            onExport: onExport
        )
        .ignoresSafeArea(.keyboard)
    }
}

private struct CanvasEditorContainerView: UIViewControllerRepresentable {
    let input: CanvasEditorInput
    let configuration: CanvasEditorConfiguration
    let onCancel: () -> Void
    let onExport: (CanvasEditorResult, UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onExport: onExport)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let viewController = CanvasEditorViewController(
            input: input,
            configuration: configuration
        )
        viewController.delegate = context.coordinator

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.navigationBar.tintColor = UIColor(canvasColor: configuration.theme.primaryTextColor)
        navigationController.navigationBar.barStyle = .default
        navigationController.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(canvasColor: configuration.theme.primaryTextColor)
        ]
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    func updateUIViewController(
        _ uiViewController: UINavigationController,
        context: Context
    ) {}

    final class Coordinator: NSObject, CanvasEditorViewControllerDelegate {
        private let onCancel: () -> Void
        private let onExport: (CanvasEditorResult, UIImage) -> Void

        init(
            onCancel: @escaping () -> Void,
            onExport: @escaping (CanvasEditorResult, UIImage) -> Void
        ) {
            self.onCancel = onCancel
            self.onExport = onExport
        }

        func canvasEditorViewControllerDidCancel(
            _ viewController: CanvasEditorViewController
        ) {
            onCancel()
        }

        func canvasEditorViewController(
            _ viewController: CanvasEditorViewController,
            didExport result: CanvasEditorResult,
            previewImage: UIImage
        ) {
            onExport(result, previewImage)
        }
    }
}

public extension Color {
    init(canvasColor: CanvasColor) {
        self.init(
            red: canvasColor.red,
            green: canvasColor.green,
            blue: canvasColor.blue,
            opacity: canvasColor.alpha
        )
    }
}

private extension UIColor {
    convenience init(canvasColor: CanvasColor) {
        self.init(
            red: canvasColor.red,
            green: canvasColor.green,
            blue: canvasColor.blue,
            alpha: canvasColor.alpha
        )
    }
}
#endif
