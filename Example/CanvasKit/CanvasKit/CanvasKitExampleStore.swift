import CanvasKitCore
import Combine
import Foundation
import UIKit

@MainActor
final class CanvasKitExampleStore: ObservableObject {
    @Published private(set) var templates: [CanvasTemplate] = []
    @Published private(set) var savedDocument: SavedCanvasDocument?
    @Published private(set) var savedBatchPDFDocument: SavedCanvasPDFDocument?

    let configuration: CanvasEditorConfiguration

    init(configuration: CanvasEditorConfiguration) {
        self.configuration = configuration
        templates = CanvasTemplateLoader.loadTemplates(configuration: configuration)
        loadSavedDocument()
        loadSavedBatchPDFDocument()
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

    func saveBatchPDF(pages: [BatchPDFPage]) throws -> SavedCanvasPDFDocument {
        guard !pages.isEmpty else {
            throw CanvasKitExamplePDFError.emptyExport
        }

        let folderURL = Self.storageDirectory()
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        let previewImage = try Self.makeBatchPreviewImage(from: pages)
        guard let previewData = previewImage.pngData() else {
            throw CanvasKitExamplePDFError.previewEncodingFailed
        }

        let pdfData = try Self.makeBatchPDFData(from: previewImage)
        let previewURL = folderURL.appendingPathComponent("last-batch-export-preview.png")
        let pdfURL = folderURL.appendingPathComponent("last-batch-export.pdf")
        let metadataURL = folderURL.appendingPathComponent("last-batch-export.json")
        let exportedAt = Date()

        try previewData.write(to: previewURL, options: .atomic)
        try pdfData.write(to: pdfURL, options: .atomic)
        let metadata = BatchPDFExportMetadata(itemCount: pages.count, exportedAt: exportedAt)
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)

        let document = SavedCanvasPDFDocument(
            previewImage: previewImage,
            pdfURL: pdfURL,
            previewURL: previewURL,
            itemCount: pages.count,
            exportedAt: exportedAt
        )
        savedBatchPDFDocument = document
        return document
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

    private func loadSavedBatchPDFDocument() {
        let folderURL = Self.storageDirectory()
        let previewURL = folderURL.appendingPathComponent("last-batch-export-preview.png")
        let pdfURL = folderURL.appendingPathComponent("last-batch-export.pdf")
        let metadataURL = folderURL.appendingPathComponent("last-batch-export.json")

        guard FileManager.default.fileExists(atPath: pdfURL.path),
              let previewData = try? Data(contentsOf: previewURL),
              let previewImage = UIImage(data: previewData) else {
            return
        }

        let metadata = (try? Data(contentsOf: metadataURL))
            .flatMap { try? JSONDecoder().decode(BatchPDFExportMetadata.self, from: $0) }
        let itemCount = metadata?.itemCount ?? 0
        let exportedAt = metadata?.exportedAt ?? Date()

        savedBatchPDFDocument = SavedCanvasPDFDocument(
            previewImage: previewImage,
            pdfURL: pdfURL,
            previewURL: previewURL,
            itemCount: itemCount,
            exportedAt: exportedAt
        )
    }

    private static func makeBatchPreviewImage(from pages: [BatchPDFPage]) throws -> UIImage {
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 28
        let interSectionSpacing: CGFloat = 28
        let titleBottomSpacing: CGFloat = 14
        let titleBlockHeight: CGFloat = 52
        let pageWidth: CGFloat = 1_024
        let contentWidth = pageWidth - (horizontalPadding * 2)
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 15, weight: .medium)

        struct Layout {
            let page: BatchPDFPage
            let imageHeight: CGFloat
        }

        let layouts: [Layout] = pages.map { page in
            let sourceWidth = max(page.image.size.width, 1)
            let imageHeight = max((page.image.size.height / sourceWidth) * contentWidth, 1)
            return Layout(page: page, imageHeight: imageHeight)
        }

        let totalHeight = layouts.reduce(verticalPadding) { partialResult, layout in
            partialResult + titleBlockHeight + titleBottomSpacing + layout.imageHeight + interSectionSpacing
        } + verticalPadding - interSectionSpacing

        guard totalHeight > 0 else {
            throw CanvasKitExamplePDFError.previewGenerationFailed
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(
            size: CGSize(width: pageWidth, height: totalHeight),
            format: format
        ).image { context in
            let cgContext = context.cgContext

            UIColor.white.setFill()
            cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: totalHeight))

            var currentY = verticalPadding

            for (index, layout) in layouts.enumerated() {
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor.label
                ]
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]

                layout.page.title.draw(
                    in: CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: 28),
                    withAttributes: titleAttributes
                )
                let subtitleY = currentY + 30
                "Edit item \(index + 1)".draw(
                    in: CGRect(x: horizontalPadding, y: subtitleY, width: contentWidth, height: 20),
                    withAttributes: subtitleAttributes
                )

                currentY += titleBlockHeight + titleBottomSpacing

                let imageRect = CGRect(
                    x: horizontalPadding,
                    y: currentY,
                    width: contentWidth,
                    height: layout.imageHeight
                )

                cgContext.saveGState()
                UIBezierPath(
                    roundedRect: imageRect,
                    cornerRadius: 24
                ).addClip()
                layout.page.image.draw(in: imageRect)
                cgContext.restoreGState()

                UIColor(
                    red: 0.87,
                    green: 0.89,
                    blue: 0.93,
                    alpha: 1
                ).setStroke()
                UIBezierPath(
                    roundedRect: imageRect.insetBy(dx: 0.5, dy: 0.5),
                    cornerRadius: 24
                ).stroke()

                currentY += layout.imageHeight + interSectionSpacing
            }
        }
    }

    private static func makeBatchPDFData(from previewImage: UIImage) throws -> Data {
        let bounds = CGRect(origin: .zero, size: previewImage.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { context in
            context.beginPage()
            previewImage.draw(in: bounds)
        }
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

struct BatchPDFPage {
    let title: String
    let image: UIImage
}

struct SavedCanvasPDFDocument: Identifiable {
    var id: URL { pdfURL }

    let previewImage: UIImage
    let pdfURL: URL
    let previewURL: URL
    let itemCount: Int
    let exportedAt: Date
}

private struct BatchPDFExportMetadata: Codable {
    let itemCount: Int
    let exportedAt: Date
}

enum CanvasKitExamplePDFError: LocalizedError {
    case emptyExport
    case previewGenerationFailed
    case previewEncodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyExport:
            return "There are no edited items available to export."
        case .previewGenerationFailed:
            return "The combined preview image for the PDF could not be generated."
        case .previewEncodingFailed:
            return "The combined preview image could not be encoded before writing the PDF."
        }
    }
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
