import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

class AppViewModel: ObservableObject {
    // MARK: - Canvas State
    @Published var canvasState = CanvasState()
    @Published var activeBlockId: UUID?
    @Published var activeBlockViewRect: CGRect? = nil
    @Published var selectedBlockIds: Set<UUID> = []
    @Published var isDragging = false
    @Published var dragOffset: CGPoint = .zero

    // MARK: - UI State
    @Published var s2tMode: String = "simplified" // simplified | traditional
    @Published var currentTemplateId: String?
    @Published var currentFontId: String = "lishu"
    @Published var toastMessage: String?
    @Published var showDraftModal = false
    @Published var isDarkMode = true
    @Published var watermarkText: String = "— 诗笺生成"
    @Published var showExportPreview = false
    @Published var exportPreviewImage: NSImage?
    @Published var zoomScale: CGFloat = 1.0
    @Published var recentColors: [String] = ["#2c2c2c", "#c8a46e", "#b22222", "#1a1a2e", "#e8d5a0", "#8b4513", "#556b2f", "#4a3728"]

    // MARK: - History
    private var undoStack: [CanvasState] = []
    private var redoStack: [CanvasState] = []
    private var cancellables = Set<AnyCancellable>()

    // 背景图参数
    @Published var bgOpacity: Double = 100.0
    @Published var bgBlurRadius: Double = 0.0

    // 复制块缓存
    private var copiedBlock: TextBlock?

    // MARK: - Services
    let fontManager = FontManager()
    let draftManager = DraftManager()

    // 自动恢复 key
    private static let autoSaveKey = "ShiJian_AutoSave"

    // MARK: - Computed
    var canvasSize: CGSize { CGSize(width: canvasState.width, height: canvasState.height) }
    var blocks: [TextBlock] { canvasState.blocks }
    var isBackgroundNone: Bool {
        if case .none = canvasState.background { return true }
        return false
    }

