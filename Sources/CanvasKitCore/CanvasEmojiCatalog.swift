import Foundation

public struct CanvasEmojiKeyboardCategory: Hashable, Sendable {
    public let id: String
    public let title: String
    public let emojis: [String]

    public init(
        id: String,
        title: String,
        emojis: [String]
    ) {
        self.id = id
        self.title = title
        self.emojis = emojis
    }
}

public enum CanvasEmojiCatalog {
    public static func keyboardCategories() -> [CanvasEmojiKeyboardCategory] {
        cachedKeyboardCategories
    }

    private struct CategoryDefinition: Sendable {
        let id: String
        let title: String
        let unicodeGroups: [String]
    }

    private static let cachedKeyboardCategories: [CanvasEmojiKeyboardCategory] = {
        guard let emojiTestText = loadEmojiTestText() else {
            return []
        }

        let definitions: [CategoryDefinition] = [
            .init(
                id: "smileys_people",
                title: "Smileys & People",
                unicodeGroups: ["Smileys & Emotion", "People & Body"]
            ),
            .init(
                id: "animals_nature",
                title: "Animals & Nature",
                unicodeGroups: ["Animals & Nature"]
            ),
            .init(
                id: "food_drink",
                title: "Food & Drink",
                unicodeGroups: ["Food & Drink"]
            ),
            .init(
                id: "activities",
                title: "Activities",
                unicodeGroups: ["Activities"]
            ),
            .init(
                id: "travel_places",
                title: "Travel & Places",
                unicodeGroups: ["Travel & Places"]
            ),
            .init(
                id: "objects",
                title: "Objects",
                unicodeGroups: ["Objects"]
            ),
            .init(
                id: "symbols",
                title: "Symbols",
                unicodeGroups: ["Symbols"]
            ),
            .init(
                id: "flags",
                title: "Flags",
                unicodeGroups: ["Flags"]
            )
        ]

        var unicodeGroupToCategoryID: [String: String] = [:]
        for definition in definitions {
            for unicodeGroup in definition.unicodeGroups {
                unicodeGroupToCategoryID[unicodeGroup] = definition.id
            }
        }

        var emojisByCategoryID: [String: [String]] = Dictionary(
            uniqueKeysWithValues: definitions.map { ($0.id, []) }
        )
        var globalEmojiSet = Set<String>()
        var currentUnicodeGroup: String?

        for rawLine in emojiTestText.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("# group:") {
                currentUnicodeGroup = String(line.dropFirst("# group:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let currentUnicodeGroup else {
                continue
            }
            guard currentUnicodeGroup != "Component" else {
                continue
            }

            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            guard let categoryID = unicodeGroupToCategoryID[currentUnicodeGroup] else {
                continue
            }

            guard let emoji = parseFullyQualifiedEmoji(from: line) else {
                continue
            }

            guard globalEmojiSet.insert(emoji).inserted else {
                continue
            }

            emojisByCategoryID[categoryID, default: []].append(emoji)
        }

        return definitions.map { definition in
            CanvasEmojiKeyboardCategory(
                id: definition.id,
                title: definition.title,
                emojis: emojisByCategoryID[definition.id] ?? []
            )
        }
    }()

    private static func loadEmojiTestText() -> String? {
        let directURL = Bundle.module.url(
            forResource: "emoji-test",
            withExtension: "txt",
            subdirectory: "Emoji"
        )
        let rootURL = Bundle.module.url(forResource: "emoji-test", withExtension: "txt")

        guard let url = directURL ?? rootURL else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func parseFullyQualifiedEmoji(from line: String) -> String? {
        guard let semicolonIndex = line.firstIndex(of: ";") else {
            return nil
        }

        let statusPart = line[line.index(after: semicolonIndex)...]
            .trimmingCharacters(in: .whitespaces)
        guard statusPart.hasPrefix("fully-qualified") else {
            return nil
        }

        let components = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2 else {
            return nil
        }

        let comment = components[1].trimmingCharacters(in: .whitespaces)
        guard let emojiCharacter = comment.first else {
            return nil
        }

        return String(emojiCharacter)
    }
}

