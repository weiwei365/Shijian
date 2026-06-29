import SwiftUI

// MARK: - 窗口配置器：透明标题栏 + 红绿灯融合
struct WindowConfigurator: NSViewRepresentable {
    let isDarkMode: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.styleMask.insert(.fullSizeContentView)
                // 深色模式下用 darkAqua appearance 让红绿灯变暗
                if isDarkMode {
                    window.appearance = NSAppearance(named: .darkAqua)
                }
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                if isDarkMode {
                    window.appearance = NSAppearance(named: .darkAqua)
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Bar
                TopBarView()

                // Main: Sidebar + Canvas
                HSplitView {
                    SidebarView()
                    ZStack(alignment: .topLeading) {
                        CanvasView(zoomScale: vm.zoomScale)
                            .onAppear {
                                // 仅在无自动恢复数据时才加载默认模板
                                if vm.canvasState.blocks.isEmpty {
                                    vm.selectTemplate("night-ink")
                                }
                            }
                        
                        if let viewRect = vm.activeBlockViewRect {
                            FloatingActionBarView(vm: vm, viewRect: viewRect)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: viewRect)
                        }
                    }
                }
            }

            // Toast overlay
            if let msg = vm.toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .cornerRadius(6)
                        .shadow(radius: 10)
                        .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: vm.toastMessage)
            }

            // Draft Modal
            if vm.showDraftModal {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { vm.showDraftModal = false }
                DraftModalView()
            }

            // Export Preview
            if vm.showExportPreview, let preview = vm.exportPreviewImage {
                Color.black.opacity(0.5).ignoresSafeArea()
                    .onTapGesture { vm.showExportPreview = false }
                ExportPreviewView(image: preview, isBgNone: vm.isBackgroundNone) { options in
                    vm.showExportPreview = false
                    vm.confirmExport(options: options)
                } onCancel: {
                    vm.showExportPreview = false
                }
            }
        }
        .background(WindowConfigurator(isDarkMode: vm.isDarkMode))
        .onAppear {
            // 设置初始画布比例
            vm.setAspectRatio("4:3")
        }
        .onExitCommand {
            if vm.showDraftModal {
                vm.showDraftModal = false
            }
        }
    }
}

// MARK: - Floating Action Bar

struct FloatingActionBarView: View {
    @ObservedObject var vm: AppViewModel
    let viewRect: CGRect

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { vm.moveActiveBlockFontSize(by: 2) }) {
                HStack(spacing: 2) {
                    Image(systemName: "textformat.size.larger")
                    Text("A+")
                }
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .help("增大字号")

            Button(action: { vm.moveActiveBlockFontSize(by: -2) }) {
                HStack(spacing: 2) {
                    Image(systemName: "textformat.size.smaller")
                    Text("A-")
                }
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .help("减小字号")

            Divider()
                .frame(height: 12)
                .background(Color.gray.opacity(0.3))

            Button(action: { vm.moveActiveBlockUp() }) {
                Image(systemName: "arrow.up.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .help("上移一层")

            Button(action: { vm.moveActiveBlockDown() }) {
                Image(systemName: "arrow.down.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .help("下移一层")

            Divider()
                .frame(height: 12)
                .background(Color.gray.opacity(0.3))

            Button(action: { vm.deleteActiveBlock() }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(4)
            .help("删除")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .position(x: viewRect.midX, y: viewRect.maxY + 30)
    }
}
