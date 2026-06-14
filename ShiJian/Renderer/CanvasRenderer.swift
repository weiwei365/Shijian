import Foundation
import AppKit
import CoreImage

/// 画布渲染器 —— 负责将 CanvasState 绘制 to CGContext
struct CanvasRenderer {

    static func draw(state: CanvasState, ctx: CGContext, width: CGFloat, height: CGFloat, selectedIds: Set<UUID> = [], isFlipped: Bool = true, fontManager: FontManager? = nil, transparent: Bool = false) {
        // 0. 辅助对齐十字线（无选中块时显示）
        if state.activeBlockId == nil && selectedIds.isEmpty {
            drawCenterGuides(ctx: ctx, width: width, height: height)
        }

        // 1. 背景
        if !transparent {
            drawBackground(config: state.background, ctx: ctx, width: width, height: height)
        } else {
            // 透明导出且背景为无或纯色时跳过背景绘制
            switch state.background {
            case .none, .solid:
                break
            default:
                drawBackground(config: state.background, ctx: ctx, width: width, height: height)
            }
        }

        // 1.5 绘制纸张纹理
        drawPaperTexture(type: state.paperTextureType, intensity: state.paperTextureIntensity, ctx: ctx, width: width, height: height)

        // 1.6 绘制界格线
        drawGridLines(state: state, ctx: ctx, width: width, height: height)

        // 1.7 禅意占位图案
        if state.blocks.isEmpty {
            drawZenPlaceholder(ctx: ctx, width: width, height: height, isFlipped: isFlipped)
        }

        // 2. 所有块
        for block in state.blocks {
            if block.type == .seal {
                drawSealBlock(block, ctx: ctx, fontManager: fontManager)
            } else {
                drawTextBlock(block, ctx: ctx, isFlipped: isFlipped, fontManager: fontManager)
            }
        }

        // 3. 选中边框（多选 + 单选）
        let idsToHighlight = selectedIds.isEmpty
            ? (state.activeBlockId.map { [$0] } ?? []).compactMap { $0 }
            : Array(selectedIds)
        for id in idsToHighlight {
            if let block = state.blocks.first(where: { $0.id == id }) {
                drawActiveBorder(block, ctx: ctx, fontManager: fontManager)
            }
        }
    }

    // MARK: - Background

    static func drawBackground(config: BackgroundConfig, ctx: CGContext, width: CGFloat, height: CGFloat) {
        switch config {
        case .none:
            ctx.setFillColor(CGColor.white)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        case .solid(let hex):
            ctx.setFillColor(parseColor(hex))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        case .gradient(let colors, let angleDeg):
            renderGradient(colors: colors, angleDeg: angleDeg, ctx: ctx, width: width, height: height)

        case .image(let filename, let opacity, let blurRadius):
            // 尝试从 app support 或 bundle 加载背景图
            if let nsImage = loadBackgroundImage(filename: filename) {
                let processedImage = applyBlurAndOpacity(nsImage, blurRadius: blurRadius, opacity: opacity)
                if let processed = processedImage,
                   let cgImage = processed.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    // cover 模式填充
                    let imgW = CGFloat(cgImage.width), imgH = CGFloat(cgImage.height)
                    let scale = max(width / imgW, height / imgH)
                    let w = imgW * scale, h = imgH * scale
                    let x = (width - w) / 2, y = (height - h) / 2
                    ctx.draw(cgImage, in: CGRect(x: x, y: y, width: w, height: h))
                }
            } else {
                ctx.setFillColor(CGColor.white)
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
    }

    private static func applyBlurAndOpacity(_ image: NSImage, blurRadius: Double, opacity: Double) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return image }
        
        var outputImage = ciImage
        
        // 应用模糊
        if blurRadius > 0 {
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(blurRadius, forKey: kCIInputRadiusKey)
            if let blurred = filter?.outputImage {
                outputImage = blurred.cropped(to: ciImage.extent)
            }
        }
        
