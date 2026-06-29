import SwiftUI
import AppKit

/// 画布视图 —— 用 NSViewRepresentable 包裹 Core Graphics 渲染
struct CanvasView: NSViewRepresentable {
    @EnvironmentObject var vm: AppViewModel
    let zoomScale: CGFloat  // 显式追踪缩放变化

    init(zoomScale: CGFloat = 1.0) {
        self.zoomScale = zoomScale
    }

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.vm = vm
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // 双击编辑回调
        view.onEditBlock = { blockId in
            vm.activeBlockId = blockId
            // 把文本复制到侧边栏的输入框里
            if vm.blocks.first(where: { $0.id == blockId }) != nil {
                vm.objectWillChange.send()
            }
        }
        return view
    }

    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        nsView.vm = vm
        nsView.needsDisplay = true
    }
}

// MARK: - Custom NSView

class CanvasNSView: NSView {
    weak var vm: AppViewModel?
    var onEditBlock: ((UUID) -> Void)?

    // 阻止画布区域拖动窗口（只允许拖动画布内文字块）
    override var mouseDownCanMoveWindow: Bool { false }

    override var isFlipped: Bool { true }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 注册拖拽接收
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let vm = vm, let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 计算居中偏移和缩放
        let zoom = vm.zoomScale
        let canvasW = vm.canvasState.width
        let canvasH = vm.canvasState.height
        let scale = min(bounds.width / canvasW, bounds.height / canvasH)
        let offsetX = (bounds.width - canvasW * scale) / 2
        let offsetY = (bounds.height - canvasH * scale) / 2

