# Configuration

`CanvasEditorConfiguration` drives editor behavior and appearance.

## Main groups

- `fonts`
  - font family catalog for text nodes
  - optional bundled font files to auto-register from configured bundles
- `stickers`
  - sticker catalog used by the sticker picker
- `signatures`
  - shared signature provider plus signature-specific drawing defaults
- `colors`
  - editor palette for text/background/shadow/outline and brush color selection
- `features`
  - enabled tools and feature flags
- `theme`
  - chrome colors and font descriptors for the editor UI
- `icons`
  - SF Symbol names used by toolbar, inspectors, layer panel, and handles
- `strings`
  - all primary user-facing copy inside the editor chrome
- `layout`
  - key layout metrics for toolbar, inspector, overlay, and panel spacing
  - `overlayHandleSize` is the base on-screen size for selection handles; runtime scales it to the displayed canvas with built-in min/max clamps
- `resources`
  - bundle resolution for assets, fonts, and template JSON
- `templates`
  - bundled file names, embedded templates, and external JSON URLs

## Typical override

```swift
var configuration = CanvasEditorConfiguration.default
configuration.features.enabledTools = [.addText, .addImage, .addBrush, .export]
configuration.features.showsEmbeddedLayersButton = false
configuration.theme.accentColor = CanvasColor(hex: "006C67")
configuration.theme.sheetTitleFont = .init(
    familyName: "Avenir Next",
    pointSize: 17,
    weight: .heavy
)
configuration.strings.exportButtonTitle = "Save"
configuration.icons.addStickerTool = "seal.fill"

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
configuration.signatures = CanvasSignatureConfiguration(store: signatureStore)
configuration.features.enabledTools.append(.addSignature)
```

`configuration.signatures.palette` defaults to `configuration.colors`.
`configuration.signatures.store` is the shared source of truth, so multiple editor instances can reuse the same saved signatures when they receive the same store instance.
`configuration.features.allowsColorPicker` enables the system color picker in text, brush, and signature color inspectors in addition to the configured palette.
Visible swatches keep a default border so light colors such as white remain distinguishable against the editor surfaces.
In embedded presentations, `.undo` and `.redo` are now honored from `configuration.features.enabledTools`. In both embedded and fullscreen presentations, the bottom toolbar is automatically hidden when no primary toolbar tools are left after filtering.
The floating Layers button is only shown when the project has at least 2 nodes; when fewer, the button is hidden and the layer panel auto-dismisses if it was open.
Set `configuration.features.showsEmbeddedLayersButton = false` to hide the embedded layers button while leaving fullscreen chrome unchanged.

## Legacy aliases

These aliases remain available for convenience:

- `fontCatalog`
- `stickerCatalog`
- `colorPalette`
- `enabledTools`

They proxy to the new grouped configuration.
