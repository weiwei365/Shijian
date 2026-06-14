import Foundation
import AppKit

/// 印章渲染器 —— 在离屏位图上绘制朱文/白文印章
struct SealRenderer {

    /// 生成印章 CGImage
    static func render(block: TextBlock, fontManager: FontManager? = nil) -> CGImage? {
        let size = Int(block.sealSize)
        guard size > 0 else { return nil }

        let redColor = CGColor(red: 0.698, green: 0.133, blue: 0.133, alpha: 1.0) // #b22222
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: size * 4, bitsPerPixel: 32
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))

        let s = CGFloat(size)
        let defaultLineW = max(2, s * 0.05)
        let borderFactor = CGFloat(block.sealBorderWidth ?? 5.0) / 5.0
        let lineW = defaultLineW * borderFactor

        if block.sealType == .zhuwen {
            // 阳刻（朱文）：透明底、红色边框和文字
            ctx.setStrokeColor(redColor)
            ctx.setFillColor(redColor)
            ctx.setLineWidth(lineW)

            if block.sealShape == .circle {
                let r = s / 2 - lineW / 2
                ctx.addArc(center: CGPoint(x: s/2, y: s/2), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            } else if block.sealShape == .oval {
                let rx = s / 2 - lineW / 2
                let ry = s / 2 * 0.7 - lineW / 2
                ctx.addEllipse(in: CGRect(x: s/2 - rx, y: s/2 - ry, width: rx * 2, height: ry * 2))
            } else if block.sealShape == .roundedSquare {
                let r = s * 0.15
                let path = CGPath(roundedRect: CGRect(x: lineW/2, y: lineW/2, width: s - lineW, height: s - lineW), cornerWidth: r, cornerHeight: r, transform: nil)
                ctx.addPath(path)
            } else {
                ctx.addRect(CGRect(x: lineW/2, y: lineW/2, width: s - lineW, height: s - lineW))
            }
            ctx.strokePath()

            drawSealText(ctx: ctx, text: block.text, cx: s/2, cy: s/2, size: s, color: redColor, fontFamily: block.fontFamily, fontId: block.fontId, fontManager: fontManager)
        } else {
            // 阴刻（白文）：红色底、透明白字
            ctx.setFillColor(redColor)
            if block.sealShape == .circle {
                ctx.addArc(center: CGPoint(x: s/2, y: s/2), radius: s/2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            } else if block.sealShape == .oval {
                ctx.addEllipse(in: CGRect(x: 0, y: s/2 - s/2 * 0.7, width: s, height: s * 1.4))
            } else if block.sealShape == .roundedSquare {
                let r = s * 0.15
                let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s), cornerWidth: r, cornerHeight: r, transform: nil)
                ctx.addPath(path)
            } else {
                ctx.addRect(CGRect(x: 0, y: 0, width: s, height: s))
            }
            ctx.fillPath()

            // 用 destination-out 混合模式抠出白字
            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            drawSealText(ctx: ctx, text: block.text, cx: s/2, cy: s/2, size: s, color: .white, fontFamily: block.fontFamily, fontId: block.fontId, fontManager: fontManager)
            ctx.restoreGState()
        }

        // 斑驳效果
        if block.sealDirty > 0 {
            applyDirtyEffect(ctx: ctx, size: s, dirty: block.sealDirty, seed: block.id.hashValue, shape: block.sealShape)
        }

        let image = ctx.makeImage()
        NSGraphicsContext.restoreGraphicsState()
        return image
    }

    private static func drawSealText(ctx: CGContext, text: String, cx: CGFloat, cy: CGFloat, size: CGFloat, color: CGColor, fontFamily: String, fontId: String? = nil, fontManager: FontManager? = nil) {
        let chars = Array(text)
        let len = chars.count

        var fontSize: CGFloat = size * 0.4
        if len == 1 { fontSize = size * 0.55 }
        else if len == 2 { fontSize = size * 0.45 }
        else if len == 3 { fontSize = size * 0.35 }
        else if len >= 4 { fontSize = size * 0.38 }

        let realFontFamily: String
        if let fm = fontManager, let fId = fontId {
            realFontFamily = fm.getFontFamily(fId)
        } else {
            realFontFamily = fontFamily
        }

        // 尝试获取字体，回退到系统字体
        let font: NSFont
        if let f = NSFont(name: realFontFamily, size: fontSize) {
            font = f
        } else if let f = NSFont(name: "PingFang SC", size: fontSize) {
            font = f
        } else {
            font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color)!,
            .paragraphStyle: paragraphStyle
        ]

        if len == 1 {
            drawChar(String(chars[0]), at: CGPoint(x: cx, y: cy), attrs: attrs, ctx: ctx)
        } else if len == 2 {
            let offset = size * 0.22
            drawChar(String(chars[0]), at: CGPoint(x: cx + offset, y: cy), attrs: attrs, ctx: ctx)
            drawChar(String(chars[1]), at: CGPoint(x: cx - offset, y: cy), attrs: attrs, ctx: ctx)
        } else if len == 3 {
            let ox = size * 0.22, oy = size * 0.22
            drawChar(String(chars[0]), at: CGPoint(x: cx + ox, y: cy - oy), attrs: attrs, ctx: ctx)
            drawChar(String(chars[1]), at: CGPoint(x: cx + ox, y: cy + oy), attrs: attrs, ctx: ctx)
            drawChar(String(chars[2]), at: CGPoint(x: cx - ox, y: cy), attrs: attrs, ctx: ctx)
        } else {
            let ox = size * 0.22, oy = size * 0.22
            let display = chars.prefix(4)
            drawChar(String(display[0]), at: CGPoint(x: cx + ox, y: cy - oy), attrs: attrs, ctx: ctx)
            drawChar(String(display[1]), at: CGPoint(x: cx + ox, y: cy + oy), attrs: attrs, ctx: ctx)
            drawChar(String(display[2]), at: CGPoint(x: cx - ox, y: cy - oy), attrs: attrs, ctx: ctx)
            drawChar(String(display[3]), at: CGPoint(x: cx - ox, y: cy + oy), attrs: attrs, ctx: ctx)
        }
    }

    private static func drawChar(_ char: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any], ctx: CGContext) {
        let nsStr = NSAttributedString(string: char, attributes: attrs)
        let line = CTLineCreateWithAttributedString(nsStr)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func applyDirtyEffect(ctx: CGContext, size: CGFloat, dirty: Int, seed: Int, shape: TextBlock.SealShape) {
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        ctx.setFillColor(CGColor.white)

        // 确定性伪随机（基于 seed）
        var s = UInt64(bitPattern: Int64(seed &+ 12345))
        func rand() -> CGFloat {
            s = (s &* 9301 &+ 49297) % 233280
            return CGFloat(s) / 233280.0
        }

        // 内部沙眼
        let dotCount = Int(Double(dirty) * 1.5 + Double(size) * Double(dirty) / 20.0)
        for _ in 0..<dotCount {
            let dx = rand() * size
            let dy = rand() * size
            let dr: CGFloat = 0.5 + rand() * 1.5
            ctx.addArc(center: CGPoint(x: dx, y: dy), radius: dr, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
        }

        // 边缘腐蚀
        let edgeCount = Int(Double(dirty) * 0.4)
        for _ in 0..<edgeCount {
            let er: CGFloat = 1.0 + rand() * 3.0
            var ex: CGFloat, ey: CGFloat
            if shape == .circle || shape == .oval {
                let angle = rand() * .pi * 2
                let rx = size / 2
                let ry = shape == .oval ? size / 2 * 0.7 : size / 2
                ex = size / 2 + cos(angle) * rx
                ey = size / 2 + sin(angle) * ry
            } else {
                let edgeSide = Int(rand() * 4)
                let pos = rand() * size
                switch edgeSide {
                case 0: ex = pos; ey = 0
                case 1: ex = size; ey = pos
                case 2: ex = pos; ey = size
                default: ex = 0; ey = pos
                }
            }
            ctx.addArc(center: CGPoint(x: ex, y: ey), radius: er, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
        }

        ctx.restoreGState()
    }
}
