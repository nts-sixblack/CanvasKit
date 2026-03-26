# CanvasKit

Reusable Swift Package for iOS canvas editing with:

- `CanvasKitCore`: schema, store, history, template/project loading, configuration
- `CanvasKitUIKit`: UIKit editor controller and rendering/runtime helpers
- `CanvasKitSwiftUI`: SwiftUI wrapper around the UIKit editor

Current release: `1.0.0`

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

Example client code lives in [`Example/CanvasKitExample/README.md`](Example/CanvasKitExample/README.md).

## Docs

- [`Docs/CONFIGURATION.md`](Docs/CONFIGURATION.md)
- [`Docs/RESOURCES.md`](Docs/RESOURCES.md)
- [`Docs/TEMPLATES.md`](Docs/TEMPLATES.md)
- [`Docs/UPDATING.md`](Docs/UPDATING.md)
