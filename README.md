# CanvasKit

Reusable Swift Package for iOS canvas editing with:

- `CanvasKitCore`: schema, store, history, template/project loading, configuration
- `CanvasKitUIKit`: UIKit editor controller and rendering/runtime helpers
- `CanvasKitSwiftUI`: SwiftUI wrapper around the UIKit editor

Current release: `1.0.1`

The package is built so host apps can theme and configure editor chrome at runtime:

- colors
- fonts
- SF Symbol icons
- text labels
- tool availability
- sticker catalog
- bundled or host-provided assets
- bundled or host-provided template JSON

## Installation

Add this repository to your app with Swift Package Manager, then import the product you need:

- `CanvasKitCore`
- `CanvasKitUIKit`
- `CanvasKitSwiftUI`

## Quick Start

### SwiftUI

```swift
import CanvasKitCore
import CanvasKitSwiftUI
import SwiftUI

struct EditorHostView: View {
    @State private var isPresented = false
    private let template = CanvasTemplateLoader
        .loadTemplates(configuration: .default)
        .first!

    var body: some View {
        Button("Open Editor") {
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            CanvasEditorView(
                input: .template(template),
                configuration: .default,
                onCancel: {
                    isPresented = false
                },
                onExport: { result, previewImage in
                    print(result.imageData.count, previewImage.size)
                    isPresented = false
                }
            )
        }
    }
}
```

`CanvasEditorView` already ignores the keyboard safe area, so presenting it in a
regular SwiftUI `.sheet` keeps the canvas layout stable while inline text editing
is active.

Push the editor inside a `NavigationStack` by switching the hosting style:

```swift
import CanvasKitCore
import CanvasKitSwiftUI
import SwiftUI

struct NavigationEditorHostView: View {
    @State private var path: [Route] = []
    private let configuration = CanvasEditorConfiguration.default
    private let template = CanvasTemplateLoader
        .loadTemplates(configuration: .default)
        .first!

    var body: some View {
        NavigationStack(path: $path) {
            Button("Edit Template") {
                path.append(.editor)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .editor:
                    NavigationEditorScreen(
                        template: template,
                        configuration: configuration
                    )
                }
            }
        }
    }
}

private struct NavigationEditorScreen: View {
    let template: CanvasTemplate
    let configuration: CanvasEditorConfiguration

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CanvasEditorView(
            input: .template(template),
            configuration: configuration,
            hostingStyle: .navigationStack,
            onCancel: {
                dismiss()
            },
            onExport: { result, previewImage in
                print(result.projectData.count, previewImage.size)
                dismiss()
            }
        )
    }
}

private enum Route: Hashable {
    case editor
}
```

`hostingStyle: .navigationStack` hides the outer SwiftUI navigation bar so the
editor keeps using its own navigation chrome for close and export actions.

### UIKit

```swift
import CanvasKitCore
import CanvasKitUIKit
import UIKit

final class HostViewController: UIViewController, CanvasEditorViewControllerDelegate {
    func openEditor() {
        let configuration = CanvasEditorConfiguration.default
        let template = CanvasTemplateLoader
            .loadTemplates(configuration: configuration)
            .first!

        let controller = CanvasEditorViewController(
            input: .template(template),
            configuration: configuration
        )
        controller.delegate = self

        let navigationController = UINavigationController(rootViewController: controller)
        present(navigationController, animated: true)
    }

    func canvasEditorViewControllerDidCancel(_ viewController: CanvasEditorViewController) {
        dismiss(animated: true)
    }

    func canvasEditorViewController(
        _ viewController: CanvasEditorViewController,
        didExport result: CanvasEditorResult,
        previewImage: UIImage
    ) {
        print(result.projectData.count, previewImage.size)
        dismiss(animated: true)
    }
}
```

## Configuration

`CanvasEditorConfiguration` is the single source of truth for editor setup.

```swift
var configuration = CanvasEditorConfiguration.default

configuration.theme = CanvasEditorTheme(
    canvasBackdropColor: CanvasColor(hex: "F7F4EF"),
    accentColor: CanvasColor(hex: "006C67"),
    toolbarLabelFont: .init(familyName: "Avenir Next", pointSize: 14, weight: .semibold),
    inspectorTitleFont: .init(familyName: "Avenir Next", pointSize: 18, weight: .heavy)
)

configuration.icons = CanvasEditorIconSet(
    addTextTool: "character.textbox",
    addEmojiTool: "face.smiling.inverse",
    addStickerTool: "seal.fill",
    colorPickerFilled: "paintpalette.fill"
)

configuration.strings = CanvasEditorStrings(
    closeButtonTitle: "Done",
    exportButtonTitle: "Save",
    textInspectorTitle: "Typography",
    layerPanelTitle: "Stack"
)
```

`configuration.templates` controls bundled and external template sources.
`configuration.resources` controls which bundles are used for assets, fonts, and templates.

## Included Resources

Default templates are bundled inside the package:

- `Poster45`
- `PortraitStory`
- `SquareVibes`

Load them with `CanvasTemplateLoader`.

## Example

Example client code lives in [`Example/CanvasKit/CanvasKit/ContentView.swift`](Example/CanvasKit/CanvasKit/ContentView.swift).

## Docs

- [`Docs/CONFIGURATION.md`](Docs/CONFIGURATION.md)
- [`Docs/RESOURCES.md`](Docs/RESOURCES.md)
- [`Docs/TEMPLATES.md`](Docs/TEMPLATES.md)
- [`Docs/UPDATING.md`](Docs/UPDATING.md)
