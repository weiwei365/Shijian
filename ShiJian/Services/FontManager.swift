import Foundation
import AppKit
import CoreText

// MARK: - Font Definition

struct FontDefinition: Identifiable {
    let id: String
    let name: String
    let displayName: String   // 侧栏显示名
    let source: FontSource

    enum FontSource {
        case local(filename: String, psName: String)    // 文件名 + PostScript 名
        case google(family: String)                     // Google Fonts family 名
    }
}

extension FontDefinition {
    static let all: [FontDefinition] = [
        FontDefinition(id: "lishu", name: "古雅隶书", displayName: "古雅隶书",
                       source: .local(filename: "lishu.ttf", psName: "LiSu")),
        FontDefinition(id: "shoujinti", name: "瘦金书体", displayName: "徽宗瘦金",
                       source: .local(filename: "shoujinti.ttf", psName: "SJ-wjq135")),
        FontDefinition(id: "fangsong", name: "朱雀仿宋", displayName: "朱雀仿宋",
                       source: .local(filename: "fangsong.ttf", psName: "ZhuqueFangsong-Regular")),
        FontDefinition(id: "xiaozhuan", name: "秦风小篆", displayName: "秦风小篆",
                       source: .local(filename: "xiaozhuan.ttf", psName: "FZXZTFW--GB1-0")),

        FontDefinition(id: "ma-shan-zheng", name: "马善楷书", displayName: "马善楷书",
                       source: .google(family: "Ma+Shan+Zheng")),
        FontDefinition(id: "zcool-xiaowei", name: "站酷小薇", displayName: "站酷小薇",
                       source: .google(family: "ZCOOL+XiaoWei")),
        FontDefinition(id: "zcool-qingke", name: "稚趣黄油", displayName: "稚趣黄油",
                       source: .google(family: "ZCOOL+QingKe+HuangYou")),
        FontDefinition(id: "noto-serif-sc", name: "思源宋体", displayName: "思源宋体",
                       source: .google(family: "Noto+Serif+SC")),
        FontDefinition(id: "noto-sans-sc", name: "思源黑体", displayName: "思源黑体",
                       source: .google(family: "Noto+Sans+SC")),
        FontDefinition(id: "zcool-kuaile", name: "快乐墨迹", displayName: "快乐墨迹",
                       source: .google(family: "ZCOOL+KuaiLe")),
        FontDefinition(id: "liu-jian-mao-cao", name: "手写狂草", displayName: "手写狂草",
                       source: .google(family: "Liu+Jian+Mao+Cao")),
        FontDefinition(id: "long-cang", name: "龙藏行书", displayName: "龙藏行书",
                       source: .google(family: "Long+Cang")),
        FontDefinition(id: "zhi-mang-xing", name: "志芒行草", displayName: "志芒行草",
                       source: .google(family: "Zhi+Mang+Xing"))
    ]
}

// MARK: - Font Manager

class FontManager: ObservableObject {
    @Published var loadedFonts: Set<String> = []
    @Published var downloadingFonts: Set<String> = []
    @Published var currentFontId: String = "lishu"

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShiJian/Fonts")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Local Font Registration

    func registerLocalFonts() {
        guard let resourceDir = Bundle.main.resourceURL else {
            print("[FontManager] Resource directory not found")
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: resourceDir, includingPropertiesForKeys: nil)) ?? []
        let ttfFiles = files.filter { $0.pathExtension == "ttf" }
        print("[FontManager] Found \(ttfFiles.count) TTF files in bundle resources")

