import Charts
import SwiftUI
import SystemCore

struct OverviewPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let data = model.tracker.value
        let summary = summarize(data)
        ScrollView {
            if model.tracker.isLoaded {
                VStack(spacing: 12) {
                    TimelineView(.everyMinute) { _ in
                        PlayingWithCard(
                            data: data, summary: summary, progress: monthProgress(data, on: model.today))
                    }
                    BreakdownCard(data: data, summary: summary)
                    SavingsCard(summary: summary)
                    AnnualCard(summary: summary)
                    TaxCard()
                }
                .padding(12)
            }
        }
        .refreshable { await model.refreshAll() }
        .overlay {
            if !model.tracker.isLoaded { ProgressView() }
        }
    }
}

/// What's left to play with, how much of it has landed, and the math behind it.
private struct PlayingWithCard: View {
    let data: TrackerData
    let summary: TrackerSummary
    let progress: MonthProgress

    private var rows: [(id: String, label: String, value: Double)] {
        [
            ("overview.gross", "Gross pay", summary.gross),
            ("overview.taxes", "Taxes at \(formatNumber(data.taxRate * 100))%", summary.earn - summary.gross),
            ("overview.bills", "Bills", -summary.bills),
            ("overview.other", "Other expenses", -summary.otherExpenses),
        ]
    }

    private var landed: String {
        progress.toCover > 0
            ? "\(formatUSD(progress.toCover)) of expenses to cover"
            : "\(formatUSD(progress.soFar)) so far this month"
    }

    var body: some View {
        let shown = rows.filter { $0.value != 0 }
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Playing with")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatUSD(summary.game))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(summary.game >= 0 ? Color.positive : .red)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityIdentifier("overview.game")
                    Text("a month")
                        .foregroundStyle(.secondary)
                }
            }

            if summary.game > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: progress.soFar, total: summary.game)
                        .tint(.positive)
                    HStack {
                        Text(landed)
                            .accessibilityIdentifier("overview.soFar")
                        Spacer()
                        Text("\(formatUSD(progress.toCome)) to come")
                            .accessibilityIdentifier("overview.toCome")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            if !shown.isEmpty { Divider() }

            ForEach(shown, id: \.id) { row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatUSD(row.value))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .accessibilityIdentifier(row.id)
                }
                .font(.subheadline)
            }

            if summary.uncategorized > 0 {
                Text("\(formatUSD(summary.uncategorized)) with no category isn't counted")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("overview.uncategorized")
            }
        }
    }
}

private struct Slice: Identifiable {
    let name: String
    let value: Double
    let color: Color
    var id: String { name }
}

private struct BreakdownCard: View {
    let data: TrackerData
    let summary: TrackerSummary

    private var slices: [Slice] {
        var slices = data.categories.compactMap { category -> Slice? in
            guard let value = summary.byCategory[category], value > 0 else { return nil }
            return Slice(name: category, value: value, color: Color(hex: data.color(forCategory: category)))
        }
        if summary.game > 0 {
            slices.append(Slice(name: "Playing with", value: summary.game, color: .positive))
        }
        return slices
    }

    var body: some View {
        if !slices.isEmpty { card }
    }

    private var card: some View {
        Card {
            Text("Where your take-home goes")
                .font(.headline)
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.value),
                    innerRadius: .ratio(0.68),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(slice.color)
            }
            .frame(height: 190)
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Text(formatUSD(summary.earn))
                        .font(.title3.bold())
                    Text("take-home")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 9, height: 9)
                    Text(slice.name)
                        .font(.subheadline)
                    Spacer()
                    Text(formatUSD(slice.value))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }
}

private struct SavingsCard: View {
    let summary: TrackerSummary

    var body: some View {
        Card {
            Text("Savings goals")
                .font(.headline)
            Row(
                label: "Checking (2×)", value: formatUSD(summary.checkingGoal),
                note: summary.monthsToChecking.map { "\($0) months" })
            Divider()
            Row(
                label: "Emergency (6×)", value: formatUSD(summary.emergencyGoal),
                note: summary.monthsToEmergency.map { "\($0) months" })
        }
    }

    private struct Row: View {
        let label: String
        let value: String
        let note: String?

        var body: some View {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(value).fontWeight(.medium)
                    if let note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
    }
}

private struct AnnualCard: View {
    let summary: TrackerSummary

    var body: some View {
        let rows: [(String, Double)] = [
            ("Annual gross", summary.annualGross),
            ("Annual after-tax", summary.afterTax),
            ("Annual bonus (net)", summary.annualBonusNet),
            ("Pure savings", summary.pureSavings),
            ("Tax paid", summary.annualGross - summary.afterTax),
        ]
        Card {
            Text("Annual summary")
                .font(.headline)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatUSD(row.1))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
    }
}

private struct TaxCard: View {
    @Environment(AppModel.self) private var model
    @State private var percent: Double?

    var body: some View {
        Card {
            LabeledContent("Tax rate on taxed income") {
                HStack(spacing: 2) {
                    DecimalField("25", value: $percent)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .accessibilityIdentifier("overview.tax")
                    Text("%").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .onAppear {
            percent = (model.tracker.value.taxRate * 1000).rounded() / 10
        }
        .onChange(of: percent) { _, value in
            guard let value, abs(value / 100 - model.tracker.value.taxRate) > 0.0001 else { return }
            model.tracker.update { $0.setTaxPercent(value) }
        }
    }
}
