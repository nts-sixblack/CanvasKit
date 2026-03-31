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

    func makeBackgroundEditorInput(imageData: Data, mimeType: String) -> CanvasEditorInput? {
        guard let image = UIImage(data: imageData),
              image.size.width > 0,
              image.size.height > 0 else {
            return nil
        }

        let now = Date()
        let project = CanvasProject(
            templateID: "example-photo-background",
            canvasSize: CanvasSize(image.size),
            background: .image(.inlineImage(data: imageData, mimeType: mimeType)),
            nodes: [],
            metadata: CanvasProjectMetadata(createdAt: now, modifiedAt: now)
        )
        return .project(project)
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

    fileprivate static func storageDirectory() -> URL {
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

@MainActor
final class CanvasKitExampleSignatureStore: CanvasSignatureStore {
    static let shared = CanvasKitExampleSignatureStore()

    private var cachedSignatures: [CanvasSignatureDescriptor]?

    func loadSignatures() async throws -> [CanvasSignatureDescriptor] {
        if let cachedSignatures {
            return cachedSignatures
        }

        let signaturesURL = Self.signaturesURL()
        guard let data = try? Data(contentsOf: signaturesURL) else {
            cachedSignatures = []
            return []
        }

        let signatures = try JSONDecoder().decode([CanvasSignatureDescriptor].self, from: data)
        cachedSignatures = signatures
        return signatures
    }

    func saveSignature(_ signature: CanvasSignatureDescriptor) async throws -> CanvasSignatureDescriptor {
        let folderURL = CanvasKitExampleStore.storageDirectory()
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        var signatures = try await loadSignatures()
        signatures.removeAll(where: { $0.id == signature.id })
        signatures.insert(signature, at: 0)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(signatures)
        try data.write(to: Self.signaturesURL(), options: .atomic)
        cachedSignatures = signatures
        return signature
    }

    func deleteSignature(id: String) async throws {
        let folderURL = CanvasKitExampleStore.storageDirectory()
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        var signatures = try await loadSignatures()
        signatures.removeAll(where: { $0.id == id })

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(signatures)
        try data.write(to: Self.signaturesURL(), options: .atomic)
        cachedSignatures = signatures
    }

    private static func signaturesURL() -> URL {
        CanvasKitExampleStore.storageDirectory()
            .appendingPathComponent("signatures.json")
    }
}
