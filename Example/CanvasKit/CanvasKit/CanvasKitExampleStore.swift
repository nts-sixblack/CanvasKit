import CanvasKitCore
import Combine
import Foundation
import UIKit

@MainActor
final class CanvasKitExampleStore: ObservableObject {
    @Published private(set) var templates: [CanvasTemplate] = []
    @Published private(set) var savedDocument: SavedCanvasDocument?

    let configuration: CanvasEditorConfiguration

    init(configuration: CanvasEditorConfiguration) {
        self.configuration = configuration
        templates = CanvasTemplateLoader.loadTemplates(configuration: configuration)
        loadSavedDocument()
    }

    func save(result: CanvasEditorResult, previewImage: UIImage) {
        let folderURL = Self.storageDirectory()
        let fileManager = FileManager.default

        try? fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        let imageURL = folderURL.appendingPathComponent("last-export.png")
        let projectURL = folderURL.appendingPathComponent("last-project.json")

        try? result.imageData.write(to: imageURL, options: .atomic)
        try? result.projectData.write(to: projectURL, options: .atomic)

        let project = try? JSONDecoder().decode(CanvasProject.self, from: result.projectData)
        savedDocument = SavedCanvasDocument(
            previewImage: previewImage,
            project: project,
            imageURL: imageURL,
            projectURL: projectURL
        )
    }

    private func loadSavedDocument() {
        let folderURL = Self.storageDirectory()
        let imageURL = folderURL.appendingPathComponent("last-export.png")
        let projectURL = folderURL.appendingPathComponent("last-project.json")

        guard let imageData = try? Data(contentsOf: imageURL),
              let previewImage = UIImage(data: imageData) else {
            return
        }

        let project = (try? Data(contentsOf: projectURL))
            .flatMap { try? JSONDecoder().decode(CanvasProject.self, from: $0) }

        savedDocument = SavedCanvasDocument(
            previewImage: previewImage,
            project: project,
            imageURL: imageURL,
            projectURL: projectURL
        )
    }

    private static func storageDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CanvasKitExample", isDirectory: true)
    }
}

struct SavedCanvasDocument {
    let previewImage: UIImage
    let project: CanvasProject?
    let imageURL: URL
    let projectURL: URL
}