        for def in FontDefinition.all {
            guard case .local(let filename, let psName) = def.source else { continue }
            // 字体文件现在直接放在 Resources/ 根目录（由 Xcode Copy Bundle Resources 复制）
            let url = resourceDir.appendingPathComponent(filename)

            guard FileManager.default.fileExists(atPath: url.path) else {
                print("[FontManager] ⚠️ Local font file not found: \(filename)")
                continue
            }

            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                loadedFonts.insert(def.id)
                print("[FontManager] ✓ Registered: \(def.name) (PS: \(psName))")
            } else {
                let err = error?.takeRetainedValue().localizedDescription ?? "unknown"
                print("[FontManager] ✗ Failed to register \(filename): \(err)")
                // 尝试用 CTFontDescriptor 直接加载
                if registerFontManually(url: url, psName: psName) {
                    loadedFonts.insert(def.id)
                    print("[FontManager] ✓ Manually loaded: \(def.name)")
                }
            }
        }
    }

    /// 如果 CTFontManager 注册失败，用 Core Text 手动加载
    private func registerFontManually(url: URL, psName: String) -> Bool {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &error) { return true }
        return false
    }

    // MARK: - Font Family Lookup

    func getFontFamily(_ id: String) -> String {
        guard let def = FontDefinition.all.first(where: { $0.id == id }) else {
            return "PingFang SC"
        }
        switch def.source {
        case .local(_, let psName):
            return psName
        case .google(let family):
            // 从缓存目录或注册表中获取实际 family 名
            return resolveGoogleFontFamily(id: id, family: family.replacingOccurrences(of: "+", with: " "))
        }
    }

    private func resolveGoogleFontFamily(id: String, family: String) -> String {
        // 先检查缓存文件是否已注册
        let cached = cacheDir.appendingPathComponent("\(id).ttf")
        if FileManager.default.fileExists(atPath: cached.path) {
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(cached as CFURL) as? [CTFontDescriptor],
               let first = descriptors.first,
               let name = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String {
                    return name
            }
        }
        // 检查系统是否已有该字体
        if let _ = NSFont(name: family, size: 12) {
            return family
        }
        return "PingFang SC"
    }

    func isLoaded(_ id: String) -> Bool {
        loadedFonts.contains(id)
    }

    func isFontAvailable(_ id: String) -> Bool {
        if loadedFonts.contains(id) { return true }
        let family = getFontFamily(id)
        return NSFont(name: family, size: 12) != nil
    }

    // MARK: - Google Font Download (via Google Fonts CSS API)

    func loadGoogleFont(_ id: String) async -> Bool {
        guard let def = FontDefinition.all.first(where: { $0.id == id }),
              case .google(let family) = def.source else { return false }

        if isLoaded(id) { return true }

        // 标记下载中
        await MainActor.run { [weak self] in self?.downloadingFonts.insert(id) }
        defer { Task { await MainActor.run { [weak self] in self?.downloadingFonts.remove(id) } } }

        // 如果系统已安装，直接标记为已加载
        let plainFamily = family.replacingOccurrences(of: "+", with: " ")
        if NSFont(name: plainFamily, size: 12) != nil {
            _ = await MainActor.run { [weak self] in self?.loadedFonts.insert(id) }
            return true
        }

        let cachedURL = cacheDir.appendingPathComponent("\(id).ttf")
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            if registerFont(fileURL: cachedURL, id: id) { return true }
        }

        // Step 1: 从 Google Fonts CSS API 获取真实 TTF 下载链接
        let cssURLStr = "https://fonts.googleapis.com/css2?family=\(family)&display=swap"
        guard let cssURL = URL(string: cssURLStr) else { return false }

        do {
            var req = URLRequest(url: cssURL)
            // 必须带 UA，否则 Google 返回 woff2 而非 ttf
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

            let (cssData, _) = try await URLSession.shared.data(for: req)
            guard let css = String(data: cssData, encoding: .utf8) else { return false }

            // 提取 url(...) 中的链接
            guard let urlStart = css.range(of: "url("),
                  let urlEnd = css.range(of: ")", range: urlStart.upperBound..<css.endIndex) else {
                print("[FontManager] ✗ Cannot parse CSS for \(def.name)")
                return false
            }
            let fontURLStr = String(css[urlStart.upperBound..<urlEnd.lowerBound])
            guard let fontURL = URL(string: fontURLStr) else { return false }

            // Step 2: 下载 TTF
            let (ttfData, _) = try await URLSession.shared.data(from: fontURL)
            try ttfData.write(to: cachedURL)

            return registerFont(fileURL: cachedURL, id: id)
        } catch {
            print("[FontManager] ✗ Download failed for \(def.name): \(error.localizedDescription)")
            return false
        }
    }

    private func registerFont(fileURL: URL, id: String) -> Bool {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, &error) {
            DispatchQueue.main.async { [weak self] in self?.loadedFonts.insert(id) }
            print("[FontManager] ✓ Registered: \(id)")
            return true
        }
        // Try alternative registration
        if let dataProvider = CGDataProvider(url: fileURL as CFURL),
           let cgFont = CGFont(dataProvider),
           CTFontManagerRegisterGraphicsFont(cgFont, &error) {
            DispatchQueue.main.async { [weak self] in self?.loadedFonts.insert(id) }
            print("[FontManager] ✓ Registered via CGFont: \(id)")
            return true
        }
        print("[FontManager] ✗ Font registration failed for \(id)")
        return false
    }
}
