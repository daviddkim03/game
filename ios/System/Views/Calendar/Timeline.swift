import SwiftUI
import SystemCore

/// Measurements shared by the day and week timelines.
enum Timeline {
    static let hourHeight: CGFloat = 56
    static let inset: CGFloat = 12
    static let gutter: CGFloat = 46
    static let hours = ScheduleGrid.lastHour - ScheduleGrid.firstHour
    static let height = CGFloat(hours) * hourHeight + inset * 2
    /// Enough days or weeks to swipe through in either direction.
    static let pageRange = -520...520

    static func y(_ minute: Int) -> CGFloat {
        CGFloat(minute - ScheduleGrid.firstHour * 60) / 60 * hourHeight + inset
    }

    /// The half-hour slot at a tapped height.
    static func slot(atY y: CGFloat) -> Int {
        max(0, min(ScheduleGrid.slotCount - 1, Int((y - inset) / (hourHeight / 2))))
    }

    static func hourLabel(_ index: Int) -> String {
        let hour = (ScheduleGrid.firstHour + index) % 24
        return "\(hour % 12 == 0 ? 12 : hour % 12) \(hour >= 12 ? "PM" : "AM")"
    }
}

/// A vertical timeline whose content swipes sideways, so every page stays at
/// the same time of day.
struct TimelinePager<Page: View>: View {
    @Binding var page: Int?
    /// Puts the current time in the gutter, for pages that show today.
    var showsNow = false
    @ViewBuilder let content: (Int) -> Page

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    HourGutter(showsNow: showsNow)
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(Timeline.pageRange, id: \.self) { index in
                                content(index)
                                    .containerRelativeFrame(.horizontal)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $page)
                    .scrollIndicators(.hidden)
                }
                .frame(height: Timeline.height)
                .background(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .offset(y: Timeline.y(CivilDate.minuteOfDay(AppClock.now)))
                        .id("now")
                }
            }
            .onAppear {
                proxy.scrollTo("now", anchor: .center)
            }
        }
    }
}

struct HourGutter: View {
    var showsNow = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0...Timeline.hours, id: \.self) { index in
                Text(Timeline.hourLabel(index))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .padding(.trailing, 6)
                    .offset(y: Timeline.y(ScheduleGrid.firstHour * 60 + index * 60) - 7)
            }
            if showsNow {
                TimelineView(.everyMinute) { _ in
                    let minute = CivilDate.minuteOfDay(AppClock.now)
                    if minute >= ScheduleGrid.firstHour * 60 {
                        // Covers any hour label it lands on, like Apple's Calendar.
                        Text(String(clockLabel(minute).dropLast(3)))
                            .font(.system(size: 10.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                            .padding(.trailing, 6)
                            .frame(width: Timeline.gutter, height: 16, alignment: .trailing)
                            .background(Color(.systemBackground))
                            .offset(y: Timeline.y(minute) - 8)
                    }
                }
            }
        }
        .frame(width: Timeline.gutter, height: Timeline.height, alignment: .topTrailing)
        .accessibilityHidden(true)
    }
}

struct HourLines: View {
    var body: some View {
        Canvas { context, size in
            var hours = Path()
            for index in 0...Timeline.hours {
                let y = Timeline.y(ScheduleGrid.firstHour * 60 + index * 60)
                hours.move(to: CGPoint(x: 0, y: y))
                hours.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(hours, with: .color(Color(.separator)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// The red line at the current time.
struct NowLine: View {
    /// Keeps the dot inside a column that clips at its left edge.
    var dotOffset: CGFloat = -3

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let minute = CivilDate.minuteOfDay(AppClock.now)
            if minute >= ScheduleGrid.firstHour * 60 {
                Rectangle()
                    .fill(.red)
                    .frame(height: 1.5)
                    .overlay(alignment: .leading) {
                        Circle()
                            .fill(.red)
                            .frame(width: 9, height: 9)
                            .offset(x: dotOffset)
                    }
                    .offset(y: Timeline.y(minute) - 0.75)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("calendar.nowLine")
            }
        }
    }
}

/// One day's blocks on the timeline.
struct DayColumn: View {
    @Environment(AppModel.self) private var model
    let date: CivilDate
    var isCompact = false
    let onOpen: (BlockRef) -> Void
    let onAdd: (CivilDate, Int) -> Void

    var body: some View {
        let plan = model.plan(for: date)
        ZStack(alignment: .topLeading) {
            HourLines()
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    onAdd(date, Timeline.slot(atY: location.y))
                }
            ForEach(plan.skipped) { block in
                tile(block, isSkipped: true)
            }
            ForEach(plan.blocks) { block in
                tile(block, isSkipped: false)
            }
            if date == model.today {
                NowLine(dotOffset: isCompact ? -3 : 0)
            }
        }
        .frame(height: Timeline.height)
    }

    private func tile(_ block: PlannedBlock, isSkipped: Bool) -> some View {
        Button {
            onOpen(BlockRef(date: date, blockId: block.id))
        } label: {
            TimelineTile(block: block, isCompact: isCompact, isSkipped: isSkipped)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isCompact ? 1 : 3)
        .offset(y: Timeline.y(block.start) + 1)
        .accessibilityIdentifier("tile.\(date.key).\(block.label)")
    }
}

struct TimelineTile: View {
    let block: PlannedBlock
    let isCompact: Bool
    let isSkipped: Bool

    private var height: CGFloat {
        max(16, Timeline.y(block.end) - Timeline.y(block.start) - 2)
    }

    var body: some View {
        let color = Color(hex: block.color)
        Group {
            if isCompact {
                compact
            } else {
                wide
            }
        }
        .foregroundStyle(isSkipped ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .padding(.leading, isCompact ? 5 : 9)
        .padding(.trailing, isCompact ? 1 : 6)
        .padding(.vertical, height < 34 ? 1 : 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height, alignment: .topLeading)
        .background(isSkipped ? color.opacity(0.06) : color.opacity(0.24))
        .overlay(alignment: .leading) {
            color.opacity(isSkipped ? 0.4 : 1).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var wide: some View {
        if height < 44 {
            HStack(spacing: 6) {
                label(.subheadline.weight(.semibold))
                Text(clockLabel(block.start))
                    .font(.caption)
                    .opacity(0.75)
            }
            .lineLimit(1)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                label(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(block.timeLabel)
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var compact: some View {
        VStack(alignment: .leading, spacing: 1) {
            label(.system(size: 10.5, weight: .semibold))
                .lineLimit(height < 40 ? 1 : 3)
                .minimumScaleFactor(0.75)
            if height >= 62 {
                Text(shortClock(block.start))
                    .font(.system(size: 9))
                    .opacity(0.75)
                Text(shortClock(block.end))
                    .font(.system(size: 9))
                    .opacity(0.75)
            }
        }
    }

    private func label(_ font: Font) -> some View {
        Text(block.label)
            .font(font)
            .strikethrough(isSkipped)
    }

    /// "8:30" without AM or PM, for narrow columns.
    private func shortClock(_ minute: Int) -> String {
        String(clockLabel(minute).dropLast(3))
    }
}
