# CanvasKit

Reusable Swift Package for iOS canvas editing with:

- `CanvasKitCore`: schema, store, history, template/project loading, configuration
- `CanvasKitUIKit`: UIKit editor controller and rendering/runtime helpers
- `CanvasKitSwiftUI`: SwiftUI wrapper around the UIKit editor

Current release: `2.5.0`

The package is built so host apps can theme and configure editor chrome at runtime:

- colors
- fonts
- SF Symbol icons
- text labels
- tool availability
- sticker catalog
- provider-backed signature library
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
import CanvasKitUIKit
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

Embed the editor inside an existing screen and trigger save from the host app:

```swift
import CanvasKitCore
import CanvasKitSwiftUI
import SwiftUI

struct EmbeddedEditorHostView: View {
    @State private var handle = CanvasEmbeddedEditorHandle()

    let template: CanvasTemplate
    let configuration: CanvasEditorConfiguration

    var body: some View {
        CanvasEmbeddedEditorView(
            input: .template(template),
            configuration: configuration,
            handle: handle
        )
        .navigationTitle("Embedded Editor")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    handle.exportCurrentCanvas { result in
                        switch result {
                        case .success(let output):
                            print(output.result.projectData.count, output.previewImage.size)
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
```

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

To embed the UIKit controller as a child view controller, initialize it with
`mode: .embedded` and call `exportCurrentCanvas(...)` from the host screen when
you want to save:

```swift
let controller = CanvasEditorViewController(
    input: .template(template),
    configuration: configuration,
    mode: .embedded
)

controller.exportCurrentCanvas { result in
    switch result {
    case .success(let output):
        print(output.result.imageData.count, output.previewImage.size)
    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

Empty masked template slots still show their add-photo affordance while editing,
but that `+` marker is omitted from rendered exports.

Text nodes also support two runtime behavior flags:

- `CanvasTextStyle.isJustified` forces justified paragraph layout while preserving the stored leading/center/trailing alignment for later reuse
- `CanvasNode.isPermanent` locks the current text frame and transform, then treats `style.fontSize` as the maximum preferred size while runtime layout auto-fits the effective font size for display, inline editing, and export

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
    addSignatureTool: "signature",
    colorPickerFilled: "paintpalette.fill"
)

configuration.strings = CanvasEditorStrings(
    closeButtonTitle: "Done",
    exportButtonTitle: "Save",
    textInspectorTitle: "Typography",
    layerPanelTitle: "Stack"
)

@MainActor
final class SharedSignatureStore: CanvasSignatureStore {
    private var signatures: [CanvasSignatureDescriptor] = []

    func loadSignatures() async throws -> [CanvasSignatureDescriptor] {
        signatures
    }

    func saveSignature(_ signature: CanvasSignatureDescriptor) async throws -> CanvasSignatureDescriptor {
        signatures.insert(signature, at: 0)
        return signature
    }

    func deleteSignature(id: String) async throws {
        signatures.removeAll { $0.id == id }
    }
}

let signatureStore = SharedSignatureStore()
configuration.signatures = CanvasSignatureConfiguration(
    store: signatureStore,
    defaultColor: .black,
    defaultLineWidth: 4
)
configuration.features.enabledTools = [
    .addText,
    .addImage,
    .addBrush,
    .undo,
    .redo,
    .export,
    .addSignature
]
configuration.features.showsEmbeddedLayersButton = false
```

`configuration.templates` controls bundled and external template sources.
`configuration.resources` controls which bundles are used for assets, fonts, and templates.
`configuration.signatures` controls the shared signature library used by the signature tool. The tool is only shown when `.addSignature` is enabled and a signature store is configured.
`configuration.signatures.defaultLineWidth` sets the stroke width used by the signature composer.
`configuration.features.allowsColorPicker` controls whether the system color picker is available alongside palette swatches for text and brush color selection. Signature creation uses the configured signature palette only.
Visible color swatches include a default border so light colors such as white stay legible against the editor chrome.
In `mode: .embedded`, `configuration.features.enabledTools` now also controls whether `undo` and `redo` are rendered. In both embedded and fullscreen presentations, the bottom tool strip is removed entirely when no primary toolbar tools remain after filtering.
The floating Layers button is only shown when the project has at least 2 nodes; when fewer, the button is hidden and the panel auto-dismisses if it was open.
Use `configuration.features.showsEmbeddedLayersButton = false` to always hide the embedded layers button without affecting fullscreen editor chrome.
Text inspector copy can now customize `behaviorSectionTitle`, `justifyToggleTitle`, and `permanentToggleTitle`.
Setting `CanvasTextStyle.isJustified = true` uses justified paragraph layout without overwriting `alignment`, so turning justify back off restores the previous leading/center/trailing choice.
Setting `CanvasNode.isPermanent = true` keeps the node's current frame, hides text resize and transform handles, blocks drag/pinch/rotation manipulation, and auto-fits the effective font size using `configuration.layout.textContentInset` as the shared measurement inset.

## Included Resources

Default templates are bundled inside the package:

- `Poster45`
- `PortraitStory`
- `SquareVibes`

Load them with `CanvasTemplateLoader`.

CanvasKit also bundles Unicode emoji keyboard data (`emoji-test.txt`) used by the emoji picker. See `Docs/RESOURCES.md` for details and Unicode terms of use.

## Example

Example client code lives in [`Example/CanvasKit/CanvasKit/ContentView.swift`](Example/CanvasKit/CanvasKit/ContentView.swift).

## Docs

- [`Docs/CONFIGURATION.md`](Docs/CONFIGURATION.md)
- [`Docs/RESOURCES.md`](Docs/RESOURCES.md)
- [`Docs/TEMPLATES.md`](Docs/TEMPLATES.md)
- [`Docs/UPDATING.md`](Docs/UPDATING.md)