        // 应用透明度
        if opacity < 100 {
            let alphaFilter = CIFilter(name: "CIColorMatrix")
            alphaFilter?.setValue(outputImage, forKey: kCIInputImageKey)
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: opacity / 100.0)
            alphaFilter?.setValue(alphaVector, forKey: "inputAVector")
            if let alphaOutput = alphaFilter?.outputImage {
                outputImage = alphaOutput
            }
        }
        
        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: image.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    private static func renderGradient(colors: [String], angleDeg: Double, ctx: CGContext, width: CGFloat, height: CGFloat) {
        let cgColors = colors.map { parseColor($0) }
        guard !cgColors.isEmpty else { return }

        let angle = (angleDeg - 90) * .pi / 180
        let cx = width / 2, cy = height / 2
        let len = sqrt(width * width + height * height) / 2

        let x1 = cx - cos(angle) * len, y1 = cy - sin(angle) * len
        let x2 = cx + cos(angle) * len, y2 = cy + sin(angle) * len

        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: cgColors as CFArray,
                                         locations: nil) else { return }

        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: x1, y: y1),
                               end: CGPoint(x: x2, y: y2),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    // MARK: - Text Block

    static func drawTextBlock(_ block: TextBlock, ctx: CGContext, isFlipped: Bool = true, fontManager: FontManager? = nil) {
        ctx.saveGState()

        let color = parseColor(block.colorHex)
        let familyName: String
        if let fm = fontManager, let fId = block.fontId {
            familyName = fm.getFontFamily(fId)
        } else {
            familyName = block.fontFamily
        }
        let font = getFont(family: familyName, size: block.fontSize, italic: block.italic)
        let strokeColor = parseColor(block.strokeColorHex)
        let lines = block.text.components(separatedBy: "\n")

        // 旋转（以 block 中心为轴）
        if block.rotation != 0 {
            ctx.saveGState()
            ctx.translateBy(x: block.x, y: block.y)
            ctx.rotate(by: block.rotation * .pi / 180)
            ctx.translateBy(x: -block.x, y: -block.y)
        }

        // 文字阴影
        if block.shadowBlur > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 1, height: 1), blur: block.shadowBlur, color: parseColor(block.shadowColorHex))
            drawTextContent(block: block, lines: lines, font: font, color: color, strokeColor: strokeColor, strokeWidth: block.strokeWidth, ctx: ctx, isFlipped: isFlipped)
            ctx.restoreGState()
        }

        drawTextContent(block: block, lines: lines, font: font, color: color, strokeColor: strokeColor, strokeWidth: block.strokeWidth, ctx: ctx, isFlipped: isFlipped)

        if block.rotation != 0 {
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }

    private static func drawTextContent(block: TextBlock, lines: [String], font: NSFont, color: CGColor, strokeColor: CGColor, strokeWidth: CGFloat, ctx: CGContext, isFlipped: Bool = true) {
        if block.direction == .vertical {
            drawVerticalText(block: block, lines: lines, font: font, color: color,
                             strokeColor: strokeColor, strokeWidth: block.strokeWidth,
                             ctx: ctx, isFlipped: isFlipped)
        } else {
            drawHorizontalText(block: block, lines: lines, font: font, color: color,
                               strokeColor: strokeColor, strokeWidth: block.strokeWidth,
                               ctx: ctx, isFlipped: isFlipped)
        }
    }

    private static func drawHorizontalText(block: TextBlock, lines: [String], font: NSFont, color: CGColor, strokeColor: CGColor, strokeWidth: CGFloat, ctx: CGContext, isFlipped: Bool = true) {
        let lineHeight = block.fontSize * 1.8
        let attrs = makeAttrs(font: font, color: color)

        // 自动换行：使用自定义最大宽度或默认值 400
        let maxLineWidth = block.maxWidth ?? 400
        var wrappedLines: [String] = []
        for line in lines {
            let w = measureText(line, attrs: attrs).width
            if w > maxLineWidth {
                // 逐字度量，找到换行位置
                var currentLine = ""
                var currentWidth: CGFloat = 0
                for ch in line {
                    let chStr = String(ch)
                    let chW = measureText(chStr, attrs: attrs).width
                    if currentWidth + chW > maxLineWidth && !currentLine.isEmpty {
                        wrappedLines.append(currentLine)
                        currentLine = chStr
                        currentWidth = chW
                    } else {
                        currentLine += chStr
                        currentWidth += chW
                    }
                }
                if !currentLine.isEmpty { wrappedLines.append(currentLine) }
            } else {
                wrappedLines.append(line)
            }
        }
        let finalLines = wrappedLines

        // y↓ flipped: first line at top (smallest y) → startY = center - offset
        // y↑ unflipped: first line at top (largest y) → startY = center + offset
        let startY = isFlipped
            ? block.y - CGFloat(finalLines.count - 1) * lineHeight / 2
            : block.y + CGFloat(finalLines.count - 1) * lineHeight / 2

        let maxWidth = finalLines.map { measureText($0, attrs: attrs).width }.max() ?? 0
        let totalHeight = CGFloat(finalLines.count) * lineHeight

        // 文字背景
        if block.textBgOpacity > 0 {
            let bgX: CGFloat
            switch block.align {
            case .left:  bgX = block.x
            case .right: bgX = block.x - maxWidth
            case .center: bgX = block.x - maxWidth / 2
            }
            let bgY = isFlipped ? startY : startY - totalHeight
            ctx.saveGState()
            ctx.setAlpha(CGFloat(block.textBgOpacity) / 100)
            ctx.setFillColor(parseColor(block.textBgColorHex))
            let padding = block.fontSize * 0.3
            ctx.fill(CGRect(x: bgX - padding, y: bgY - padding, width: maxWidth + padding * 2, height: totalHeight + padding * 2))
            ctx.restoreGState()
        }

        for (i, line) in finalLines.enumerated() {
            let x: CGFloat
            switch block.align {
            case .left:  x = block.x
            case .right: x = block.x - measureText(line, attrs: attrs).width
            case .center: x = block.x - measureText(line, attrs: attrs).width / 2
            }
            // y↓: lines go down (y + i*spacing); y↑: lines go up (y - i*spacing)
            let y = isFlipped
                ? startY + CGFloat(i) * lineHeight
                : startY - CGFloat(i) * lineHeight

            if strokeWidth > 0 {
                drawStrokedText(line, at: CGPoint(x: x, y: y), font: font, strokeColor: strokeColor, fillColor: color, strokeWidth: strokeWidth)
            } else {
                drawString(line, at: CGPoint(x: x, y: y), attrs: attrs)
            }
        }
    }

    private static func drawVerticalText(block: TextBlock, lines: [String], font: NSFont, color: CGColor, strokeColor: CGColor, strokeWidth: CGFloat, ctx: CGContext, isFlipped: Bool = true) {
        let charSpacing = block.fontSize * 1.5
        let colSpacing = block.fontSize * 1.8
        let maxLen = lines.map { $0.count }.max() ?? 0
        let colCount = lines.count

        let totalWidth = CGFloat(colCount - 1) * colSpacing
        let totalHeight = CGFloat(maxLen - 1) * charSpacing

        // 文字背景
        if block.textBgOpacity > 0 {
            let bgW = totalWidth + block.fontSize
            let bgH = totalHeight + block.fontSize
            let bgX = block.x - totalWidth / 2
            let bgY = block.y - totalHeight / 2
            let pad = block.fontSize * 0.3
            ctx.saveGState()
            ctx.setAlpha(CGFloat(block.textBgOpacity) / 100)
            ctx.setFillColor(parseColor(block.textBgColorHex))
            ctx.fill(CGRect(x: bgX - pad, y: bgY - pad, width: bgW + pad * 2, height: bgH + pad * 2))
            ctx.restoreGState()
        }

        for (colIdx, line) in lines.enumerated() {
            let x = block.x + totalWidth / 2 - CGFloat(colIdx) * colSpacing
            let chars = Array(line)
            for (rowIdx, char) in chars.enumerated() {
                // y↓ flipped: first char at top (smallest y); y↑ unflipped: first char at top (largest y)
                let y = isFlipped
                    ? block.y - totalHeight / 2 + CGFloat(rowIdx) * charSpacing
                    : block.y + totalHeight / 2 - CGFloat(rowIdx) * charSpacing
                let str = String(char)

                if strokeWidth > 0 {
                    drawStrokedText(str, at: CGPoint(x: x, y: y), font: font, strokeColor: strokeColor, fillColor: color, strokeWidth: strokeWidth)
                } else {
                    let attrs = makeAttrs(font: font, color: color)
                    drawString(str, at: CGPoint(x: x, y: y), attrs: attrs)
                }
            }
        }
    }

    // MARK: - Seal Block

    static func drawSealBlock(_ block: TextBlock, ctx: CGContext, fontManager: FontManager? = nil) {
        guard let image = SealRenderer.render(block: block, fontManager: fontManager) else { return }
        let s = CGFloat(block.sealSize)
        // flipped canvas 中 CGImage 会上下颠倒，需要翻转
        ctx.saveGState()
        ctx.translateBy(x: block.x - s/2, y: block.y + s/2)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: s, height: s))
        ctx.restoreGState()
    }

    // MARK: - Active Border

    static func drawActiveBorder(_ block: TextBlock, ctx: CGContext, fontManager: FontManager? = nil) {
        let rect = blockRect(block, fontManager: fontManager)
        let pad: CGFloat = 4

        ctx.saveGState()
        ctx.setStrokeColor(parseColor("#c8a46e"))
        ctx.setLineWidth(1.2)
        ctx.setLineDash(phase: 0, lengths: [4, 4])

        ctx.stroke(CGRect(x: rect.origin.x - pad, y: rect.origin.y - pad,
                          width: rect.width + pad * 2, height: rect.height + pad * 2))

        // 四角装饰方块
        ctx.setFillColor(parseColor("#c8a46e"))
        let d: CGFloat = 6
        let corners: [(CGFloat, CGFloat)] = [
            (rect.origin.x - pad, rect.origin.y - pad),
            (rect.origin.x + rect.width + pad, rect.origin.y - pad),
            (rect.origin.x - pad, rect.origin.y + rect.height + pad),
            (rect.origin.x + rect.width + pad, rect.origin.y + rect.height + pad)
        ]
        for (cx, cy) in corners {
            ctx.fill(CGRect(x: cx - d/2, y: cy - d/2, width: d, height: d))
        }

        ctx.restoreGState()
    }

    // MARK: - Hit Testing

    static func blockRect(_ block: TextBlock, fontManager: FontManager? = nil) -> CGRect {
        if block.type == .seal {
            let s = CGFloat(block.sealSize)
            return CGRect(x: block.x - s/2, y: block.y - s/2, width: s, height: s)
        }

        let lines = block.text.components(separatedBy: "\n")
        let familyName: String
        if let fm = fontManager, let fId = block.fontId {
            familyName = fm.getFontFamily(fId)
        } else {
            familyName = block.fontFamily
        }
        let font = getFont(family: familyName, size: block.fontSize, italic: block.italic)
        let attrs = makeAttrs(font: font, color: parseColor(block.colorHex))

        if block.direction == .vertical {
            let charSpacing = block.fontSize * 1.5
            let colSpacing = block.fontSize * 1.8
            let maxLen = lines.map { $0.count }.max() ?? 0
            let colCount = lines.count
            let totalWidth = CGFloat(colCount - 1) * colSpacing
            let totalHeight = CGFloat(maxLen - 1) * charSpacing
            // 竖排文字：字符从 (x, y) 开始绘制，向右/向下延伸约 fontSize
            // 包围盒左上角 = 文字最左上角，宽 = 列跨度 + 单字宽，高 = 行跨度 + 单字高
            let w = totalWidth + block.fontSize
            let h = totalHeight + block.fontSize
            return CGRect(x: block.x - totalWidth/2, y: block.y - totalHeight/2, width: w, height: h)
        } else {
            let lineHeight = block.fontSize * 1.8
            
            // 自动换行：使用自定义最大宽度或默认值 400
            let maxLineWidth = block.maxWidth ?? 400
            var wrappedLines: [String] = []
            for line in lines {
                let w = measureText(line, attrs: attrs).width
                if w > maxLineWidth {
                    // 逐字度量，找到换行位置
                    var currentLine = ""
                    var currentWidth: CGFloat = 0
                    for ch in line {
                        let chStr = String(ch)
                        let chW = measureText(chStr, attrs: attrs).width
                        if currentWidth + chW > maxLineWidth && !currentLine.isEmpty {
                            wrappedLines.append(currentLine)
                            currentLine = chStr
                            currentWidth = chW
                        } else {
                            currentLine += chStr
                            currentWidth += chW
                        }
                    }
                    if !currentLine.isEmpty { wrappedLines.append(currentLine) }
                } else {
                    wrappedLines.append(line)
                }
            }
            let finalLines = wrappedLines
            
            let maxWidth = finalLines.map { measureText($0, attrs: attrs).width }.max() ?? 0
            let h = CGFloat(finalLines.count) * lineHeight
            let x: CGFloat
            switch block.align {
            case .left:  x = block.x
            case .right: x = block.x - maxWidth
            case .center: x = block.x - maxWidth / 2
            }
            return CGRect(x: x, y: block.y - h/2, width: maxWidth, height: h)
        }
    }

    static func hitBlock(at point: CGPoint, blocks: [TextBlock], fontManager: FontManager? = nil) -> TextBlock? {
        let pad: CGFloat = 12
        for block in blocks.reversed() {
            let r = blockRect(block, fontManager: fontManager).insetBy(dx: -pad, dy: -pad)
            if r.contains(point) { return block }
        }
        return nil
    }

    // MARK: - Helpers

    static func parseColor(_ hex: String) -> CGColor {
        let hexStr = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        return CGColor(red: CGFloat((rgb >> 16) & 0xFF)/255.0,
                       green: CGFloat((rgb >> 8) & 0xFF)/255.0,
                       blue: CGFloat(rgb & 0xFF)/255.0,
                       alpha: 1.0)
    }

    static func getFont(family: String, size: CGFloat, italic: Bool = false) -> NSFont {
        let fm = NSFontManager.shared
        if let font = NSFont(name: family, size: size) {
            return italic ? fm.convert(font, toHaveTrait: .italicFontMask) : font
        }
        let fallback = NSFont(name: "PingFang SC", size: size) ?? NSFont.systemFont(ofSize: size)
        return italic ? fm.convert(fallback, toHaveTrait: .italicFontMask) : fallback
    }

    static func makeAttrs(font: NSFont, color: CGColor) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor(cgColor: color)!
        ]
    }

    static func measureText(_ text: String, attrs: [NSAttributedString.Key: Any]) -> CGSize {
        return NSString(string: text).size(withAttributes: attrs)
    }

    static func drawString(_ text: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any]) {
        NSString(string: text).draw(at: point, withAttributes: attrs)
    }

    static func drawStrokedText(_ text: String, at point: CGPoint, font: NSFont, strokeColor: CGColor, fillColor: CGColor, strokeWidth: CGFloat) {
        let textColor = NSColor(cgColor: fillColor)!
        let strColor = NSColor(cgColor: strokeColor)!

        // 先画描边
        let strokeAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: strColor,
            .strokeWidth: -strokeWidth,
            .strokeColor: strColor
        ]
        NSString(string: text).draw(at: point, withAttributes: strokeAttrs)

        // 再画填充
        let fillAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        NSString(string: text).draw(at: point, withAttributes: fillAttrs)
    }

    private static func loadBackgroundImage(filename: String) -> NSImage? {
        // 先在 App Support 目录查找
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShiJian/Images")
        let supportURL = supportDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: supportURL.path) {
            return NSImage(contentsOf: supportURL)
        }
        // 再在 Bundle 中查找
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: nil) {
            return NSImage(contentsOf: bundleURL)
        }
        return nil
    }

    // MARK: - Center Alignment Guides

    private static func drawCenterGuides(ctx: CGContext, width: CGFloat, height: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.12))
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])

        let cx = width / 2
        let cy = height / 2

        // 水平中心线
        ctx.move(to: CGPoint(x: 0, y: cy))
        ctx.addLine(to: CGPoint(x: width, y: cy))

        // 垂直中心线
        ctx.move(to: CGPoint(x: cx, y: 0))
        ctx.addLine(to: CGPoint(x: cx, y: height))

        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Pseudo-random Number Generator for Deterministic Rendering

    private struct SimpleSeedRandom {
        var seed: UInt64
        init(seed: UInt64) {
            self.seed = seed
        }
        mutating func nextDouble() -> Double {
            seed = seed.multipliedReportingOverflow(by: 2862933555777941757).partialValue.addingReportingOverflow(3037000493).partialValue
            return Double(seed) / Double(UInt64.max)
        }
        mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
            return range.lowerBound + CGFloat(nextDouble()) * (range.upperBound - range.lowerBound)
        }
    }

    // MARK: - Paper Texture, Grid, and Zen Placeholder Rendering

    private static func drawPaperTexture(type: PaperTextureType, intensity: Double, ctx: CGContext, width: CGFloat, height: CGFloat) {
        guard type != .none, intensity > 0 else { return }
        ctx.saveGState()
        
        var rng = SimpleSeedRandom(seed: 20260614) // Fixed seed for deterministic layout
        
        if type == .xuan {
            // Draw xuan paper fibers
            let baseArea = 1600.0 * 1200.0
            let currentArea = Double(width * height)
            let fiberCount = Int(2500 * (currentArea / baseArea))
            
            for _ in 0..<fiberCount {
                let x = rng.nextCGFloat(in: 0...width)
                let y = rng.nextCGFloat(in: 0...height)
                let len = rng.nextCGFloat(in: 15...60)
                let angle = rng.nextCGFloat(in: 0...(2 * .pi))
                let controlOffset = rng.nextCGFloat(in: -10...10)
                
                let x2 = x + cos(angle) * len
                let y2 = y + sin(angle) * len
                
                let cx = (x + x2) / 2 + sin(angle + .pi/2) * controlOffset
                let cy = (y + y2) / 2 - cos(angle + .pi/2) * controlOffset
                
                let isDark = rng.nextDouble() > 0.4
                let alpha = CGFloat(intensity / 100.0) * (isDark ? rng.nextCGFloat(in: 0.03...0.07) : rng.nextCGFloat(in: 0.05...0.12))
                
                ctx.beginPath()
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addQuadCurve(to: CGPoint(x: x2, y: y2), control: CGPoint(x: cx, y: cy))
                
                ctx.setLineWidth(rng.nextCGFloat(in: 0.3...1.0))
                if isDark {
                    ctx.setStrokeColor(CGColor(red: 0.4, green: 0.35, blue: 0.3, alpha: alpha))
                } else {
                    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alpha))
                }
                ctx.strokePath()
            }
        } else if type == .goldSputtered {
            // Draw gold sputtered spots
            let baseArea = 1600.0 * 1200.0
            let currentArea = Double(width * height)
            let goldCount = Int(250 * (currentArea / baseArea))
            
            for _ in 0..<goldCount {
                let cx = rng.nextCGFloat(in: 0...width)
                let cy = rng.nextCGFloat(in: 0...height)
                
                let size = rng.nextCGFloat(in: 3...15)
                let pointsCount = Int(rng.nextCGFloat(in: 3...6))
                
                let alpha = CGFloat(intensity / 100.0) * rng.nextCGFloat(in: 0.3...0.75)
                
                let goldR = rng.nextCGFloat(in: 0.82...0.94)
                let goldG = rng.nextCGFloat(in: 0.64...0.78)
                let goldB = rng.nextCGFloat(in: 0.22...0.35)
                ctx.setFillColor(CGColor(red: goldR, green: goldG, blue: goldB, alpha: alpha))
                
                ctx.beginPath()
                for i in 0..<pointsCount {
                    let angle = (2 * .pi / CGFloat(pointsCount)) * CGFloat(i) + rng.nextCGFloat(in: -0.3...0.3)
                    let r = size * rng.nextCGFloat(in: 0.6...1.2)
                    let px = cx + cos(angle) * r
                    let py = cy + sin(angle) * r
                    
                    if i == 0 {
                        ctx.move(to: CGPoint(x: px, y: py))
                    } else {
                        ctx.addLine(to: CGPoint(x: px, y: py))
                    }
                }
                ctx.closePath()
                ctx.fillPath()
            }
        }
        
        ctx.restoreGState()
    }

    private static func drawGridLines(state: CanvasState, ctx: CGContext, width: CGFloat, height: CGFloat) {
        guard state.showGridLines else { return }
        ctx.saveGState()
        
        let color = parseColor(state.gridLineColorHex)
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        
        let marginX = width * 0.08
        let marginY = height * 0.08
        let gridRect = CGRect(x: marginX, y: marginY, width: width - marginX * 2, height: height - marginY * 2)
        
        // Outer frame (thick outer, thin inner)
        ctx.setLineWidth(3.0)
        ctx.stroke(gridRect)
        
        let innerGap: CGFloat = 6.0
        let innerRect = gridRect.insetBy(dx: innerGap, dy: innerGap)
        ctx.setLineWidth(1.0)
        ctx.stroke(innerRect)
        
        // Internal division grid lines
        let cols = state.gridLineColumns
        if cols > 1 {
            ctx.setLineWidth(1.0)
            if state.gridLineDirection == .vertical {
                let cellW = innerRect.width / CGFloat(cols)
                for i in 1..<cols {
                    let lx = innerRect.minX + CGFloat(i) * cellW
                    ctx.beginPath()
                    ctx.move(to: CGPoint(x: lx, y: innerRect.minY))
                    ctx.addLine(to: CGPoint(x: lx, y: innerRect.maxY))
                    ctx.strokePath()
                }
            } else {
                let cellH = innerRect.height / CGFloat(cols)
                for i in 1..<cols {
                    let ly = innerRect.minY + CGFloat(i) * cellH
                    ctx.beginPath()
                    ctx.move(to: CGPoint(x: innerRect.minX, y: ly))
                    ctx.addLine(to: CGPoint(x: innerRect.maxX, y: ly))
                    ctx.strokePath()
                }
            }
        }
        
        ctx.restoreGState()
    }

    private static func drawZenPlaceholder(ctx: CGContext, width: CGFloat, height: CGFloat, isFlipped: Bool) {
        ctx.saveGState()
        
        let cx = width / 2
        let cy = height / 2
        
        // 1. Center 8-column red box
        let boxW: CGFloat = 360
        let boxH: CGFloat = 360
        let boxRect = CGRect(x: cx - boxW/2, y: cy - boxH/2, width: boxW, height: boxH)
        
        ctx.setStrokeColor(CGColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.15))
        ctx.setLineWidth(1.0)
        ctx.stroke(boxRect)
        
        let cols = 8
        let cellW = boxW / CGFloat(cols)
        for i in 1..<cols {
            let lx = boxRect.minX + CGFloat(i) * cellW
            ctx.beginPath()
            ctx.move(to: CGPoint(x: lx, y: boxRect.minY))
            ctx.addLine(to: CGPoint(x: lx, y: boxRect.maxY))
            ctx.strokePath()
        }
        
        // 2. Write Large Zen character "笺"
        let largeFont = NSFont(name: "Kaiti SC", size: 220) ?? NSFont(name: "PingFang SC", size: 220) ?? NSFont.systemFont(ofSize: 220)
        let largeAttrs: [NSAttributedString.Key: Any] = [
            .font: largeFont,
            .foregroundColor: NSColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 0.08)
        ]
        let word = "笺"
        let wordSize = measureText(word, attrs: largeAttrs)
        let wordX = cx - wordSize.width / 2
        let wordY = cy - wordSize.height / 2
        drawString(word, at: CGPoint(x: wordX, y: wordY), attrs: largeAttrs)
        
        // 3. Hint text below
        let tipFont = NSFont(name: "PingFang SC", size: 16) ?? NSFont.systemFont(ofSize: 16)
        let tipAttrs: [NSAttributedString.Key: Any] = [
            .font: tipFont,
            .foregroundColor: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.35)
        ]
        let tipStr = "落墨成诗，抚笺成画。点击左侧添加文本或印章以起笔。"
        let tipSize = measureText(tipStr, attrs: tipAttrs)
        let tipX = cx - tipSize.width / 2
        
        let tipY: CGFloat
        if isFlipped {
            tipY = cy + boxH / 2 + 20
        } else {
            tipY = cy - boxH / 2 - 20 - tipSize.height
        }
        drawString(tipStr, at: CGPoint(x: tipX, y: tipY), attrs: tipAttrs)
        
        ctx.restoreGState()
    }
}
