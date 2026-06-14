import SwiftUI

struct ExportPreviewView: View {
    let image: NSImage
    let isBgNone: Bool
    let onConfirm: (ExportOptions) -> Void
    let onCancel: () -> Void

    @State private var scale: Double = 1
    @State private var format: ExportFormat = .png
    @State private var transparent: Bool = false

    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
    }

    var exportSizeLabel: String {
        let w = Int(image.size.width * scale)
        let h = Int(image.size.height * scale)
        return "\(w) × \(h) px"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("导出预览").font(.headline)

            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 500, maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 10)

            // Options
            VStack(spacing: 8) {
                HStack {
                    Text("缩放").font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .trailing)
                    Slider(value: $scale, in: 0.25...3, step: 0.25)
                        .tint(Color(hex: "#d4a64a"))
                    Text("\(String(format: "%.0f", scale * 100))%").font(.caption.monospaced()).foregroundColor(.secondary).frame(width: 36)
                }
                HStack {
                    Text(exportSizeLabel).font(.caption.monospaced()).foregroundColor(.secondary)
                    Spacer()
                    
                    if isBgNone && format == .png {
                        Toggle("透明背景", isOn: $transparent)
                            .toggleStyle(.checkbox)
                            .tint(Color(hex: "#d4a64a"))
                            .padding(.trailing, 6)
                    }
                    
                    Picker("", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.2))
            .cornerRadius(6)

            HStack(spacing: 12) {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.escape)
                Button("保存...") {
                    onConfirm(ExportOptions(scale: scale, format: format, transparent: transparent))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#d4a64a"))
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

struct ExportOptions {
    let scale: Double
    let format: ExportPreviewView.ExportFormat
    let transparent: Bool
}
