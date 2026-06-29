import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var vm: AppViewModel
    private let gold = Color(hex: "#d4a64a")

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "scroll.fill")
                    .font(.system(size: 12))
                    .foregroundColor(gold)
                Text("诗笺").font(.system(size: 13, weight: .semibold)).tracking(4)
            }
            .padding(.leading, 14)

            Spacer()

            HStack(spacing: 2) {
                topBtn(icon: vm.isDarkMode ? "sun.max" : "moon", action: { vm.isDarkMode.toggle() })
                Divider().frame(height: 14).padding(.horizontal, 4)

                topBtn(icon: "arrow.uturn.backward", action: { vm.undo() }).help("撤销 (⌘Z)")
                topBtn(icon: "arrow.uturn.forward", action: { vm.redo() }).help("重做 (⇧⌘Z)")

                Divider().frame(height: 14).padding(.horizontal, 4)

                // 缩放控件
                topBtn(icon: "minus.magnifyingglass", action: { vm.zoomScale = max(0.3, vm.zoomScale - 0.2) })
                    .help("缩小 (⌘滚轮)")
                Text("\(String(format: "%.0f", vm.zoomScale * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32)
                topBtn(icon: "plus.magnifyingglass", action: { vm.zoomScale = min(5.0, vm.zoomScale + 0.2) })
                    .help("放大 (⌘滚轮)")
                topBtn(icon: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right", action: { vm.zoomScale = 1.0 })
                    .help("重置缩放")

                Divider().frame(height: 14).padding(.horizontal, 4)

                topBtn(icon: "folder", action: { vm.openProject() }).help("打开项目")
                topBtn(icon: "square.and.arrow.down.on.square", action: { vm.saveProject() }).help("另存项目")

                Divider().frame(height: 14).padding(.horizontal, 4)

                Button(action: { vm.showDraftModal = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full").font(.system(size: 12))
                        Text("草稿").font(.system(size: 11))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                }
                .buttonStyle(.borderless)

                topBtn(icon: "square.and.arrow.up", action: { shareImage() })
                    .help("分享图片")

                Spacer().frame(width: 4)

                Button(action: { vm.exportToFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill").font(.system(size: 12))
                        Text("导出图片").font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(gold).foregroundColor(.white).cornerRadius(4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)
                .help("导出图片 (⌘E)")
            }
            .padding(.trailing, 14)
        }
        .frame(height: 36)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.08))
        }
    }

    func topBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.borderless)
    }

    func shareImage() {
        guard let image = vm.exportImage() else { return }
        let picker = NSSharingServicePicker(items: [image])
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            let rect = NSRect(x: contentView.bounds.width - 160, y: contentView.bounds.height - 40, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }
}
