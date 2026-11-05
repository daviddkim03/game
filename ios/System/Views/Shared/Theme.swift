import SwiftUI
import SystemCore

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

    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)
    static let positive = Color(red: 0.0, green: 0.6, blue: 0.4)
}

extension CivilDate {
    /// Formats with a template such as "EEEE, MMMM d".
    func formatted(_ template: String) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date())
    }
}

/// A rounded surface on the grouped background.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

/// A number typed with the decimal keyboard. It updates on every keystroke, so
/// tapping Save right after typing can't save the old value the way a
/// formatted `TextField` does. Empty means nil.
struct DecimalField: View {
    let placeholder: String
    @Binding var value: Double?
    @State private var text = ""

    init(_ placeholder: String = "0", value: Binding<Double?>) {
        self.placeholder = placeholder
        _value = value
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .onAppear {
                text = value.map(Self.plain) ?? ""
            }
            .onChange(of: text) { _, new in
                value = Double(new.replacingOccurrences(of: ",", with: ""))
            }
            .onChange(of: value) { _, new in
                if Double(text.replacingOccurrences(of: ",", with: "")) != new {
                    text = new.map(Self.plain) ?? ""
                }
            }
    }

    /// "12.5" or "900", never "900.0".
    private static func plain(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(number)
    }
}

/// A labeled number row in a form.
struct NumberField: View {
    let title: String
    @Binding var value: Double?

    var body: some View {
        LabeledContent(title) {
            DecimalField(value: $value)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Moves between months with chevrons.
struct MonthSwitcher: View {
    @Binding var month: CivilDate

    var body: some View {
        HStack {
            Button {
                month = month.adding(months: -1)
            } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted("MMMM yyyy"))
                .font(.headline)
                .accessibilityIdentifier("month.title")
            Spacer()
            Button {
                month = month.adding(months: 1)
            } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
            .accessibilityLabel("Next month")
        }
    }
}
