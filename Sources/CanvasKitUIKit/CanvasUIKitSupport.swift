#if canImport(UIKit)
import UIKit
import CanvasKitCore

extension CanvasColor {
    var uiColor: UIColor {
        UIColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )
            return
        }

        let fallback = CIColor(color: uiColor)
        self.init(
            red: fallback.red,
            green: fallback.green,
            blue: fallback.blue,
            alpha: fallback.alpha
        )
    }
}

extension CanvasShapeType {
    @MainActor
    var systemImageName: String {
        CanvasEditorUIRuntime.currentConfiguration.icons.systemImageName(for: self)
    }

    func systemImageName(in icons: CanvasEditorIconSet) -> String {
        icons.systemImageName(for: self)
    }
}

enum CanvasSymbolNodeLayout {
    private static let minimumPointSize: CGFloat = 18
    private static let defaultPointSize: CGFloat = 40
    private static let maximumSizeRatio: CGFloat = 0.72

    static func symbolPointSize(for node: CanvasNode) -> CGFloat {
        let preferredPointSize = CGFloat(node.style?.fontSize ?? Double(defaultPointSize))
        let maxPointSize = max(min(node.size.width, node.size.height) * maximumSizeRatio, minimumPointSize)
        return min(max(preferredPointSize, minimumPointSize), maxPointSize)
    }
}

enum CanvasAspectRatioLayout {
    static func aspectFitRect(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let fittedSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return CGRect(
            x: bounds.midX - (fittedSize.width / 2),
            y: bounds.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    static func aspectFillRect(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let filledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return CGRect(
            x: bounds.midX - (filledSize.width / 2),
            y: bounds.midY - (filledSize.height / 2),
            width: filledSize.width,
            height: filledSize.height
        )
    }
}

struct CanvasResolvedMaskedImageLayout {
    var center: CGPoint
    var size: CGSize
}

enum CanvasMaskedImageLayout {
    static func resolvedContentLayout(
        imageSize: CGSize,
        in bounds: CGRect,
        contentTransform: CanvasMaskedImageContentTransform
    ) -> CanvasResolvedMaskedImageLayout {
        let baseRect = CanvasAspectRatioLayout.aspectFillRect(for: imageSize, in: bounds)
        return CanvasResolvedMaskedImageLayout(
            center: CGPoint(
                x: baseRect.midX + contentTransform.offset.x,
                y: baseRect.midY + contentTransform.offset.y
            ),
            size: baseRect.size
        )
    }
}

enum CanvasShapePathBuilder {
    static func localPoints(for payload: CanvasShapePayload) -> [CGPoint] {
        payload.points.map(\.cgPoint)
    }

    static func makePath(type: CanvasShapeType, points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()

        switch type {
        case .brush:
            path.append(UIBezierPath(cgPath: CanvasEraserPathBuilder.makePath(points: points)))

        case .line:
            guard let first = points.first, let last = points.last else {
                return path
            }
            path.move(to: first)
            path.addLine(to: last)

        case .arrow:
            guard let first = points.first, let last = points.last else {
                return path
            }
            path.move(to: first)
            path.addLine(to: last)

            let deltaX = last.x - first.x
            let deltaY = last.y - first.y
            let length = max(hypot(deltaX, deltaY), 0.001)
            let baseAngle = atan2(deltaY, deltaX)
            let headLength = max(length * 0.16, 18)
            let arrowAngle = CGFloat.pi / 6
            let leftPoint = CGPoint(
                x: last.x - cos(baseAngle - arrowAngle) * headLength,
                y: last.y - sin(baseAngle - arrowAngle) * headLength
            )
            let rightPoint = CGPoint(
                x: last.x - cos(baseAngle + arrowAngle) * headLength,
                y: last.y - sin(baseAngle + arrowAngle) * headLength
            )

            path.move(to: last)
            path.addLine(to: leftPoint)
            path.move(to: last)
            path.addLine(to: rightPoint)

        case .oval:
            let rect = rect(for: points)
            if rect.isNull {
                return path
            }
            path.append(UIBezierPath(ovalIn: rect))

        case .rectangle:
            let rect = rect(for: points)
            if rect.isNull {
                return path
            }
            path.append(UIBezierPath(rect: rect))
        }

        return path
    }

    private static func rect(for points: [CGPoint]) -> CGRect {
        if points.count == 2, let first = points.first, let last = points.last {
            return CGRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: abs(last.x - first.x),
                height: abs(last.y - first.y)
            )
        }

        guard !points.isEmpty else {
            return .null
        }

        return points.reduce(into: CGRect.null) { partialResult, point in
            partialResult = partialResult.union(CGRect(origin: point, size: .zero))
        }
    }
}

extension CanvasShapePayload {
    func bezierPath() -> UIBezierPath {
        CanvasShapePathBuilder.makePath(
            type: type,
            points: CanvasShapePathBuilder.localPoints(for: self)
        )
    }
}

extension CanvasTextAlignment {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }
}

