import Charts
import SwiftUI
import SystemCore

struct OverviewPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let data = model.tracker.value
        let summary = summarize(data)
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    Kpi(
                        title: "Monthly gross", value: summary.gross,
                        note: "Taxed \(formatUSD(summary.taxed)) · Untaxed \(formatUSD(summary.untaxed))")
                    Kpi(
                        title: "Take-home", value: summary.earn,
                        note: "After \(Int((data.taxRate * 100).rounded()))% tax on taxed income")
                    Kpi(
                        title: "Monthly expenses", value: summary.expenses,
                        note: "\(summary.expenseCount) items")
                    Kpi(
                        title: "GAME", value: summary.game,
                        note: "\(summary.savingsRate)% of take-home saved",
                        tint: summary.game >= 0 ? .positive : .red)
                }
                SpendingCard(data: data)
                BreakdownCard(data: data, summary: summary)
                ComparisonCard(summary: summary)
                SavingsCard(summary: summary)
                AnnualCard(summary: summary)
                TaxCard()
            }
            .padding(12)
        }
        .refreshable { await model.refreshAll() }
        .overlay {
            if !model.tracker.isLoaded { ProgressView() }
        }
    }
}

private struct Kpi: View {
    let title: String
    let value: Double
    let note: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(formatUSD(value))
                .font(.title2.bold())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityIdentifier("kpi.\(title)")
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// This month's logged purchases against the spending budget.
private struct SpendingCard: View {
    @Environment(AppModel.self) private var model
    let data: TrackerData

    var body: some View {
        let spent = model.spending(for: model.today).value.total
        let plan = FlexiblePlan(data).total
        Card {
            Text("Spending this month")
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatUSD(spent))
                    .font(.title2.bold())
                    .accessibilityIdentifier("overview.spent")
                Text("of \(formatUSD(plan))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(spent, max(plan, 1)), total: max(plan, 1))
                .tint(spent > plan ? .red : .positive)
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
            slices.append(Slice(name: "GAME", value: summary.game, color: .positive))
        }
        return slices
    }

    var body: some View {
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

private struct ComparisonCard: View {
    let summary: TrackerSummary

    private var bars: [Slice] {
        [
            Slice(name: "Gross", value: summary.gross, color: Color(hex: "#888780")),
            Slice(name: "Take-home", value: summary.earn, color: Color(hex: "#378ADD")),
            Slice(name: "Expenses", value: summary.expenses, color: Color(hex: "#E24B4A")),
            Slice(name: "GAME", value: max(summary.game, 0), color: .positive),
        ]
    }

    var body: some View {
        Card {
            Text("Gross vs take-home vs GAME")
                .font(.headline)
            Chart(bars) { bar in
                BarMark(
                    x: .value("Name", bar.name),
                    y: .value("Amount", bar.value),
                    width: .ratio(0.7)
                )
                .cornerRadius(6)
                .foregroundStyle(bar.color)
                .annotation(position: .top) {
                    Text(formatUSD(bar.value))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 170)
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
