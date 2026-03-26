import Foundation

public enum CanvasTemplateLoader {
    public static func loadTemplates(configuration: CanvasEditorConfiguration) -> [CanvasTemplate] {
        loadTemplates(
            catalog: configuration.templates,
            resources: configuration.resources
        )
    }

    public static func loadTemplates(
        catalog: CanvasTemplateCatalog,
        resources: CanvasEditorResources
    ) -> [CanvasTemplate] {
        var loadedTemplates = catalog.templates
        let decoder = JSONDecoder()

        for fileName in catalog.bundledFileNames {
            for bundle in resources.templateBundles {
                let directURL = bundle.url(
                    forResource: fileName,
                    withExtension: "json",
                    subdirectory: catalog.bundleSubdirectory
                )
                let fallbackURL = bundle
                    .urls(
                        forResourcesWithExtension: "json",
                        subdirectory: catalog.bundleSubdirectory
                    )?
                    .first(where: {
                        $0.deletingPathExtension().lastPathComponent == fileName
                    })
                let rootFallbackURL = bundle
                    .urls(forResourcesWithExtension: "json", subdirectory: nil)?
                    .first(where: {
                        $0.deletingPathExtension().lastPathComponent == fileName
                    })

                guard let url = directURL ?? fallbackURL ?? rootFallbackURL else {
                    continue
                }

                if let template = decodeTemplate(at: url, using: decoder) {
                    loadedTemplates.append(template)
                    break
                }
            }
        }

        if catalog.bundledFileNames.isEmpty {
            for bundle in resources.templateBundles {
                let urls = bundle.urls(
                    forResourcesWithExtension: "json",
                    subdirectory: catalog.bundleSubdirectory
                ) ?? []
                for url in urls {
                    if let template = decodeTemplate(at: url, using: decoder) {
                        loadedTemplates.append(template)
                    }
                }
            }
        }

        for url in catalog.externalURLs {
            if let template = decodeTemplate(at: url, using: decoder) {
                loadedTemplates.append(template)
            }
        }

        var templatesByID: [String: CanvasTemplate] = [:]
        for template in loadedTemplates {
            templatesByID[template.id] = template
        }

        return templatesByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func decodeTemplate(
        at url: URL,
        using decoder: JSONDecoder
    ) -> CanvasTemplate? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(CanvasTemplate.self, from: data)
    }
}
