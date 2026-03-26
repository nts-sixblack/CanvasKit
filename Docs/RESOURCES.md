# Resources

CanvasKit resolves package and host resources through `CanvasEditorResources`.

## Bundles

- `assetBundles`
  - searched for `.bundleImage(named:)` assets
- `templateBundles`
  - searched for template JSON files
- `fontBundles`
  - searched when auto-registering bundled fonts

Default behavior searches the package bundle first, then `Bundle.main`.

## Fonts

Register packaged fonts by listing file names in `configuration.fonts.bundledFontFiles`.

```swift
var configuration = CanvasEditorConfiguration.default
configuration.fonts = CanvasFontCatalog(
    families: ["Sora", "Avenir Next"],
    bundledFontFiles: ["Sora-Bold.ttf", "Sora-Regular.ttf"]
)
```

CanvasKit registers those files once per process from `configuration.resources.fontBundles`.

## Images

`CanvasAssetSource` supports:

- `.bundleImage(named:)`
- `.symbol(named:)`
- `.remoteURL(_:)`
- `.inlineImage(data:mimeType:)`

For `bundleImage`, CanvasKit checks every bundle in `assetBundles`.
