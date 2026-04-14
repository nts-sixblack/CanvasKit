import XCTest
@testable import CanvasKitCore

final class CanvasEmojiCatalogTests: XCTestCase {
    func testKeyboardCategoriesProvideDeduplicatedFullEmojiList() {
        let categories = CanvasEmojiCatalog.keyboardCategories()

        XCTAssertEqual(categories.count, 8)
        XCTAssertTrue(categories.allSatisfy { !$0.emojis.isEmpty })

        let allEmojis = categories.flatMap(\.emojis)

        XCTAssertGreaterThan(allEmojis.count, 1000)
        XCTAssertTrue(allEmojis.contains("😀"))
        XCTAssertTrue(allEmojis.contains("👍🏽"))
        XCTAssertTrue(allEmojis.contains("🇻🇳"))
        XCTAssertEqual(Set(allEmojis).count, allEmojis.count)
    }
}