    // MARK: - Init
    init() {
        // 订阅 FontManager 的变化并转发
        fontManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        fontManager.registerLocalFonts()
        canvasState.background = .none

        // 自动恢复
        autoRestore()

        // 自动下载缺失的字体
        downloadMissingFontsForCanvas()

        // 监听 app 退出，自动保存
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.autoSave()
        }
    }

    // MARK: - Auto Save / Restore

    func autoSave() {
        guard let data = try? JSONEncoder().encode(canvasState) else { return }
        UserDefaults.standard.set(data, forKey: Self.autoSaveKey)
    }

    private func autoRestore() {
        guard let data = UserDefaults.standard.data(forKey: Self.autoSaveKey),
              let state = try? JSONDecoder().decode(CanvasState.self, from: data) else { return }
        canvasState = state
        activeBlockId = state.activeBlockId
        undoStack = [state]
        syncBgParamsFromState()
        showToast("已恢复上次编辑")
    }

    // MARK: - Background / Template

    func selectTemplate(_ id: String) {
        guard let tpl = TemplateData.find(by: id) else { return }
        canvasState.background = tpl.bgConfig
        currentTemplateId = id  // 加这行确保模板高亮选中
        currentFontId = tpl.defaultFontId

        if tpl.type == .preset, let text = tpl.presetText {
            canvasState.blocks.removeAll()
            let dir: TextBlock.TextDirection = (tpl.presetDirection == "vertical") ? .vertical : .horizontal
            let block = TextBlock(
                text: text,
                x: canvasState.width / 2,
                y: canvasState.height / 2,
                fontFamily: fontManager.getFontFamily(tpl.defaultFontId),
                fontSize: tpl.defaultFontSize,
                colorHex: tpl.defaultColorHex,
                direction: dir,
                align: .center,
                fontId: tpl.defaultFontId,
                maxWidth: 400
            )
            canvasState.blocks.append(block)
            activeBlockId = block.id
        }
        pushHistory()
        syncBgParamsFromState()
        objectWillChange.send()
    }

    func setCustomBackground(hex: String) {
        currentTemplateId = nil
        canvasState.background = .solid(hex: hex)
        pushHistory()
        objectWillChange.send()
    }

    func setCustomBackgroundImage(url: URL) {
        currentTemplateId = nil
        let filename = url.lastPathComponent
        // 复制到 App Support
        let destDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShiJian/Images")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = destDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)

        canvasState.background = .image(filename: filename, opacity: 100.0, blurRadius: 0.0)
        bgOpacity = 100.0
        bgBlurRadius = 0.0
        pushHistory()
        objectWillChange.send()
    }

    func updateBackgroundImageParams(opacity: Double, blur: Double) {
        if case .image(let filename, _, _) = canvasState.background {
            canvasState.background = .image(filename: filename, opacity: opacity, blurRadius: blur)
            bgOpacity = opacity
            bgBlurRadius = blur
            pushHistory()
            objectWillChange.send()
        }
    }

    func syncBgParamsFromState() {
        if case .image(_, let opacity, let blur) = canvasState.background {
            bgOpacity = opacity
            bgBlurRadius = blur
        } else {
            bgOpacity = 100.0
            bgBlurRadius = 0.0
        }
    }

    // MARK: - Aspect Ratio
    func setAspectRatio(_ ratio: String) {
        let sizes: [String: (CGFloat, CGFloat)] = [
            "4:3": (1600, 1200), "1:1": (1600, 1600),
            "9:16": (1152, 2048), "16:9": (2048, 1152)
        ]
        guard let (w, h) = sizes[ratio] else { return }
        let oldW = canvasState.width, oldH = canvasState.height
        canvasState.width = w
        canvasState.height = h
        canvasState.ratio = ratio

        // 缩放现有块坐标
        for i in canvasState.blocks.indices {
            canvasState.blocks[i].x = canvasState.blocks[i].x / oldW * w
            canvasState.blocks[i].y = canvasState.blocks[i].y / oldH * h
        }
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Text Blocks
    func addTextBlock(_ text: String, style: [String: Any] = [:]) {
        let fId = style["fontId"] as? String ?? currentFontId
        let block = TextBlock(
            text: text,
            x: canvasState.width / 2,
            y: canvasState.height / 2,
            fontFamily: style["fontFamily"] as? String ?? fontManager.getFontFamily(fId),
            fontSize: style["fontSize"] as? CGFloat ?? 36,
            colorHex: style["colorHex"] as? String ?? "#2c2c2c",
            direction: style["direction"] as? TextBlock.TextDirection ?? .horizontal,
            align: style["align"] as? TextBlock.TextAlignment ?? .center,
            fontId: fId,
            maxWidth: style["maxWidth"] as? CGFloat ?? 400
        )
        canvasState.blocks.append(block)
        activeBlockId = block.id
        pushHistory()
        objectWillChange.send()
    }

    func addSealBlock(text: String, shape: TextBlock.SealShape, sealType: TextBlock.SealType, size: CGFloat, fontId: String) {
        let block = TextBlock(
            text: text,
            type: .seal,
            x: canvasState.width / 2,
            y: canvasState.height / 2,
            fontFamily: fontManager.getFontFamily(fontId),
            fontSize: 0,
            colorHex: "#b22222",
            fontId: fontId,
            sealShape: shape,
            sealType: sealType,
            sealSize: size,
            sealBorderWidth: 5.0
        )
        canvasState.blocks.append(block)
        activeBlockId = block.id
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Preset Poems

    func loadPreset(_ preset: PoemData.PresetItem) {
        canvasState.blocks.removeAll()
        let block = TextBlock(
            text: preset.text,
            x: canvasState.width / 2,
            y: canvasState.height / 2,
            fontFamily: fontManager.getFontFamily(preset.fontId),
            fontSize: 26,
            colorHex: preset.colorHex,
            direction: preset.direction,
            align: .center,
            fontId: preset.fontId,
            maxWidth: 400
        )
        canvasState.blocks.append(block)
        activeBlockId = block.id
        currentFontId = preset.fontId
        pushHistory()
        objectWillChange.send()
    }

    func updateBlock(_ id: UUID, updates: (inout TextBlock) -> Void) {
        guard let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { return }
        updates(&canvasState.blocks[idx])
        pushHistory()
        objectWillChange.send()
    }

    func deleteActiveBlock() {
        if !selectedBlockIds.isEmpty {
            canvasState.blocks.removeAll { selectedBlockIds.contains($0.id) }
            selectedBlockIds.removeAll()
        } else if let id = activeBlockId {
            canvasState.blocks.removeAll { $0.id == id }
        }
        activeBlockId = canvasState.blocks.first?.id
        pushHistory()
        objectWillChange.send()
    }

    func randomPoem() {
        let poem = PoemData.random()
        let processed = s2tMode == "traditional" ? ConvertService.toTraditional(poem) : ConvertService.toSimplified(poem)
        if let active = activeBlockId, let idx = canvasState.blocks.firstIndex(where: { $0.id == active }), canvasState.blocks[idx].type != .seal {
            canvasState.blocks[idx].text = processed
        } else {
            let dir = s2tMode == "traditional" ? TextBlock.TextDirection.vertical : TextBlock.TextDirection.horizontal
            addTextBlock(processed, style: ["direction": dir])
        }
        objectWillChange.send()
    }

    // MARK: - S2T
    func toggleS2T(_ mode: String) {
        s2tMode = mode
        guard let active = activeBlockId, let idx = canvasState.blocks.firstIndex(where: { $0.id == active }), canvasState.blocks[idx].type != .seal else { return }
        let converted = mode == "traditional" ? ConvertService.toTraditional(canvasState.blocks[idx].text) : ConvertService.toSimplified(canvasState.blocks[idx].text)
        canvasState.blocks[idx].text = converted
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Drag
    func beginDrag(at point: CGPoint, shiftHeld: Bool = false) {
        guard let block = CanvasRenderer.hitBlock(at: point, blocks: canvasState.blocks, fontManager: fontManager) else {
            // 点空白 → 取消所有选中
            if !shiftHeld {
                activeBlockId = nil
                selectedBlockIds.removeAll()
            }
            objectWillChange.send()
            return
        }

        if shiftHeld {
            // Shift+点击 → 切换多选
            if selectedBlockIds.contains(block.id) {
                selectedBlockIds.remove(block.id)
            } else {
                selectedBlockIds.insert(block.id)
            }
            activeBlockId = selectedBlockIds.count == 1 ? selectedBlockIds.first : nil
        } else {
            if activeBlockId != block.id || selectedBlockIds.count > 1 {
                activeBlockId = block.id
                selectedBlockIds = [block.id]
            }
        }
        isDragging = true
        dragOffset = CGPoint(x: point.x - block.x, y: point.y - block.y)
    }

    func continueDrag(at point: CGPoint) {
        if selectedBlockIds.count > 1 {
            // 多选 → 整体移动
            for id in selectedBlockIds {
                guard let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { continue }
                canvasState.blocks[idx].x = point.x - dragOffset.x + (canvasState.blocks[idx].x - (activeBlockId != nil ? canvasState.blocks.first(where: { $0.id == activeBlockId! })?.x ?? 0 : 0))
            }
            // 简化：统一偏移
            guard let firstId = selectedBlockIds.first,
                  let firstIdx = canvasState.blocks.firstIndex(where: { $0.id == firstId }) else { return }
            let dx = (point.x - dragOffset.x) - canvasState.blocks[firstIdx].x
            let dy = (point.y - dragOffset.y) - canvasState.blocks[firstIdx].y
            for id in selectedBlockIds {
                guard let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { continue }
                canvasState.blocks[idx].x += dx
                canvasState.blocks[idx].y += dy
            }
        } else {
            guard let id = activeBlockId, let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { return }
            canvasState.blocks[idx].x = point.x - dragOffset.x
            canvasState.blocks[idx].y = point.y - dragOffset.y
        }
        objectWillChange.send()
    }

    func endDrag() {
        if isDragging {
            isDragging = false
            pushHistory()
        }
    }

    // MARK: - Keyboard Move
    func moveActiveBlock(dx: CGFloat, dy: CGFloat) {
        guard let id = activeBlockId, let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { return }
        canvasState.blocks[idx].x += dx
        canvasState.blocks[idx].y += dy
        pushHistory()
        objectWillChange.send()
    }

    func moveActiveBlockFontSize(by delta: CGFloat) {
        guard let id = activeBlockId else { return }
        updateBlock(id) { block in
            if block.type == .seal {
                block.sealSize = max(20, min(300, block.sealSize + delta))
            } else {
                block.fontSize = max(10, min(100, block.fontSize + delta))
            }
        }
    }

    func moveActiveBlockUp() {
        guard let id = activeBlockId,
              let idx = canvasState.blocks.firstIndex(where: { $0.id == id }),
              idx < canvasState.blocks.count - 1 else { return }
        canvasState.blocks.swapAt(idx, idx + 1)
        pushHistory()
        objectWillChange.send()
    }

    func moveActiveBlockDown() {
        guard let id = activeBlockId,
              let idx = canvasState.blocks.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        canvasState.blocks.swapAt(idx, idx - 1)
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Export
    func exportImage(transparent: Bool = false) -> NSImage? {
        let size = canvasSize
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: Int(size.width) * 4, bitsPerPixel: 32
        )!
        rep.size = NSSize(width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        guard let gc = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        gc.shouldAntialias = true
        gc.imageInterpolation = .high
        NSGraphicsContext.current = gc

        let ctx = gc.cgContext
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = CGInterpolationQuality.high

        // 导出时不画选中框
        let saved = canvasState.activeBlockId
        canvasState.activeBlockId = nil
        // NSBitmapImageRep 的 CGContext 使用标准坐标系（y↑），
        // 传入 isFlipped: false 让 CanvasRenderer 反转 y 定位逻辑
        CanvasRenderer.draw(state: canvasState, ctx: ctx, width: size.width, height: size.height, isFlipped: false, fontManager: fontManager, transparent: transparent)
        canvasState.activeBlockId = saved

        // 右下角署名落款
        drawWatermark(ctx: ctx, size: size)

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private func drawWatermark(ctx: CGContext, size: CGSize) {
        guard !watermarkText.isEmpty else { return }
        let font = NSFont(name: "PingFang SC", size: 24) ?? NSFont.systemFont(ofSize: 24)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 0.4, alpha: 0.5)
        ]
        let nsStr = NSString(string: watermarkText)
        let textSize = nsStr.size(withAttributes: attrs)
        let padding: CGFloat = 16
        ctx.saveGState()
        // 这里 ctx 的坐标是 Core Graphics 默认的(非 flipped)，因为我们创建的是 NSBitmapImageRep
        nsStr.draw(at: CGPoint(x: size.width - textSize.width - padding,
                                y: padding),
                   withAttributes: attrs)
        ctx.restoreGState()
    }

    func exportToFile() {
        // 先显示预览
        exportPreviewImage = exportImage()
        showExportPreview = true
    }

    func confirmExport(options: ExportOptions) {
        guard let baseImage = exportImage(transparent: options.transparent),
              let data = baseImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else { return }

        // 按缩放比例重新采样
        let scaledW = Int(baseImage.size.width * options.scale)
        let scaledH = Int(baseImage.size.height * options.scale)
        let scaledImage = NSImage(size: NSSize(width: scaledW, height: scaledH))
        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        baseImage.draw(in: NSRect(x: 0, y: 0, width: scaledW, height: scaledH))
        scaledImage.unlockFocus()

        guard let scaledData = scaledImage.tiffRepresentation,
              let scaledBitmap = NSBitmapImageRep(data: scaledData) else { return }

        let fileData: Data?
        let fileType: UTType
        let fileName: String

        switch options.format {
        case .png:
            fileData = scaledBitmap.representation(using: .png, properties: [:])
            fileType = UTType.png
            fileName = "诗笺诗词.png"
        case .jpeg:
            fileData = scaledBitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            fileType = UTType.jpeg
            fileName = "诗笺诗词.jpg"
        }

        guard let dataOut = fileData else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [fileType]
        panel.nameFieldStringValue = fileName
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? dataOut.write(to: url)
                self.showToast("图片已导出")
            }
        }
    }

    // MARK: - Drafts
    func saveDraft() {
        let name = "草稿 \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        if draftManager.save(canvasState, name: name) {
            showToast("草稿已保存")
        } else {
            showToast("保存失败")
        }
    }

    // MARK: - 项目文件 (.shijian)
    func saveProject() {
        guard let data = try? JSONEncoder().encode(canvasState) else { showToast("编码失败"); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "诗笺项目.shijian"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
                self.showToast("项目已保存")
            }
        }
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url),
                  let state = try? JSONDecoder().decode(CanvasState.self, from: data) else {
                self.showToast("无法打开项目文件")
                return
            }
            self.canvasState = state
            self.activeBlockId = state.activeBlockId
            self.undoStack = [state]
            self.redoStack.removeAll()
            self.downloadMissingFontsForCanvas()
            self.syncBgParamsFromState()
            self.showToast("项目已打开")
        }
    }

    func loadDraft(_ draft: Draft) {
        guard let state = draftManager.load(draft) else { return }
        canvasState = state
        activeBlockId = state.activeBlockId
        if case .solid = state.background { }
        undoStack = [state]
        redoStack.removeAll()
        downloadMissingFontsForCanvas()
        syncBgParamsFromState()
        objectWillChange.send()
    }

    // MARK: - Undo / Redo
    func pushHistory() {
        undoStack.append(canvasState)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
        // 每次操作后自动保存
        autoSave()
    }

    func undo() {
        guard undoStack.count > 1 else { showToast("没有可撤销的步骤"); return }
        redoStack.append(undoStack.removeLast())
        canvasState = undoStack.last!
        activeBlockId = canvasState.activeBlockId
        objectWillChange.send()
    }

    func redo() {
        guard !redoStack.isEmpty else { showToast("没有可恢复的步骤"); return }
        let next = redoStack.removeLast()
        undoStack.append(next)
        canvasState = next
        activeBlockId = canvasState.activeBlockId
        objectWillChange.send()
    }

    // MARK: - Font Management & Autoloading

    func selectFont(id: String) {
        currentFontId = id
        if let activeId = activeBlockId {
            updateBlock(activeId) {
                $0.fontId = id
                $0.fontFamily = self.fontManager.getFontFamily(id)
            }
        }

        let def = FontDefinition.all.first { $0.id == id }
        if let def = def, case .google = def.source {
            Task {
                let success = await fontManager.loadGoogleFont(id)
                if success {
                    await MainActor.run {
                        if self.currentFontId == id {
                            if let activeId = self.activeBlockId {
                                self.updateBlock(activeId) {
                                    $0.fontFamily = self.fontManager.getFontFamily(id)
                                }
                            }
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        }
    }

    func downloadMissingFontsForCanvas() {
        let fontIds = Set(canvasState.blocks.compactMap { $0.fontId })
        for fontId in fontIds {
            if let def = FontDefinition.all.first(where: { $0.id == fontId }),
               case .google = def.source {
                if !fontManager.isLoaded(fontId) && !fontManager.isFontAvailable(fontId) {
                    Task {
                        _ = await fontManager.loadGoogleFont(fontId)
                    }
                }
            }
        }
    }

    // MARK: - Clipboard & Duplicate

    func copyActiveBlock() {
        guard let id = activeBlockId,
              let block = canvasState.blocks.first(where: { $0.id == id }) else { return }
        copiedBlock = block
    }

    func pasteBlock() {
        guard let block = copiedBlock else { return }
        var newBlock = block
        newBlock.id = UUID()
        newBlock.x += 40
        newBlock.y += 40
        canvasState.blocks.append(newBlock)
        activeBlockId = newBlock.id
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Alignment

    enum AlignmentType {
        case left, right, top, bottom, horizontalCenter, verticalCenter
    }

    func alignSelectedBlocks(_ type: AlignmentType) {
        let targets = selectedBlockIds.isEmpty ? (activeBlockId.map { [$0] } ?? []) : Array(selectedBlockIds)
        guard targets.count > 0 else { return }

        let blocksToAlign = canvasState.blocks.filter { targets.contains($0.id) }
        guard !blocksToAlign.isEmpty else { return }

        let rects = blocksToAlign.map { ($0.id, CanvasRenderer.blockRect($0, fontManager: fontManager)) }

        if targets.count == 1 {
            guard let blockId = targets.first,
                  let idx = canvasState.blocks.firstIndex(where: { $0.id == blockId }) else { return }
            let rect = rects[0].1
            switch type {
            case .horizontalCenter:
                canvasState.blocks[idx].x = canvasState.width / 2
            case .verticalCenter:
                canvasState.blocks[idx].y = canvasState.height / 2
            case .left:
                canvasState.blocks[idx].x = rect.width / 2
            case .right:
                canvasState.blocks[idx].x = canvasState.width - rect.width / 2
            case .top:
                canvasState.blocks[idx].y = rect.height / 2
            case .bottom:
                canvasState.blocks[idx].y = canvasState.height - rect.height / 2
            }
        } else {
            let minX = rects.map { $0.1.minX }.min() ?? 0
            let maxX = rects.map { $0.1.maxX }.max() ?? 0
            let minY = rects.map { $0.1.minY }.min() ?? 0
            let maxY = rects.map { $0.1.maxY }.max() ?? 0
            let midX = (minX + maxX) / 2
            let midY = (minY + maxY) / 2

            for id in targets {
                guard let idx = canvasState.blocks.firstIndex(where: { $0.id == id }) else { continue }
                let rect = rects.first(where: { $0.0 == id })!.1
                switch type {
                case .left:
                    let offsetX = canvasState.blocks[idx].x - rect.minX
                    canvasState.blocks[idx].x = minX + offsetX
                case .right:
                    let offsetX = rect.maxX - canvasState.blocks[idx].x
                    canvasState.blocks[idx].x = maxX - offsetX
                case .horizontalCenter:
                    let offsetX = canvasState.blocks[idx].x - rect.midX
                    canvasState.blocks[idx].x = midX + offsetX
                case .top:
                    let offsetY = canvasState.blocks[idx].y - rect.minY
                    canvasState.blocks[idx].y = minY + offsetY
                case .bottom:
                    let offsetY = rect.maxY - canvasState.blocks[idx].y
                    canvasState.blocks[idx].y = maxY - offsetY
                case .verticalCenter:
                    let offsetY = canvasState.blocks[idx].y - rect.midY
                    canvasState.blocks[idx].y = midY + offsetY
                }
            }
        }
        pushHistory()
        objectWillChange.send()
    }

    // MARK: - Toast
    func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.toastMessage == msg { self.toastMessage = nil }
        }
    }
}
