//
//  ContentView.swift
//  CanvasKit
//
//  Created by Sau Nguyen on 26/3/26.
//

import CanvasKitCore
import CanvasKitSwiftUI
import SwiftUI

struct ContentView: View {
    @StateObject private var store = CanvasKitExampleStore(
        configuration: CanvasKitExampleConfiguration.makeEditorConfiguration()
    )
    @State private var navigationPath: [ActiveEditorSession] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section("Templates") {
                    ForEach(store.templates) { template in
                        Button(template.name) {
                            navigationPath.append(ActiveEditorSession(input: .template(template)))
                        }
                    }
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
                            navigationPath.append(ActiveEditorSession(input: .project(project)))
                        }
                        .disabled(savedDocument.project == nil)
                    }
                }
            }
            .navigationTitle("CanvasKit Example")
            .navigationDestination(for: ActiveEditorSession.self) { session in
                CanvasEditorExampleScreen(
                    input: session.input,
                    store: store
                )
            }
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

private struct ActiveEditorSession: Hashable, Identifiable {
    let id = UUID()
    let input: CanvasEditorInput

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
