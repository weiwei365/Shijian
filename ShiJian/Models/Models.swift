import Foundation
import AppKit

// MARK: - Text Block

struct TextBlock: Identifiable, Codable {
    var id = UUID()
    var text: String
    var type: BlockType = .text
    var x: CGFloat
    var y: CGFloat
    var fontFamily: String
    var fontSize: CGFloat
    var colorHex: String
    var direction: TextDirection = .horizontal
    var align: TextAlignment = .center
    var italic: Bool = false
    var strokeColorHex: String = "#000000"
    var strokeWidth: CGFloat = 0
    var textBgColorHex: String = "#ffffff"
    var textBgOpacity: Int = 0
    var shadowColorHex: String = "#000000"
    var shadowBlur: CGFloat = 0
    var rotation: Double = 0  // 旋转角度（度）
    var fontId: String? = nil
    var maxWidth: CGFloat? = 400
    var sealBorderWidth: CGFloat? = 5.0

    // Seal-specific properties
    var sealShape: SealShape = .square
    var sealType: SealType = .zhuwen
    var sealSize: CGFloat = 60
    var sealDirty: Int = 0

    enum BlockType: String, Codable { case text, seal }
    enum TextDirection: String, Codable { case horizontal, vertical }
    enum TextAlignment: String, Codable { case left, center, right }
    enum SealShape: String, Codable { case square, circle, oval, roundedSquare }
    enum SealType: String, Codable { case zhuwen, baiwen }

    init(
        id: UUID = UUID(),
        text: String,
        type: BlockType = .text,
        x: CGFloat,
        y: CGFloat,
        fontFamily: String,
        fontSize: CGFloat,
        colorHex: String,
        direction: TextDirection = .horizontal,
        align: TextAlignment = .center,
        italic: Bool = false,
        strokeColorHex: String = "#000000",
        strokeWidth: CGFloat = 0,
        textBgColorHex: String = "#ffffff",
        textBgOpacity: Int = 0,
        shadowColorHex: String = "#000000",
        shadowBlur: CGFloat = 0,
        rotation: Double = 0,
        fontId: String? = nil,
        maxWidth: CGFloat? = 400,
        sealShape: SealShape = .square,
        sealType: SealType = .zhuwen,
        sealSize: CGFloat = 60,
        sealDirty: Int = 0,
        sealBorderWidth: CGFloat? = 5.0
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.x = x
        self.y = y
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.direction = direction
        self.align = align
        self.italic = italic
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.textBgColorHex = textBgColorHex
        self.textBgOpacity = textBgOpacity
        self.shadowColorHex = shadowColorHex
        self.shadowBlur = shadowBlur
        self.rotation = rotation
        self.fontId = fontId
        self.maxWidth = maxWidth
        self.sealShape = sealShape
        self.sealType = sealType
        self.sealSize = sealSize
        self.sealDirty = sealDirty
        self.sealBorderWidth = sealBorderWidth
    }
}

// MARK: - Background

enum BackgroundConfig: Codable {
    case none
    case solid(hex: String)
    case gradient(colors: [String], angle: Double)
    case image(filename: String, opacity: Double, blurRadius: Double)

    enum CodingKeys: String, CodingKey {
        case type, hex, colors, angle, filename, opacity, blurRadius
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "solid":
            let hex = try c.decode(String.self, forKey: .hex)
            self = .solid(hex: hex)
        case "gradient":
            let colors = try c.decode([String].self, forKey: .colors)
            let angle = try c.decode(Double.self, forKey: .angle)
            self = .gradient(colors: colors, angle: angle)
        case "image":
            let filename = try c.decode(String.self, forKey: .filename)
            let opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 100.0
            let blurRadius = try c.decodeIfPresent(Double.self, forKey: .blurRadius) ?? 0.0
            self = .image(filename: filename, opacity: opacity, blurRadius: blurRadius)
        default:
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode("none", forKey: .type)
        case .solid(let hex):
            try c.encode("solid", forKey: .type)
            try c.encode(hex, forKey: .hex)
        case .gradient(let colors, let angle):
            try c.encode("gradient", forKey: .type)
            try c.encode(colors, forKey: .colors)
            try c.encode(angle, forKey: .angle)
        case .image(let filename, let opacity, let blurRadius):
            try c.encode("image", forKey: .type)
            try c.encode(filename, forKey: .filename)
            try c.encode(opacity, forKey: .opacity)
            try c.encode(blurRadius, forKey: .blurRadius)
        }
    }
}

// MARK: - Canvas State

enum PaperTextureType: String, Codable {
    case none, xuan, goldSputtered
}

struct CanvasState: Codable {
    var width: CGFloat = 1600
    var height: CGFloat = 1200
    var ratio: String = "4:3"
    var background: BackgroundConfig = .none
    var blocks: [TextBlock] = []
    var activeBlockId: UUID?

    // 纸张纹理与界格属性
    var paperTextureType: PaperTextureType = .none
    var paperTextureIntensity: Double = 50.0
    var showGridLines: Bool = false
    var gridLineColorHex: String = "#b22222"
    var gridLineColumns: Int = 8
    var gridLineDirection: TextBlock.TextDirection = .vertical

    enum CodingKeys: String, CodingKey {
        case width, height, ratio, background, blocks, activeBlockId
        case paperTextureType, paperTextureIntensity, showGridLines, gridLineColorHex, gridLineColumns, gridLineDirection
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        ratio = try container.decode(String.self, forKey: .ratio)
        background = try container.decode(BackgroundConfig.self, forKey: .background)
        blocks = try container.decode([TextBlock].self, forKey: .blocks)
        activeBlockId = try container.decodeIfPresent(UUID.self, forKey: .activeBlockId)

        paperTextureType = try container.decodeIfPresent(PaperTextureType.self, forKey: .paperTextureType) ?? .none
        paperTextureIntensity = try container.decodeIfPresent(Double.self, forKey: .paperTextureIntensity) ?? 50.0
        showGridLines = try container.decodeIfPresent(Bool.self, forKey: .showGridLines) ?? false
        gridLineColorHex = try container.decodeIfPresent(String.self, forKey: .gridLineColorHex) ?? "#b22222"
        gridLineColumns = try container.decodeIfPresent(Int.self, forKey: .gridLineColumns) ?? 8
        gridLineDirection = try container.decodeIfPresent(TextBlock.TextDirection.self, forKey: .gridLineDirection) ?? .vertical
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(ratio, forKey: .ratio)
        try container.encode(background, forKey: .background)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(activeBlockId, forKey: .activeBlockId)

        try container.encode(paperTextureType, forKey: .paperTextureType)
        try container.encode(paperTextureIntensity, forKey: .paperTextureIntensity)
        try container.encode(showGridLines, forKey: .showGridLines)
        try container.encode(gridLineColorHex, forKey: .gridLineColorHex)
        try container.encode(gridLineColumns, forKey: .gridLineColumns)
        try container.encode(gridLineDirection, forKey: .gridLineDirection)
    }
}

// MARK: - Draft

struct Draft: Codable, Identifiable {
    var id = UUID()
    var name: String
    var savedAt: Date
    var canvasState: CanvasState
}

// MARK: - Template

struct ArtTemplate: Identifiable {
    var id: String
    var name: String
    var type: TemplateType
    var bgConfig: BackgroundConfig
    var defaultFontId: String
    var defaultFontSize: CGFloat
    var defaultColorHex: String
    var presetText: String?
    var presetDirection: String?

    enum TemplateType: String { case gradient, solid, preset }
}
