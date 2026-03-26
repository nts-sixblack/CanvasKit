#if canImport(UIKit)
import CoreText
import Foundation
import CanvasKitCore

@MainActor
enum CanvasEditorFontRegistrar {
    private static var registeredFontKeys = Set<String>()

    static func registerFonts(from configuration: CanvasEditorConfiguration) {
        let fontFiles = configuration.fonts.bundledFontFiles
        guard !fontFiles.isEmpty else {
            return
        }

        for fileName in fontFiles {
            let key = configuration.resources.fontBundles
                .map { $0.bundleIdentifier ?? $0.bundlePath }
                .joined(separator: "|") + "|\(fileName)"

            if registeredFontKeys.contains(key) {
                continue
            }

            guard let url = fontURL(
                named: fileName,
                bundles: configuration.resources.fontBundles
            ) else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            registeredFontKeys.insert(key)
        }
    }

    private static func fontURL(
        named fileName: String,
        bundles: [Bundle]
    ) -> URL? {
        let fileURL = URL(fileURLWithPath: fileName)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension

        for bundle in bundles {
            if let url = bundle.url(forResource: baseName, withExtension: fileExtension) {
                return url
            }
        }

        return nil
    }
}
#endif