        ctx.saveGState()
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)

        // 用户缩放倍率
        ctx.saveGState()
        ctx.scaleBy(x: zoom, y: zoom)
        CanvasRenderer.draw(state: vm.canvasState, ctx: ctx, width: canvasW, height: canvasH, selectedIds: vm.selectedBlockIds, fontManager: vm.fontManager)
        ctx.restoreGState()

        ctx.restoreGState()

        // 棋盘格边缘（表示透明区域）
        drawCheckerboard(ctx: ctx, canvasRect: CGRect(x: offsetX, y: offsetY, width: canvasW * scale * zoom, height: canvasH * scale * zoom))

        // 计算物理包围盒并传递给 view model，供毛玻璃浮动工具栏对齐使用
        if let activeId = vm.activeBlockId,
           let activeBlock = vm.canvasState.blocks.first(where: { $0.id == activeId }) {
            let localRect = CanvasRenderer.blockRect(activeBlock, fontManager: vm.fontManager)
            let totalScale = scale * zoom
            let viewRect = CGRect(
                x: localRect.origin.x * totalScale + offsetX,
                y: localRect.origin.y * totalScale + offsetY,
                width: localRect.width * totalScale,
                height: localRect.height * totalScale
            )
            if vm.activeBlockViewRect != viewRect {
                DispatchQueue.main.async {
                    vm.activeBlockViewRect = viewRect
                }
            }
        } else {
            if vm.activeBlockViewRect != nil {
                DispatchQueue.main.async {
                    vm.activeBlockViewRect = nil
                }
            }
        }
    }

    private func drawCheckerboard(ctx: CGContext, canvasRect: CGRect) {
        ctx.saveGState()
        ctx.setFillColor(NSColor.tertiaryLabelColor.withAlphaComponent(0.15).cgColor)

        // 左侧
        if canvasRect.origin.x > 0 {
            ctx.fill(CGRect(x: 0, y: 0, width: canvasRect.origin.x, height: bounds.height))
        }
        // 右侧
        let rightEdge = canvasRect.origin.x + canvasRect.width
        if rightEdge < bounds.width {
            ctx.fill(CGRect(x: rightEdge, y: 0, width: bounds.width - rightEdge, height: bounds.height))
        }
        // 上方
        if canvasRect.origin.y > 0 {
            ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: canvasRect.origin.y))
        }
        // 下方
        let bottomEdge = canvasRect.origin.y + canvasRect.height
        if bottomEdge < bounds.height {
            ctx.fill(CGRect(x: 0, y: bottomEdge, width: bounds.width, height: bounds.height - bottomEdge))
        }
        ctx.restoreGState()
    }

    // MARK: - Mouse Events

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        guard let vm = vm, !vm.isDragging else { return }
        let pt = convertToCanvas(event.locationInWindow)
        if let _ = CanvasRenderer.hitBlock(at: pt, blocks: vm.blocks, fontManager: vm.fontManager) {
            NSCursor.openHand.push()
        } else {
            NSCursor.pop()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convertToCanvas(event.locationInWindow)
        let shiftHeld = event.modifierFlags.contains(.shift)

        // 双击 → 编辑
        if event.clickCount == 2 {
            if let block = CanvasRenderer.hitBlock(at: pt, blocks: vm?.blocks ?? [], fontManager: vm?.fontManager),
               block.type != .seal {
                onEditBlock?(block.id)
            }
            return
        }

        // 检测是否命中了文字块 → 拖拽光标
        if let _ = CanvasRenderer.hitBlock(at: pt, blocks: vm?.blocks ?? [], fontManager: vm?.fontManager) {
                NSCursor.openHand.push()
            NSCursor.closedHand.push()
        }

        vm?.beginDrag(at: pt, shiftHeld: shiftHeld)
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convertToCanvas(event.locationInWindow)
        vm?.continueDrag(at: pt)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        vm?.endDrag()
        NSCursor.pop()
        needsDisplay = true
    }

    /// 将窗口坐标转换为画布坐标
    private func convertToCanvas(_ windowPoint: NSPoint) -> CGPoint {
        let local = convert(windowPoint, from: nil)
        guard let vm = vm else { return local }
        let zoom = vm.zoomScale
        let scale = min(bounds.width / vm.canvasState.width, bounds.height / vm.canvasState.height)
        let offsetX = (bounds.width - vm.canvasState.width * scale) / 2
        let offsetY = (bounds.height - vm.canvasState.height * scale) / 2
        return CGPoint(
            x: (local.x - offsetX) / (scale * zoom),
            y: (local.y - offsetY) / (scale * zoom)
        )
    }

    override func keyDown(with event: NSEvent) {
        guard let vm = vm else { super.keyDown(with: event); return }

        if event.modifierFlags.contains(.command) {
            switch event.keyCode {
            case 24: // = / +
                vm.zoomScale = min(5.0, vm.zoomScale + 0.2)
                needsDisplay = true
                return
            case 27: // -
                vm.zoomScale = max(0.3, vm.zoomScale - 0.2)
                needsDisplay = true
                return
            case 29: // 0
                vm.zoomScale = 1.0
                needsDisplay = true
                return
            case 8: // C
                vm.copyActiveBlock()
                return
            case 9: // V
                vm.pasteBlock()
                needsDisplay = true
                return
            default:
                break
            }
        }

        switch event.keyCode {
        case 51, 117: // Delete / Forward Delete
            vm.deleteActiveBlock()
            needsDisplay = true
        case 126: // Up
            vm.moveActiveBlock(dx: 0, dy: event.modifierFlags.contains(.shift) ? -10 : -1)
        case 125: // Down
            vm.moveActiveBlock(dx: 0, dy: event.modifierFlags.contains(.shift) ? 10 : 1)
        case 123: // Left
            vm.moveActiveBlock(dx: event.modifierFlags.contains(.shift) ? -10 : -1, dy: 0)
        case 124: // Right
            vm.moveActiveBlock(dx: event.modifierFlags.contains(.shift) ? 10 : 1, dy: 0)
        default:
            super.keyDown(with: event)
        }
        needsDisplay = true
    }

    // MARK: - Right-click Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        guard let vm = vm else { return menu }

        let pt = convertToCanvas(event.locationInWindow)
        if let hitBlock = CanvasRenderer.hitBlock(at: pt, blocks: vm.blocks, fontManager: vm.fontManager) {
            // 右键命中了某个块
            let selectItem = NSMenuItem(title: "选中", action: #selector(rightClickSelect), keyEquivalent: "")
            selectItem.representedObject = hitBlock.id
            menu.addItem(selectItem)

            let deleteItem = NSMenuItem(title: "删除", action: #selector(rightClickDelete), keyEquivalent: "")
            deleteItem.representedObject = hitBlock.id
            menu.addItem(deleteItem)

            menu.addItem(.separator())

            // 置于顶层 / 底层
            let toFront = NSMenuItem(title: "置于顶层", action: #selector(rightClickToFront), keyEquivalent: "")
            toFront.representedObject = hitBlock.id
            menu.addItem(toFront)

            let upOne = NSMenuItem(title: "上移一层", action: #selector(rightClickUpOne), keyEquivalent: "")
            upOne.representedObject = hitBlock.id
            menu.addItem(upOne)

            let downOne = NSMenuItem(title: "下移一层", action: #selector(rightClickDownOne), keyEquivalent: "")
            downOne.representedObject = hitBlock.id
            menu.addItem(downOne)

            let toBack = NSMenuItem(title: "置于底层", action: #selector(rightClickToBack), keyEquivalent: "")
            toBack.representedObject = hitBlock.id
            menu.addItem(toBack)
        } else {
            let pasteItem = NSMenuItem(title: "粘贴文字", action: #selector(rightClickPaste), keyEquivalent: "")
            menu.addItem(pasteItem)
        }
        return menu
    }

    @objc private func rightClickSelect(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        vm?.activeBlockId = id
    }

    @objc private func rightClickDelete(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        vm?.activeBlockId = id
        vm?.deleteActiveBlock()
        needsDisplay = true
    }

    @objc private func rightClickToFront(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let idx = vm?.blocks.firstIndex(where: { $0.id == id }) else { return }
        let block = vm?.canvasState.blocks.remove(at: idx)
        if let block = block { vm?.canvasState.blocks.append(block); vm?.pushHistory() }
        needsDisplay = true
    }

    @objc private func rightClickUpOne(_ sender: NSMenuItem) {
        vm?.moveActiveBlockUp()
        needsDisplay = true
    }

    @objc private func rightClickDownOne(_ sender: NSMenuItem) {
        vm?.moveActiveBlockDown()
        needsDisplay = true
    }

    @objc private func rightClickToBack(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let idx = vm?.blocks.firstIndex(where: { $0.id == id }) else { return }
        let block = vm?.canvasState.blocks.remove(at: idx)
        if let block = block { vm?.canvasState.blocks.insert(block, at: 0); vm?.pushHistory() }
        needsDisplay = true
    }

    @objc private func rightClickPaste(_ sender: NSMenuItem) {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }
        vm?.addTextBlock(str)
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Scroll Wheel Zoom

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { super.scrollWheel(with: event); return }
        let delta = event.deltaY * 0.003
        let newZoom = max(0.3, min(5.0, (vm?.zoomScale ?? 1.0) + CGFloat(delta)))
        vm?.zoomScale = newZoom
        needsDisplay = true
    }

    // MARK: - Drag & Drop (背景图)
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types, types.contains(.fileURL) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return false }

        // 检查是否为图片文件
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        guard imageExtensions.contains(url.pathExtension.lowercased()) else { return false }

        vm?.setCustomBackgroundImage(url: url)
        needsDisplay = true
        return true
    }
}
