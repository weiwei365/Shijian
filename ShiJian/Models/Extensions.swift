import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }

    func toHex() -> String {
        guard let c = NSColor(self).usingColorSpace(.deviceRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}
