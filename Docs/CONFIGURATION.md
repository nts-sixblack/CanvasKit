# Configuration

`CanvasEditorConfiguration` drives editor behavior and appearance.

## Main groups

- `fonts`
  - font family catalog for text nodes
  - optional bundled font files to auto-register from configured bundles
- `stickers`
  - sticker catalog used by the sticker picker
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
- `resources`
  - bundle resolution for assets, fonts, and template JSON
- `templates`
  - bundled file names, embedded templates, and external JSON URLs

## Typical override

```swift
var configuration = CanvasEditorConfiguration.default
configuration.features.enabledTools = [.addText, .addImage, .addBrush, .export]
configuration.theme.accentColor = CanvasColor(hex: "006C67")
configuration.theme.sheetTitleFont = .init(
    familyName: "Avenir Next",
    pointSize: 17,
    weight: .heavy
)
configuration.strings.exportButtonTitle = "Save"
configuration.icons.addStickerTool = "seal.fill"
```

## Legacy aliases

These aliases remain available for convenience:

- `fontCatalog`
- `stickerCatalog`
- `colorPalette`
- `enabledTools`

They proxy to the new grouped configuration.
