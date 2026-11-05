import SwiftUI

/// Block colors, shared by the app and the widget.
extension Color {
    /// Reads "#5aab3f".
    init(hex: String) {
        let (red, green, blue) = Self.channels(hex)
        self.init(red: red, green: green, blue: blue)
    }

    /// Black or white, whichever stays readable on top of `hex`.
    static func readable(on hex: String) -> Color {
        let (red, green, blue) = channels(hex)
        let brightness = 0.299 * red + 0.587 * green + 0.114 * blue
        return brightness > 0.62 ? .black : .white
    }

    private static func channels(_ hex: String) -> (Double, Double, Double) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: ["#"])).scanHexInt64(&value)
        return (
            Double((value >> 16) & 255) / 255,
            Double((value >> 8) & 255) / 255,
            Double(value & 255) / 255
        )
    }
}
