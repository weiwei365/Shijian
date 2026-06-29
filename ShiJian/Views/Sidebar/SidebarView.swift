import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Design Tokens
fileprivate let gold = Color(hex: "#d4a64a")
fileprivate let goldLight = Color(hex: "#d4a64a").opacity(0.12)
fileprivate let goldMuted = Color(hex: "#b8942e")
fileprivate let cardTitleSz: CGFloat = 12
fileprivate let labelSz: CGFloat = 10
fileprivate let subLabelSz: CGFloat = 9
fileprivate let valueSz: CGFloat = 10

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var textInput = ""
    @State private var fontSize: Double = 36
    @State private var fontColorHex = "#2c2c2c"
    @State private var textDirection = TextBlock.TextDirection.horizontal
    @State private var textAlign = TextBlock.TextAlignment.center
    @State private var isItalic = false
    @State private var strokeColorHex = "#000000"
    @State private var strokeWidth: Double = 0
    @State private var textBgColorHex = "#ffffff"
    @State private var textBgOpacity: Double = 0
    @State private var shadowColorHex: String = "#000000"
    @State private var shadowBlur: Double = 0
    @State private var rotation: Double = 0
    @State private var sealText = "印"
    @State private var sealShape = TextBlock.SealShape.square
    @State private var sealType = TextBlock.SealType.zhuwen
    @State private var sealFontId = "xiaozhuan"
    @State private var sealSize: Double = 60
    @State private var sealDirty: Double = 0
    @State private var sealPreviewImage: NSImage?
    @State private var effectExpanded = false
    @State private var hoveredTemplateId: String?
    @State private var hoveredFontId: String?
    @State private var hoveredRatio: String?
    @State private var hoveredSegLabel: String?
    @State private var maxWidth: Double = 400
    @State private var sealBorderWidth: Double = 5.0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                contentCard
                ratioCard
                alignmentCard
                templateCard
                paperGridCard
                fontCard
                styleCard
                effectCard
                sealCard
                watermarkCard
            }
            .padding(12)
        }
        .frame(minWidth: 230, idealWidth: 250, maxWidth: 280)
        .background(VisualEffectView(material: .sidebar))
        .onChange(of: vm.activeBlockId) { _ in syncFromActiveBlock() }
    }

    // MARK: - 1. 内容

    var contentCard: some View {
        CardView(title: "内容") {
            HStack(spacing: 6) {
                Button(action: { vm.randomPoem() }) {
                    Label("随机", systemImage: "dice")
                        .font(.system(size: labelSz, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                }
                .buttonStyle(.bordered).tint(gold)
                Spacer()
                Button(action: { vm.deleteActiveBlock() }) {
                    Text("删除").font(.system(size: labelSz))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                }
                .buttonStyle(.bordered).tint(.red.opacity(0.7))
            }
        } bodyContent: {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $textInput)
                    .font(.system(size: 11))
                    .frame(minHeight: 64, maxHeight: 120)
                    .padding(6)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                    .onChange(of: textInput) { handleText($0) }

                if vm.activeBlockId == nil && textInput.isEmpty {
                    Text("点击画布中的文字块，\n或点击「添加文字」开始创作")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }

            // 名篇快捷标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PoemData.presets) { preset in
                        Button(preset.title) {
                            vm.loadPreset(preset)
                        }
                        .font(.system(size: 9))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .buttonStyle(.bordered)
                        .tint(gold)
                        .controlSize(.small)
                    }
                }
            }

            Button(action: { vm.addTextBlock("在此输入诗词") }) {
                Label("添加文字", systemImage: "plus.circle.fill")
                    .font(.system(size: labelSz, weight: .medium))
                    .padding(.horizontal, 24).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).tint(gold)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - 2. 比例

    var ratioCard: some View {
        CardView(title: "画布比例") {
            HStack(spacing: 3) {
                ForEach(["4:3", "1:1", "9:16", "16:9"], id: \.self) { r in
                    let active = vm.canvasState.ratio == r
                    let hover = hoveredRatio == r
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { vm.setAspectRatio(r) }
                        Text(r)
                            .font(.system(size: labelSz, weight: active ? .semibold : .regular))
                            .foregroundColor(active ? goldMuted : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(active ? goldLight : (hover ? Color.white.opacity(0.05) : Color.clear))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(active ? gold : Color.clear, lineWidth: 1))
                    .onHover { h in
                        hoveredRatio = h ? r : nil
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
        }
    }

    // MARK: - 3. 模板

    var templateCard: some View {
        CardView(title: "模板") {
            VStack(spacing: 5) {
                Text("渐变").font(.system(size: subLabelSz, weight: .medium)).foregroundColor(.secondary)
                templateGrid(TemplateData.gradientTemplates)
                Text("纯色").font(.system(size: subLabelSz, weight: .medium)).foregroundColor(.secondary)
                templateGrid(TemplateData.solidTemplates)
                Text("搭配").font(.system(size: subLabelSz, weight: .medium)).foregroundColor(.secondary)
                templateGrid(TemplateData.presetTemplates)

                Divider().padding(.vertical, 1)

                HStack(spacing: 6) {
                    ColorPicker("", selection: Binding(get: { currentBgColor }, set: { vm.setCustomBackground(hex: $0.toHex()) }))
                        .labelsHidden()
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    Text("自定义背景色").font(.system(size: labelSz)).foregroundColor(.secondary)
                    Spacer()
                    Button(action: chooseBgImage) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 11))
                    }.buttonStyle(.borderless).foregroundColor(.secondary).help("上传背景图")
                }
                
                if case .image = vm.canvasState.background {
                    Divider().padding(.vertical, 2)
                    SegSlider(label: "模糊度", value: $vm.bgBlurRadius, range: 0...30, fmt: "%.0f px") {
                        vm.updateBackgroundImageParams(opacity: vm.bgOpacity, blur: vm.bgBlurRadius)
                    }
                    SegSlider(label: "不透明", value: $vm.bgOpacity, range: 0...100, fmt: "%.0f%%") {
                        vm.updateBackgroundImageParams(opacity: vm.bgOpacity, blur: vm.bgBlurRadius)
                    }
                }
            }
        }
    }

    var paperGridCard: some View {
        CardView(title: "信笺材质 (纸张与界格)") {
            VStack(spacing: 8) {
                // 1. 纸张材质 Picker
                rowSeg("纸面材质", Binding(
                    get: { vm.canvasState.paperTextureType },
                    set: { vm.canvasState.paperTextureType = $0; vm.pushHistory(); vm.objectWillChange.send() }
                ), ["无", "宣纸", "洒金"], values: [.none, .xuan, .goldSputtered]) { _ in }
                
                if vm.canvasState.paperTextureType != .none {
                    rowSlider("材质强度", Binding(
                        get: { vm.canvasState.paperTextureIntensity },
                        set: { vm.canvasState.paperTextureIntensity = $0; vm.pushHistory(); vm.objectWillChange.send() }
                    ), 10...100, fmt: "%.0f%%") { }
                }
                
                Divider().padding(.vertical, 2)
                
                // 2. 信笺界格
                rowToggle("启用界格", Binding(
                    get: { vm.canvasState.showGridLines },
                    set: { vm.canvasState.showGridLines = $0; vm.pushHistory(); vm.objectWillChange.send() }
                )) { }
                
                if vm.canvasState.showGridLines {
                    rowSeg("界格方向", Binding(
                        get: { vm.canvasState.gridLineDirection },
                        set: { vm.canvasState.gridLineDirection = $0; vm.pushHistory(); vm.objectWillChange.send() }
                    ), ["横栏", "竖栏"], values: [.horizontal, .vertical]) { _ in }
                    
                    rowSlider("栏格数量", Binding(
                        get: { Double(vm.canvasState.gridLineColumns) },
                        set: { vm.canvasState.gridLineColumns = Int($0); vm.pushHistory(); vm.objectWillChange.send() }
                    ), 2...20, fmt: "%.0f 格") { }
                    
                    rowColor("栏格颜色", Binding(
                        get: { vm.canvasState.gridLineColorHex },
                        set: { vm.canvasState.gridLineColorHex = $0; vm.pushHistory(); vm.objectWillChange.send() }
                    )) { }
                }
            }
        }
    }

    var currentBgColor: Color {
        if case .solid(let hex) = vm.canvasState.background { return Color(hex: hex) }
        return Color.white
    }

    func templateGrid(_ templates: [ArtTemplate]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(templates) { tpl in
                let active = vm.currentTemplateId == tpl.id
                let hover = hoveredTemplateId == tpl.id
                RoundedRectangle(cornerRadius: 4)
                    .fill(templateFill(tpl)).frame(height: 40)
                    .overlay(alignment: .bottom) {
                        Text(tpl.name).font(.system(size: subLabelSz, weight: .medium))
                            .foregroundColor(isDarkBg(tpl) ? .white : .black).padding(.bottom, 1)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(active ? gold : Color.clear, lineWidth: 1.5))
                    .shadow(color: active ? gold.opacity(0.25) : .black.opacity(0.03), radius: active ? 3 : 1)
                    .brightness(hover ? -0.08 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { vm.selectTemplate(tpl.id) }
                    .onHover { h in
                        hoveredTemplateId = h ? tpl.id : nil
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
        }
    }

    func templateFill(_ tpl: ArtTemplate) -> Color {
        switch tpl.bgConfig {
        case .solid(let hex): return Color(hex: hex)
        case .gradient(let colors, _): return Color(hex: colors.first ?? "#ffffff")
        default: return .gray
        }
    }

    func isDarkBg(_ tpl: ArtTemplate) -> Bool {
        switch tpl.bgConfig {
        case .solid(let hex): return hexIsDark(hex)
        case .gradient(let colors, _): return hexIsDark(colors.first ?? "#fff")
        default: return true
        }
    }

    func hexIsDark(_ h: String) -> Bool {
        let s = h.trimmingCharacters(in: CharacterSet(charactersIn: "#")).prefix(6)
        guard let v = UInt64(s, radix: 16) else { return true }
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return (r * 0.299 + g * 0.587 + b * 0.114) < 128
    }

    func chooseBgImage() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.image]
        p.begin { if $0 == .OK, let u = p.url { vm.setCustomBackgroundImage(url: u) } }
    }

    // MARK: - 4. 字体

    var fontCard: some View {
        CardView(title: "书法字体") {
            VStack(spacing: 0) {
                ForEach(FontDefinition.all) { def in
                    let loaded = vm.fontManager.isLoaded(def.id) || vm.fontManager.isFontAvailable(def.id)
                    let active = vm.currentFontId == def.id
                    HStack {
                        Text(def.displayName).font(.system(size: labelSz)).lineLimit(1)
                        if loaded {
                            Text("诗笺")
                                .font(.custom(vm.fontManager.getFontFamily(def.id), size: 9))
                                .foregroundColor(.secondary.opacity(0.35))
                                .lineLimit(1)
                        }
                        Spacer()
                        if active { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(goldMuted) }
                        else if vm.fontManager.downloadingFonts.contains(def.id) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                        else if !loaded { Image(systemName: "icloud.and.arrow.down").font(.system(size: 8)).foregroundColor(.secondary.opacity(0.4)) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(active ? goldLight : (hoveredFontId == def.id ? Color.white.opacity(0.05) : Color.clear))
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.selectFont(id: def.id)
                    }
                    .onHover { h in
                        hoveredFontId = h ? def.id : nil
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
        }
    }

    // MARK: - 5. 文字样式

    var styleCard: some View {
        CardView(title: "文字样式") {
            rowSlider("字号", $fontSize, 14...100, fmt: "%.0f pt") { applyStyle() }
            if textDirection == .horizontal {
                rowSlider("换行宽", $maxWidth, 100...1200, fmt: "%.0f pt") { applyStyle() }
            }
            rowColor("颜色", $fontColorHex) { applyStyle() }
            traditionalColorPalette
            rowSeg("排列", $textDirection, ["横", "竖"], values: [.horizontal, .vertical]) { _ in applyStyle() }
            rowSeg("对齐", $textAlign, ["左", "中", "右"], values: [.left, .center, .right]) { _ in applyStyle() }
            rowSeg("繁简", $vm.s2tMode, ["简", "繁"], values: ["simplified", "traditional"]) { vm.toggleS2T($0) }
            rowSlider("旋转", $rotation, -45...45, fmt: "%.0f°") { applyStyle() }
        }
    }

    // MARK: - Traditional Color Palette

    private struct TraditionalColor: Identifiable {
        let id = UUID()
        let name: String
        let hex: String
    }

    private var traditionalColors: [TraditionalColor] {
        [
            TraditionalColor(name: "朱砂", hex: "#b22222"),
            TraditionalColor(name: "黛蓝", hex: "#1a3b5c"),
            TraditionalColor(name: "烟灰", hex: "#4a4a4a"),
            TraditionalColor(name: "鸭蛋青", hex: "#8ba89f"),
            TraditionalColor(name: "苍黄", hex: "#c8a46e"),
            TraditionalColor(name: "藕荷", hex: "#b0a4c0")
        ]
    }

    private var traditionalColorPalette: some View {
        HStack(spacing: 5) {
            Text("国风").font(.system(size: 10)).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
            
            HStack(spacing: 6) {
                ForEach(traditionalColors) { c in
                    Circle()
                        .fill(Color(hex: c.hex))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(fontColorHex.lowercased() == c.hex.lowercased() ? gold : Color.secondary.opacity(0.25), lineWidth: fontColorHex.lowercased() == c.hex.lowercased() ? 1.5 : 0.5))
                        .shadow(color: .black.opacity(0.1), radius: 1)
                        .help(c.name)
                        .contentShape(Circle())
                        .onTapGesture {
                            fontColorHex = c.hex
                            applyStyle()
                        }
                        .onHover { h in
                            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 6. 效果

    var effectCard: some View {
        CardView(title: "效果") {
            VStack(spacing: 0) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { effectExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: effectExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8)).foregroundColor(.secondary)
                        Text(effectExpanded ? "收起" : "展开全部")
                            .font(.system(size: labelSz)).foregroundColor(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, effectExpanded ? 6 : 0)

                if effectExpanded {
                    rowToggle("倾斜", $isItalic) { applyStyle() }
                    rowColor("描边", $strokeColorHex) { applyStyle() }
                    rowSlider("描边宽", $strokeWidth, 0...8, fmt: "%.1f") { applyStyle() }
                    rowColor("底色", $textBgColorHex) { applyStyle() }
                    rowSlider("透明", $textBgOpacity, 0...100, fmt: "%.0f%%") { applyStyle() }
                    rowColor("阴影", $shadowColorHex) { applyStyle() }
                    rowSlider("模糊", $shadowBlur, 0...20, fmt: "%.0f") { applyStyle() }
                }
            }
        }
    }

    // MARK: - 7. 印章

    var sealCard: some View {
        CardView(title: "印章") {
            TextField("1-4字", text: $sealText)
                .textFieldStyle(.roundedBorder).font(.system(size: labelSz))
                .onChange(of: sealText) { v in
                    if let id = vm.activeBlockId { vm.updateBlock(id) { $0.text = v } }
                    refreshSealPreview()
                }

            rowSeg("形状", $sealShape, ["方", "圆", "圆方", "椭圆"], values: [.square, .circle, .roundedSquare, .oval]) { _ in applySeal() }
            rowSeg("样式", $sealType, ["朱文", "白文"], values: [.zhuwen, .baiwen]) { _ in applySeal() }
            rowSeg("字体", $sealFontId, ["篆", "隶", "仿"], values: ["xiaozhuan", "lishu", "fangsong"]) { _ in applySeal() }
            rowSlider("边框宽", $sealBorderWidth, 1...10, fmt: "%.0f") { applySeal() }
            rowSlider("大小", $sealSize, 30...150, fmt: "%.0f") { applySeal() }
            rowSlider("斑驳", $sealDirty, 0...100, fmt: "%.0f%%") { applySeal() }

            // 印章实时预览
            HStack {
                Spacer()
                if let preview = sealPreviewImage {
                    Image(nsImage: preview)
                        .resizable().interpolation(.high)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .frame(width: 60, height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                }
                Spacer()
            }
            .padding(.vertical, 4)

            Button(action: {
                vm.addSealBlock(text: sealText, shape: sealShape, sealType: sealType, size: sealSize, fontId: sealFontId)
            }) {
                Label("生成印章", systemImage: "seal.fill")
                    .font(.system(size: labelSz, weight: .medium))
                    .padding(.horizontal, 24).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).tint(gold)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear { refreshSealPreview() }
    }

    // MARK: - Reusable Rows (改为 struct 确保 SwiftUI 状态追踪正确)

    func rowSlider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, fmt: String, action: @escaping () -> Void) -> some View {
        SegSlider(label: label, value: value, range: range, fmt: fmt, action: action)
    }

    func rowColor(_ label: String, _ hex: Binding<String>, action: @escaping () -> Void) -> some View {
        SegColor(label: label, hex: hex, action: action, recentColors: vm.recentColors)
    }

    func rowSeg<Value: Hashable>(_ label: String, _ sel: Binding<Value>, _ opts: [String], values: [Value], action: @escaping (Value) -> Void) -> some View {
        SegButtonGroup(label: label, sel: sel, opts: opts, values: values, action: action)
    }

    func rowToggle(_ label: String, _ isOn: Binding<Bool>, action: @escaping () -> Void) -> some View {
        SegToggle(label: label, isOn: isOn, action: action)
    }

    // MARK: - 8. 署名落款

    var watermarkCard: some View {
        CardView(title: "署名落款") {
            HStack(spacing: 6) {
                TextField("导出图署名", text: $vm.watermarkText)
                    .textFieldStyle(.roundedBorder).font(.system(size: labelSz))
                Button(action: { vm.watermarkText = "" }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                }
                .buttonStyle(.borderless).foregroundColor(.secondary)
                .opacity(vm.watermarkText.isEmpty ? 0 : 1)
            }
        }
    }

    // MARK: - Actions

    func handleText(_ t: String) {
        guard let id = vm.activeBlockId else {
            if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { vm.addTextBlock(t) }
            return
        }
        guard let b = vm.blocks.first(where: { $0.id == id }), b.type != .seal else { return }
        vm.updateBlock(id) { $0.text = t }
    }

    func refreshSealPreview() {
        let tempBlock = TextBlock(
            text: sealText,
            type: .seal,
            x: 0, y: 0,
            fontFamily: vm.fontManager.getFontFamily(sealFontId),
            fontSize: 0,
            colorHex: "#b22222",
            fontId: sealFontId,
            sealShape: sealShape,
            sealType: sealType,
            sealSize: CGFloat(sealSize),
            sealDirty: Int(sealDirty),
            sealBorderWidth: CGFloat(sealBorderWidth)
        )
        if let cgImage = SealRenderer.render(block: tempBlock, fontManager: vm.fontManager) {
            sealPreviewImage = NSImage(cgImage: cgImage, size: NSSize(width: sealSize, height: sealSize))
        }
    }

    func applyStyle() {
        saveRecentColor(fontColorHex)
        saveRecentColor(strokeColorHex)
        saveRecentColor(textBgColorHex)
        saveRecentColor(shadowColorHex)
        guard let id = vm.activeBlockId else { return }
        vm.updateBlock(id) {
            $0.fontSize = fontSize; $0.colorHex = fontColorHex
            $0.direction = textDirection; $0.align = textAlign
            $0.italic = isItalic; $0.strokeColorHex = strokeColorHex
            $0.strokeWidth = strokeWidth; $0.textBgColorHex = textBgColorHex
            $0.textBgOpacity = Int(textBgOpacity)
            $0.shadowColorHex = shadowColorHex; $0.shadowBlur = shadowBlur
            $0.rotation = rotation
            $0.maxWidth = CGFloat(maxWidth)
        }
    }

    private func saveRecentColor(_ hex: String) {
        if !vm.recentColors.contains(hex) {
            vm.recentColors.insert(hex, at: 0)
            if vm.recentColors.count > 8 { vm.recentColors.removeLast() }
        }
    }

    func applySeal() {
        refreshSealPreview()
        guard let id = vm.activeBlockId, let b = vm.blocks.first(where: { $0.id == id }), b.type == .seal else { return }
        vm.updateBlock(id) {
            $0.sealShape = sealShape; $0.sealType = sealType
            $0.fontFamily = vm.fontManager.getFontFamily(sealFontId)
            $0.fontId = sealFontId
            $0.sealSize = sealSize; $0.sealDirty = Int(sealDirty)
            $0.sealBorderWidth = CGFloat(sealBorderWidth)
        }
    }

    func syncFromActiveBlock() {
        guard let id = vm.activeBlockId, let b = vm.blocks.first(where: { $0.id == id }) else { textInput = ""; return }
        if b.type == .seal {
            textInput = ""; sealText = b.text; sealShape = b.sealShape
            sealType = b.sealType; sealSize = Double(b.sealSize); sealDirty = Double(b.sealDirty)
            sealBorderWidth = Double(b.sealBorderWidth ?? 5.0)
        } else {
            textInput = b.text; fontSize = Double(b.fontSize); fontColorHex = b.colorHex
            textDirection = b.direction; textAlign = b.align; isItalic = b.italic
            strokeColorHex = b.strokeColorHex; strokeWidth = Double(b.strokeWidth)
            textBgColorHex = b.textBgColorHex; textBgOpacity = Double(b.textBgOpacity)
            shadowColorHex = b.shadowColorHex; shadowBlur = Double(b.shadowBlur)
            rotation = b.rotation
            maxWidth = Double(b.maxWidth ?? 400.0)
        }
    }

    // MARK: - Alignment Panel

    var alignmentCard: some View {
        Group {
            if vm.activeBlockId != nil || !vm.selectedBlockIds.isEmpty {
                CardView(title: "排列对齐") {
                    HStack(spacing: 8) {
                        Button(action: { vm.alignSelectedBlocks(.left) }) {
                            Image(systemName: "align.horizontal.left").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("左对齐")
                        
                        Button(action: { vm.alignSelectedBlocks(.horizontalCenter) }) {
                            Image(systemName: "align.horizontal.center").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("水平居中")
                        
                        Button(action: { vm.alignSelectedBlocks(.right) }) {
                            Image(systemName: "align.horizontal.right").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("右对齐")
                        
                        Divider().frame(height: 12)
                        
                        Button(action: { vm.alignSelectedBlocks(.top) }) {
                            Image(systemName: "align.vertical.top").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("顶对齐")
                        
                        Button(action: { vm.alignSelectedBlocks(.verticalCenter) }) {
                            Image(systemName: "align.vertical.center").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("垂直居中")
                        
                        Button(action: { vm.alignSelectedBlocks(.bottom) }) {
                            Image(systemName: "align.vertical.bottom").font(.system(size: 11))
                        }.buttonStyle(.bordered).help("底对齐")
                    }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

// MARK: - Card Component

struct CardView<Header: View, BodyContent: View>: View {
    let title: String; let header: Header; let bodyContent: BodyContent
    init(title: String, @ViewBuilder header: () -> Header = { EmptyView() }, @ViewBuilder bodyContent: () -> BodyContent) {
        self.title = title; self.header = header(); self.bodyContent = bodyContent()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.system(size: cardTitleSz, weight: .semibold)).foregroundColor(.secondary); Spacer(); header }
            bodyContent.font(.system(size: labelSz))
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(7)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectView: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        func makeNSView(context: Context) -> NSVisualEffectView {
            let v = NSVisualEffectView(); v.material = material; v.state = .followsWindowActiveState; return v
        }
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }



// MARK: - Segmented Row Components (struct 确保 SwiftUI 正确追踪 @Binding)

struct SegSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let fmt: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
            Slider(value: $value, in: range)
                .tint(Color(hex: "#d4a64a"))
                .onChange(of: value) { _ in action() }
            Text(String(format: fmt, value)).font(.system(size: valueSz, design: .monospaced)).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
        }
    }
}

struct SegColor: View {
    let label: String
    @Binding var hex: String
    let action: () -> Void
    var recentColors: [String] = []

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                ColorPicker("", selection: Binding(
                    get: { Color(hex: hex) },
                    set: { c in hex = c.toHex(); action() }
                ))
                .labelsHidden().frame(width: 18, height: 18).clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                Text(hex).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
            // 快速选色
            if !recentColors.isEmpty {
                HStack(spacing: 3) {
                    Spacer().frame(width: 36)
                    HStack(spacing: 3) {
                        ForEach(Array(recentColors.prefix(4)), id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                                .onTapGesture {
                                    hex = c
                                    action()
                                }
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

struct SegButtonGroup<Value: Hashable>: View {
    let label: String
    @Binding var sel: Value
    let opts: [String]
    let values: [Value]
    let action: (Value) -> Void

    @State private var hoveredVal: Value? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
            HStack(spacing: 4) {
                ForEach(Array(zip(opts, values)), id: \.1) { (title, val) in
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { sel = val; action(val) }
                        Text(title)
                            .font(.system(size: 10, weight: sel == val ? .semibold : .regular))
                            .foregroundColor(sel == val ? Color(hex: "#b8942e") : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(sel == val ? Color(hex: "#d4a64a").opacity(0.12) : (hoveredVal == val ? Color.white.opacity(0.05) : Color.clear))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(sel == val ? Color(hex: "#d4a64a") : Color.clear, lineWidth: 1))
                    .onHover { h in
                        hoveredVal = h ? val : nil
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
        }
    }
}

struct SegToggle: View {
    let label: String
    @Binding var isOn: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().scaleEffect(0.65)
                .toggleStyle(.switch)
                .tint(Color(hex: "#d4a64a"))
                .onChange(of: isOn) { _ in action() }
        }
    }
}
