//
//  ContentView.swift
//  CanvasKit
//
//  Created by Sau Nguyen on 26/3/26.
//

import CanvasKitCore
import CanvasKitUIKit
import CanvasKitSwiftUI
import Foundation
import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject private var store = CanvasKitExampleStore(
        configuration: CanvasKitExampleConfiguration.makeEditorConfiguration()
    )
    @State private var navigationPath: [EditorDemoRoute] = []
    @State private var selectedBackgroundItem: PhotosPickerItem?
    @State private var backgroundSelectionID = UUID()
    @State private var isImportingBackground = false
    @State private var backgroundImportError: String?
    @State private var isShowingTemplateImporter = false
    @State private var projectFolderTemplates: [StoredProjectFolderTemplate] = []
    @State private var isImportingTemplate = false
    @State private var templateImportError: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    PhotosPicker(
                        selection: backgroundPickerSelection,
                        matching: .images
                    ) {
                        Label("Pick Background Photo", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(isImportingBackground)

                    if isImportingBackground {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing photo background…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("The selected photo is passed to the editor as the canvas background, so it cannot be selected, moved, or resized.")
                }

                Section {
                    if projectFolderTemplates.isEmpty {
                        Text("No project folders found in Application Support/CanvasKitExample/Template.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(projectFolderTemplates) { template in
                            Button {
                                importProjectFolder(at: template.url)
                            } label: {
                                Label(template.name, systemImage: "folder")
                            }
                            .disabled(isImportingTemplate)
                        }
                    }

                    Button {
                        isShowingTemplateImporter = true
                    } label: {
                        Label("Pick JSON Template", systemImage: "doc.badge.plus")
                    }
                    .disabled(isImportingTemplate)

                    if isImportingTemplate {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Importing…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Open project export folders stored in Application Support/CanvasKitExample/Template, or import a template JSON file.")
                }

                Section("Fullscreen Templates") {
                    ForEach(store.templates) { template in
                        Button(template.name) {
                            navigationPath.append(
                                EditorDemoRoute(
                                    input: .template(template),
                                    presentation: .fullscreen
                                )
                            )
                        }
                    }
                }

                Section("Embedded Templates") {
                    ForEach(store.templates) { template in
                        Button(template.name) {
                            navigationPath.append(
                                EditorDemoRoute(
                                    input: .template(template),
                                    presentation: .embedded
                                )
                            )
                        }
                    }
                }

                Section("Batch PDF Export") {
                    NavigationLink {
                        CanvasBatchPDFExampleScreen(store: store)
                    } label: {
                        Label("Open Multi-Item PDF Demo", systemImage: "rectangle.split.3x1")
                    }

                    Text("This demo keeps several embedded editors independent inside one screen, then exports all edited outputs into a single PDF file.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let savedDocument = store.savedDocument {
                    Section("Last Export") {
                        Image(uiImage: savedDocument.previewImage)
                            .resizable()
                            .scaledToFit()
                            .background {
                                ExampleTransparencyCheckerboard()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button("Resume Last Project") {
                            guard let project = savedDocument.project else {
                                return
                            }
                            navigationPath.append(
                                EditorDemoRoute(
                                    input: .project(project),
                                    presentation: .fullscreen
                                )
                            )
                        }
                        .disabled(savedDocument.project == nil)
                    }
                }

                if let savedBatchPDFDocument = store.savedBatchPDFDocument {
                    Section("Last PDF Export") {
                        Image(uiImage: savedBatchPDFDocument.previewImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        LabeledContent("Items", value: "\(savedBatchPDFDocument.itemCount)")
                        LabeledContent("File", value: savedBatchPDFDocument.pdfURL.lastPathComponent)

                        ShareLink(item: savedBatchPDFDocument.pdfURL) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                loadProjectFolderTemplates()
            }
            .navigationTitle("CanvasKit Example")
            .navigationDestination(for: EditorDemoRoute.self) { route in
                switch route.presentation {
                case .fullscreen:
                    CanvasEditorExampleScreen(
                        input: route.input,
                        store: store
                    )
                case .embedded:
                    CanvasEmbeddedEditorExampleScreen(
                        input: route.input,
                        store: store
                    )
                }
            }
            .task(id: backgroundSelectionID) {
                await importSelectedBackgroundIfNeeded()
            }
            .fileImporter(
                isPresented: $isShowingTemplateImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importTemplate(from: result)
            }
            .alert(
                "Couldn’t Use Photo",
                isPresented: isShowingBackgroundImportError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backgroundImportError ?? "")
            }
            .alert(
                "Couldn’t Import Template",
                isPresented: isShowingTemplateImportError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(templateImportError ?? "")
            }
        }
    }

    private var backgroundPickerSelection: Binding<PhotosPickerItem?> {
        Binding(
            get: { selectedBackgroundItem },
            set: { newValue in
                selectedBackgroundItem = newValue
                if newValue != nil {
                    backgroundSelectionID = UUID()
                }
            }
        )
    }

    private var isShowingBackgroundImportError: Binding<Bool> {
        Binding(
            get: { backgroundImportError != nil },
            set: { isPresented in
                if !isPresented {
                    backgroundImportError = nil
                }
            }
        )
    }

    private var isShowingTemplateImportError: Binding<Bool> {
        Binding(
            get: { templateImportError != nil },
            set: { isPresented in
                if !isPresented {
                    templateImportError = nil
                }
            }
        )
    }

    @MainActor
    private func importSelectedBackgroundIfNeeded() async {
        guard let item = selectedBackgroundItem,
              !isImportingBackground else {
            return
        }

        isImportingBackground = true
        defer {
            isImportingBackground = false
            selectedBackgroundItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self),
                  !imageData.isEmpty else {
                backgroundImportError = "The selected photo could not be loaded from your library."
                return
            }

            let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            guard let input = store.makeBackgroundEditorInput(
                imageData: imageData,
                mimeType: mimeType
            ) else {
                backgroundImportError = "The selected item is not a valid image for the canvas background."
                return
            }

            navigationPath.append(
                EditorDemoRoute(
                    input: input,
                    presentation: .fullscreen
                )
            )
        } catch {
            backgroundImportError = error.localizedDescription
        }
    }

    private func loadProjectFolderTemplates() {
        do {
            let templateDirectory = CanvasKitExampleStore.templateDirectory()
            try FileManager.default.createDirectory(
                at: templateDirectory,
                withIntermediateDirectories: true
            )

            let urls = try FileManager.default.contentsOfDirectory(
                at: templateDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            projectFolderTemplates = try urls.compactMap { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                guard values.isDirectory == true else {
                    return nil
                }

                return StoredProjectFolderTemplate(url: url)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch {
            projectFolderTemplates = []
            templateImportError = error.localizedDescription
        }
    }

    private func importProjectFolder(at folderURL: URL) {
        guard !isImportingTemplate else {
            return
        }

        isImportingTemplate = true
        defer {
            isImportingTemplate = false
        }

        do {
            let projectURL = folderURL.appendingPathComponent("project.json")
            guard FileManager.default.fileExists(atPath: projectURL.path) else {
                throw CanvasProjectFolderImportError.missingProjectJSON
            }

            let data = try Data(contentsOf: projectURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var project = try decoder.decode(CanvasProject.self, from: data)
            let assets = try loadThemeAssets(from: folderURL)
            try inlineBundleImages(in: &project, assets: assets)
            resolveFontPaths(in: &project, baseURL: folderURL)
            navigationPath.append(
                EditorDemoRoute(
                    input: .project(project),
                    presentation: .fullscreen
                )
            )
        } catch {
            templateImportError = error.localizedDescription
        }
    }

    private func loadThemeAssets(from folderURL: URL) throws -> [String: InlineThemeAsset] {
        let assetsURL = folderURL.appendingPathComponent("CanvasThemeAssets", isDirectory: true)
        guard FileManager.default.fileExists(atPath: assetsURL.path) else {
            throw CanvasProjectFolderImportError.missingAssetFolder
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: assetsURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            throw CanvasProjectFolderImportError.missingAssetFolder
        }

        var assets: [String: InlineThemeAsset] = [:]
        for case let imageURL as URL in enumerator {
            let values = try imageURL.resourceValues(forKeys: resourceKeys)
            guard values.isDirectory != true,
                  let mimeType = mimeType(for: imageURL) else {
                continue
            }

            let imageName = imageURL.deletingPathExtension().lastPathComponent
            let imageData = try Data(contentsOf: imageURL)
            assets[imageName] = InlineThemeAsset(
                data: imageData,
                mimeType: mimeType
            )
        }

        return assets
    }

    private func inlineBundleImages(in project: inout CanvasProject, assets: [String: InlineThemeAsset]) throws {
        try inlineBundleImage(&project.background.source, assets: assets)

        for index in project.nodes.indices {
            try inlineBundleImage(&project.nodes[index].source, assets: assets)
            if var maskedImage = project.nodes[index].maskedImage {
                try inlineBundleImage(&maskedImage.maskSource, assets: assets)
                try inlineBundleImage(&maskedImage.overlaySource, assets: assets)
                project.nodes[index].maskedImage = maskedImage
            }
        }
    }

    private func resolveFontPaths(in project: inout CanvasProject, baseURL: URL) {
        for index in project.nodes.indices {
            guard var style = project.nodes[index].style,
                  let fontPath = style.fontPath,
                  URL(fileURLWithPath: fontPath).isFileURL,
                  !fontPath.hasPrefix("/") else {
                continue
            }

            style.fontPath = baseURL.appendingPathComponent(fontPath).path
            project.nodes[index].style = style
        }
    }

    private func inlineBundleImage(_ source: inout CanvasAssetSource?, assets: [String: InlineThemeAsset]) throws {
        guard let currentSource = source else {
            return
        }

        var mutableSource = currentSource
        try inlineBundleImage(&mutableSource, assets: assets)
        source = mutableSource
    }

    private func inlineBundleImage(_ source: inout CanvasAssetSource, assets: [String: InlineThemeAsset]) throws {
        guard source.kind == .bundleImage,
              let name = source.name else {
            return
        }

        guard let asset = assets[name] else {
            throw CanvasProjectFolderImportError.missingAsset(name)
        }

        source = .inlineImage(data: asset.data, mimeType: asset.mimeType)
    }

    private func mimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        default:
            return nil
        }
    }
    private func importTemplate(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            importTemplate(at: url)
        case .failure(let error):
            if isUserCancellation(error) {
                return
            }
            templateImportError = error.localizedDescription
        }
    }

    private func importTemplate(at url: URL) {
        guard !isImportingTemplate else {
            return
        }

        isImportingTemplate = true
        defer {
            isImportingTemplate = false
        }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            if (try? JSONDecoder().decode(CanvasProject.self, from: data)) != nil {
                templateImportError = "The selected JSON file is a CanvasKit project export. Select the project folder from Application Support/CanvasKitExample/Template instead."
                return
            }
            let template = try JSONDecoder().decode(CanvasTemplate.self, from: data)
            store.addImportedTemplate(template)
            navigationPath.append(
                EditorDemoRoute(
                    input: .template(template),
                    presentation: .fullscreen
                )
            )
        } catch is DecodingError {
            templateImportError = "The selected JSON file is not a valid CanvasKit template."
        } catch {
            templateImportError = error.localizedDescription
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.userCancelled.rawValue
    }
}

private struct StoredProjectFolderTemplate: Identifiable {
    let url: URL

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

private struct InlineThemeAsset {
    let data: Data
    let mimeType: String
}

enum CanvasProjectFolderImportError: LocalizedError {
    case missingProjectJSON
    case missingAssetFolder
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case .missingProjectJSON:
            return "The selected folder must contain project.json at its root."
        case .missingAssetFolder:
            return "The selected folder must contain a CanvasThemeAssets image folder."
        case .missingAsset(let name):
            return "The selected project folder is missing the referenced asset: \(name)."
        }
    }
}

private struct CanvasEditorExampleScreen: View {
    let input: CanvasEditorInput
    let store: CanvasKitExampleStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CanvasEditorView(
            input: input,
            configuration: store.configuration,
            hostingStyle: .navigationStack,
            onCancel: {
                dismiss()
            },
            onExport: { result, previewImage in
                store.save(result: result, previewImage: previewImage)
                dismiss()
            }
        )
    }
}

private struct CanvasEmbeddedEditorExampleScreen: View {
    let input: CanvasEditorInput
    let store: CanvasKitExampleStore

    @State private var handle = CanvasEmbeddedEditorHandle()
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var savedPreview: EmbeddedEditorSavedPreview?

    var body: some View {
        CanvasEmbeddedEditorView(
            input: input,
            configuration: store.configuration,
            handle: handle
        )
        .navigationTitle("Embedded Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isExporting {
                    ProgressView()
                } else {
                    Button("Save") {
                        exportCanvas()
                    }
                }
            }
        }
        .sheet(item: $savedPreview) { preview in
            NavigationStack {
                ScrollView {
                    Image(uiImage: preview.image)
                        .resizable()
                        .scaledToFit()
                        .background {
                            ExampleTransparencyCheckerboard()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding()
                }
                .navigationTitle("Saved Preview")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert(
            "Couldn’t Save Canvas",
            isPresented: isShowingExportError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var isShowingExportError: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private func exportCanvas() {
        isExporting = true
        handle.exportCurrentCanvas { exportResult in
            isExporting = false

            switch exportResult {
            case .success(let output):
                store.save(result: output.result, previewImage: output.previewImage)
                savedPreview = EmbeddedEditorSavedPreview(image: output.previewImage)
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
private struct CanvasBatchPDFExampleScreen: View {
    let store: CanvasKitExampleStore

    @State private var sessions: [BatchPDFEditorSession]
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var exportedDocument: SavedCanvasPDFDocument?

    init(store: CanvasKitExampleStore) {
        self.store = store
        _sessions = State(initialValue: Self.makeSessions(from: store.templates))
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Templates Available",
                    systemImage: "rectangle.stack.badge.minus",
                    description: Text("Load templates into the example configuration before trying the PDF demo.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        batchIntroCard

                        ForEach(sessions) { session in
                            BatchPDFEditorCard(
                                session: session,
                                configuration: store.configuration
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationTitle("Batch PDF Demo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isExporting {
                    ProgressView()
                } else {
                    Button("Export PDF") {
                        exportBatchPDF()
                    }
                    .disabled(sessions.isEmpty)
                }
            }
        }
        .sheet(item: $exportedDocument) { document in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(uiImage: document.previewImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        LabeledContent("Items", value: "\(document.itemCount)")
                        LabeledContent("PDF", value: document.pdfURL.lastPathComponent)

                        ShareLink(item: document.pdfURL) {
                            Label("Share PDF File", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .navigationTitle("PDF Ready")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert(
            "Couldn’t Export PDF",
            isPresented: isShowingBatchExportError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var batchIntroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Independent Embedded Editors")
                .font(.headline)

            Text("Each card below is its own editor instance. Export collects every edited result, merges them into one combined preview image, then writes that image into a single PDF file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var isShowingBatchExportError: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func exportBatchPDF() {
        guard !sessions.isEmpty else {
            exportErrorMessage = CanvasKitExamplePDFError.emptyExport.localizedDescription
            return
        }

        isExporting = true
        Task { @MainActor in
            defer {
                isExporting = false
            }

            do {
                let pages = try await exportPages()
                let document = try store.saveBatchPDF(pages: pages)
                exportedDocument = document
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func exportPages() async throws -> [BatchPDFPage] {
        var pages: [BatchPDFPage] = []

        for session in sessions {
            let output = try await exportOutput(for: session)
            pages.append(
                BatchPDFPage(
                    title: session.title,
                    image: output.previewImage
                )
            )
        }

        return pages
    }

    @MainActor
    private func exportOutput(for session: BatchPDFEditorSession) async throws -> CanvasEditorExportOutput {
        try await withCheckedThrowingContinuation { continuation in
            session.handle.exportCurrentCanvas { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func makeSessions(from templates: [CanvasTemplate]) -> [BatchPDFEditorSession] {
        Array(templates.prefix(3).enumerated()).map { index, template in
            BatchPDFEditorSession(
                title: template.name,
                subtitle: "Edit item \(index + 1)",
                input: .template(template)
            )
        }
    }
}

@MainActor
private struct BatchPDFEditorCard: View {
    let session: BatchPDFEditorSession
    let configuration: CanvasEditorConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)

                Text(session.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            CanvasEmbeddedEditorView(
                input: session.input,
                configuration: configuration,
                handle: session.handle
            )
            .frame(height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct ExampleTransparencyCheckerboard: View {
    private let cellSize: CGFloat = 8
    private let lightColor = Color.white
    private let darkColor = Color(red: 0.9, green: 0.9, blue: 0.9)

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(lightColor)
            )

            let rows = Int(ceil(size.height / cellSize))
            let columns = Int(ceil(size.width / cellSize))

            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    let cellRect = CGRect(
                        x: CGFloat(column) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(cellRect), with: .color(darkColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EmbeddedEditorSavedPreview: Identifiable {
    let id = UUID()
    let image: UIImage
}

@MainActor
private struct BatchPDFEditorSession: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let input: CanvasEditorInput
    let handle = CanvasEmbeddedEditorHandle()
}

private struct EditorDemoRoute: Hashable, Identifiable {
    enum Presentation: Hashable {
        case fullscreen
        case embedded
    }

    let id = UUID()
    let input: CanvasEditorInput
    let presentation: Presentation

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
