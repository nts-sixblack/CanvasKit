//
//  ContentView.swift
//  CanvasKit
//
//  Created by Sau Nguyen on 26/3/26.
//

import CanvasKitCore
import CanvasKitSwiftUI
import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = CanvasKitExampleStore(
        configuration: CanvasKitExampleConfiguration.makeEditorConfiguration()
    )
    @State private var activeSession: ActiveEditorSession?

    var body: some View {
        NavigationStack {
            List {
                Section("Templates") {
                    ForEach(store.templates) { template in
                        Button(template.name) {
                            activeSession = ActiveEditorSession(input: .template(template))
                        }
                    }
                }

                if let savedDocument = store.savedDocument {
                    Section("Last Export") {
                        Image(uiImage: savedDocument.previewImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button("Resume Last Project") {
                            guard let project = savedDocument.project else {
                                return
                            }
                            activeSession = ActiveEditorSession(input: .project(project))
                        }
                        .disabled(savedDocument.project == nil)
                    }
                }
            }
            .navigationTitle("CanvasKit Example")
        }
        .sheet(item: $activeSession) { session in
            editorSheet(input: session.input)
        }
    }

    private func editorSheet(input: CanvasEditorInput) -> some View {
        // CanvasEditorView already ignores keyboard safe area, so the editor
        // keeps its layout stable while inline text editing is active.
        CanvasEditorView(
            input: input,
            configuration: store.configuration,
            onCancel: {
                activeSession = nil
            },
            onExport: { result, previewImage in
                store.save(result: result, previewImage: previewImage)
                activeSession = nil
            }
        )
    }
}

private struct ActiveEditorSession: Identifiable {
    let id = UUID()
    let input: CanvasEditorInput
}