extension CanvasFontWeight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        }
    }
}

extension CanvasTextStyle {
    var resolvedNSTextAlignment: NSTextAlignment {
        isJustified ? .justified : alignment.nsTextAlignment
    }

    var resolvedBackgroundUIColor: UIColor? {
        guard let backgroundFill else {
            return nil
        }

        let color = backgroundFill.color
        return CanvasColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * opacity
        ).uiColor
    }

    func textAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = resolvedNSTextAlignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: makeFont(),
            .foregroundColor: foregroundColor.uiColor.withAlphaComponent(opacity),
            .paragraphStyle: paragraph,
            .kern: letterSpacing
        ]

        if let shadow {
            let nsShadow = NSShadow()
            nsShadow.shadowColor = shadow.color.uiColor
            nsShadow.shadowBlurRadius = shadow.radius
            nsShadow.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
            attributes[.shadow] = nsShadow
        }

        if let outline {
            attributes[.strokeColor] = outline.color.uiColor
            attributes[.strokeWidth] = -outline.width
        }

        return attributes
    }

    func makeFont() -> UIFont {
        let pointSize = CGFloat(fontSize)
        let familyFonts = UIFont.fontNames(forFamilyName: fontFamily)
        let font: UIFont

        if let matchedFontName = bestMatchingFontName(in: familyFonts) ?? UIFont(name: fontFamily, size: pointSize)?.fontName,
           let resolvedFont = UIFont(name: matchedFontName, size: pointSize) {
            font = resolvedFont
        } else {
            font = UIFont.systemFont(ofSize: pointSize, weight: weight.uiFontWeight)
        }

        guard isItalic else {
            return font
        }

        if let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return font
    }

    func attributedString(text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: textAttributes())
    }

    func requiredTextHeight(text: String, constrainedWidth: CGFloat) -> CGFloat {
        let measuredText = text.isEmpty ? " " : text
        let boundingRect = attributedString(text: measuredText).boundingRect(
            with: CGSize(width: max(constrainedWidth, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height)
    }

    private func bestMatchingFontName(in fontNames: [String]) -> String? {
        guard !fontNames.isEmpty else {
            return nil
        }

        let italicTokens = ["italic", "oblique"]
        let weightTokens: [String]
        switch weight {
        case .regular:
            weightTokens = ["regular", "book"]
        case .medium:
            weightTokens = ["medium"]
        case .semibold:
            weightTokens = ["semibold", "demi"]
        case .bold:
            weightTokens = ["bold"]
        case .heavy:
            weightTokens = ["heavy", "black"]
        }

        return fontNames.max { lhs, rhs in
            fontMatchScore(lhs, italicTokens: italicTokens, weightTokens: weightTokens) <
                fontMatchScore(rhs, italicTokens: italicTokens, weightTokens: weightTokens)
        }
    }

    private func fontMatchScore(_ fontName: String, italicTokens: [String], weightTokens: [String]) -> Int {
        let lowercased = fontName.lowercased()
        let weightScore = weightTokens.contains(where: lowercased.contains) ? 4 : 0
        let italicScore = isItalic == italicTokens.contains(where: lowercased.contains) ? 3 : 0
        let familyScore = lowercased.contains(fontFamily.lowercased().replacingOccurrences(of: " ", with: "")) ? 2 : 0
        return weightScore + italicScore + familyScore
    }
}

@MainActor
struct CanvasResolvedTextNodeLayout {
    var style: CanvasTextStyle
    var textRect: CGRect
}

@MainActor
enum CanvasTextNodeLayout {
    static func resolvedLayout(
        for node: CanvasNode,
        in bounds: CGRect,
        textInset: CGFloat = resolvedTextInset
    ) -> CanvasResolvedTextNodeLayout {
        let textRect = contentRect(in: bounds, textInset: textInset)
        let baseStyle = node.style ?? fallbackStyle(for: node.kind)
        let effectiveStyle = effectiveStyle(
            for: node,
            baseStyle: baseStyle,
            availableTextSize: textRect.size
        )

        return CanvasResolvedTextNodeLayout(
            style: effectiveStyle,
            textRect: textRect
        )
    }

    static func effectiveStyle(
        for node: CanvasNode,
        in bounds: CGRect = .zero,
        textInset: CGFloat = resolvedTextInset
    ) -> CanvasTextStyle {
        let baseStyle = node.style ?? fallbackStyle(for: node.kind)
        let availableTextSize: CGSize

        if bounds.isEmpty {
            availableTextSize = contentRect(
                in: CGRect(origin: .zero, size: node.size.cgSize),
                textInset: textInset
            ).size
        } else {
            availableTextSize = contentRect(in: bounds, textInset: textInset).size
        }

        return effectiveStyle(
            for: node,
            baseStyle: baseStyle,
            availableTextSize: availableTextSize
        )
    }

    static func contentRect(
        in bounds: CGRect,
        textInset: CGFloat = resolvedTextInset
    ) -> CGRect {
        let insetRect = bounds.insetBy(dx: textInset, dy: textInset)
        return CGRect(
            x: insetRect.origin.x,
            y: insetRect.origin.y,
            width: max(insetRect.width, 1),
            height: max(insetRect.height, 1)
        )
    }

    static func textFits(
        _ text: String,
        style: CanvasTextStyle,
        in availableTextSize: CGSize
    ) -> Bool {
        let constrainedSize = CGSize(
            width: max(availableTextSize.width, 1),
            height: max(availableTextSize.height, 1)
        )
        let measuredText = text.isEmpty ? " " : text
        let textStorage = NSTextStorage(
            attributedString: style.attributedString(text: measuredText)
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: constrainedSize)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.maximumNumberOfLines = 0

        layoutManager.usesFontLeading = true
        layoutManager.allowsNonContiguousLayout = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)

        return glyphRange.length == layoutManager.numberOfGlyphs &&
            usedRect.width <= constrainedSize.width + 0.5 &&
            usedRect.height <= constrainedSize.height + 0.5
    }

    private static var resolvedTextInset: CGFloat {
        CGFloat(CanvasEditorUIRuntime.currentConfiguration.layout.textContentInset)
    }

    private static func effectiveStyle(
        for node: CanvasNode,
        baseStyle: CanvasTextStyle,
        availableTextSize: CGSize
    ) -> CanvasTextStyle {
        guard node.isPermanentText else {
            return baseStyle
        }

        var resolvedStyle = baseStyle
        resolvedStyle.fontSize = effectiveFontSize(
            for: node.text ?? "",
            style: baseStyle,
            availableTextSize: availableTextSize
        )
        return resolvedStyle
    }

    private static func effectiveFontSize(
        for text: String,
        style: CanvasTextStyle,
        availableTextSize: CGSize
    ) -> Double {
        let minimumUnits = 2
        let maximumUnits = max(Int((max(style.fontSize, 1) * 2).rounded(.down)), minimumUnits)
        var lowerBound = minimumUnits
        var upperBound = maximumUnits
        var bestFitUnits = minimumUnits

        while lowerBound <= upperBound {
            let middleUnits = (lowerBound + upperBound) / 2
            let candidateFontSize = Double(middleUnits) / 2
            var candidateStyle = style
            candidateStyle.fontSize = candidateFontSize

            if textFits(text, style: candidateStyle, in: availableTextSize) {
                bestFitUnits = middleUnits
                lowerBound = middleUnits + 1
            } else {
                upperBound = middleUnits - 1
            }
        }

        return Double(bestFitUnits) / 2
    }

    private static func fallbackStyle(for kind: CanvasNodeKind) -> CanvasTextStyle {
        kind == .emoji ? .defaultEmoji : .defaultText
    }
}
#endif
