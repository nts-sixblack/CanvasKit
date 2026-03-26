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
