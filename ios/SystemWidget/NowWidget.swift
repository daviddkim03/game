import SwiftUI
import SystemCore
import WidgetKit

@main
struct SystemWidgets: WidgetBundle {
    var body: some Widget {
        NowWidget()
    }
}

struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Now", provider: NowProvider()) { entry in
            NowWidgetView(moment: entry.moment)
        }
        .configurationDisplayName("Now")
        .description("What you should be doing right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct NowEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has signed in and saved the schedule.
    let moment: WidgetMoment?
}

struct NowProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry {
        NowEntry(date: .now, moment: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowEntry) -> Void) {
        let moment = WidgetStore.shared.read()?.moment(at: .now)
        completion(NowEntry(date: .now, moment: moment ?? (context.isPreview ? Self.sample : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowEntry>) -> Void) {
        guard let snapshot = WidgetStore.shared.read() else {
            completion(Timeline(entries: [NowEntry(date: .now, moment: nil)], policy: .never))
            return
        }
        let entries = snapshot.moments(from: .now).map { NowEntry(date: $0.date, moment: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// What the widget gallery shows before there's a schedule to read.
    private static let sample: WidgetMoment = {
        let monday = CivilDate(year: 2026, month: 11, day: 2)
        let week = Schedule(
            blocks: [
                Block(id: 1, day: 0, start: 6, end: 14, label: "Focus", color: "#378ADD"),
                Block(id: 2, day: 0, start: 14, end: 16, label: "Gym", color: "#5aab3f"),
            ],
            nextId: 3,
            selColor: "#378ADD",
            hStart: 6)
        return WidgetSnapshot(schedule: week, days: [:]).moment(at: monday.date(minutes: 11 * 60))
    }()
}

struct NowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let moment: WidgetMoment?

    private var blockColor: String? {
        moment?.state.current?.color
    }

    /// Black or white on the block's color, like the Now screen. Tinted and
    /// clear home screens pick their own colors.
    private var foreground: Color {
        guard renderingMode == .fullColor, let blockColor else { return .primary }
        return .readable(on: blockColor)
    }

    var body: some View {
        content
            .foregroundStyle(foreground)
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular || family == .accessoryInline {
                    Color.clear
                } else if let blockColor {
                    Color(hex: blockColor)
                } else {
                    Color(.secondarySystemGroupedBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let moment {
            switch family {
            case .accessoryInline:
                Text(moment.inlineLine)
            case .accessoryRectangular:
                lockScreen(moment)
            case .systemMedium:
                HStack(alignment: .top, spacing: 16) {
                    now(moment)
                    later(moment)
                }
            default:
                now(moment)
            }
        } else {
            signedOut
        }
    }

    private func now(_ moment: WidgetMoment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Now")
                .font(.footnote.weight(.semibold))
                .opacity(0.8)
            Text(moment.title)
                .font(.system(size: 26, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(moment.subtitle)
                .font(.footnote.weight(.medium))
                .padding(.top, 1)
            Spacer(minLength: 6)
            if let range = moment.currentRange {
                ProgressView(timerInterval: range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(foreground)
            }
            if family == .systemSmall, let next = moment.nextLine {
                Text(next)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func later(_ moment: WidgetMoment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next")
                .font(.footnote.weight(.semibold))
                .opacity(0.8)
            if moment.upcoming.isEmpty {
                Text("Nothing else today")
                    .font(.footnote.weight(.medium))
            }
            ForEach(moment.upcoming.prefix(3)) { thing in
                VStack(alignment: .leading, spacing: 0) {
                    Text(thing.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    Text(clockLabel(thing.start))
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func lockScreen(_ moment: WidgetMoment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(moment.title)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            Text(moment.subtitle)
                .font(.caption)
            if let next = moment.nextLine {
                Text(next)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("System")
                .font(.headline)
            Text("Open the app to sign in")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
