# Templates

Templates use the `CanvasTemplate` JSON schema already present in the sample project.

## Load templates

```swift
let templates = CanvasTemplateLoader.loadTemplates(configuration: .default)
```

## Provide your own bundle files

```swift
var configuration = CanvasEditorConfiguration.default
configuration.templates = CanvasTemplateCatalog(
    bundledFileNames: ["StoryA", "StoryB"],
    bundleSubdirectory: "CanvasTemplates"
)
```

## Provide embedded or remote files

```swift
configuration.templates = CanvasTemplateCatalog(
    templates: [customTemplate],
    externalURLs: [urlToJSON]
)
```

Bundled, embedded, and external templates are merged and de-duplicated by `template.id`.

## Schema notes

The current template and project schema version is `7`.

Text nodes can now persist two optional behavior flags:

- `style.isJustified`
- `isPermanent`

If either field is omitted, CanvasKit decodes it as `false` so older template and
project JSON keeps loading without migration.

Example text node payload:

```json
{
  "kind": "text",
  "transform": {
    "position": { "x": 540, "y": 320 },
    "rotation": 0,
    "scale": 1
  },
  "size": {
    "width": 420,
    "height": 180
  },
  "zIndex": 0,
  "text": "Headline",
  "isPermanent": true,
  "style": {
    "fontFamily": "Avenir Next",
    "fontSize": 72,
    "foregroundColor": {
      "red": 1,
      "green": 1,
      "blue": 1,
      "alpha": 1
    },
    "alignment": "center",
    "isJustified": false
  }
}
```

When `isPermanent` is `true`, the stored `size`, `position`, `scale`, and
`rotation` become the fixed frame for the text node. At runtime, `style.fontSize`
acts as the maximum preferred size while CanvasKit auto-fits the effective font
size to keep the full text inside that frame.
