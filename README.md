# 诗笺 · ShiJian

[![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![XcodeGen](https://img.shields.io/badge/built%20with-XcodeGen-lightgrey.svg)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 落墨成诗，抚笺成画。

**诗笺 (ShiJian)** 是一款专为 macOS 设计的国风诗词图文排版与美学创作应用。采用 Swift 与原生 SwiftUI 构建，提供宣纸洒金纹理、古典朱丝界格、自制金石印章以及极具禅意的水墨交互，帮助您将中国古典诗词排版成极具质感的唯美图片，支持高清无损导出及系统原生分享。

---

## 🎨 核心美学特性

* 📜 **程序化纸张材质**：纯数学算法（Core Graphics）动态渲染高精度纸张纹理：
  * **手工宣纸**：生成成百上千条浅褐色与白色的二次贝塞尔植物纤维，还原宣纸特有的丝缕细节。
  * **冷洒金笺**：散落不同大小与金色色泽的质感碎金箔，低调奢华。
  * 强度自由微调，支持视网膜视口缩放与超清无损平铺导出。
* 📐 **自适应古典界格**：支持绘制“朱丝栏（红格子）”与“乌丝栏（黑格子）”。
  * 仿照古籍装帧，外框采用“外粗内细”精美双线套框，栏格在 `2 - 20` 范围内自由切分，且完美支持横栏与竖栏排版。
* 🏷 **国风传统色盘**：精选六大传统矿物与植物雅色（朱砂、黛蓝、烟灰、鸭蛋青、苍黄、藕荷），鼠标悬停一键预览雅称，点按即时渲染。
* ☁️ **毛玻璃悬浮控制栏**：选中排版元素时，在其下方弹出轻量级 `.ultraThinMaterial` 毛玻璃操作条，无论您平移、拖拽或用滚轮缩放画布，操作条均以柔和的弹簧阻尼曲线（`spring`）实现流畅物理贴合，提供字号微调、图层移位和快捷删除。
* 🎨 **禅意水墨占位**：画布完全为空时，自动隐入朱砂八栏格和淡金色大字“笺”的写意水墨画卷，提示您起笔落墨；一经写入文本，图案自动渐隐，返璞归真。
* ✍️ **动态排版与印章**：
  * **文字块**：支持横排/竖排，字号、颜色、对齐、倾斜、描边、背景条与阴影全维度可调，长段文字支持动态边界换行。
  * **金石印章**：提供方印、圆印、圆方印与椭圆印四种形制，朱文/白文可选，内置斑驳做旧算法，模拟石料边缘风化。

---

## 🛠 本地开发与构建

如果您是开发者，可以通过以下步骤在本地编译并运行项目：

1. **安装 XcodeGen**：
   ```bash
   brew install xcodegen
   ```
2. **生成项目文件**：
   在根目录下运行以下命令，自动解析 `project.yml` 并生成 `ShiJian.xcodeproj`：
   ```bash
   xcodegen generate
   ```
3. **打开并运行**：
   ```bash
   open ShiJian.xcodeproj
   ```
   在 Xcode 中按下 `Cmd + R` 即可编译并在本地运行。

---

## 💾 安装与分发（非开发者）

1. 前往本仓库右侧的 [Releases](https://github.com/your-username/poetry-art-generator/releases) 页面，下载最新的 `ShiJian.dmg` 磁盘镜像。
2. 双击打开 `ShiJian.dmg`，将 `诗笺` 应用图标拖拽至 `Applications` (应用程序) 文件夹即可完成安装。

> ### ⚠️ macOS 安全性提示 (针对无证书运行)
> 
> 由于本应用属于开源软件，未购买 Apple 开发者账号进行证书签名。在 macOS 上首次运行可能会提示 **“已损坏，无法打开”** 或 **“身份不明的开发者”**。
>
> **解决方法**：
> 打开终端，复制并运行以下命令，清除 macOS 的 Quarantine 安全隔离标记，即可正常双击运行：
> ```bash
> xattr -cr /Applications/ShiJian.app
> ```

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。欢迎大家提交 Issue 和 Pull Request，一起让国风文化在现代设计中焕发生机！
