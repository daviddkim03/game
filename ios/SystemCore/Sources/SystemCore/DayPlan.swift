import Foundation

/// Today-only changes to one date. The weekly schedule itself stays untouched.
public struct DayOverride: Hashable, Sendable {
    /// Blocks skipped on this date.
    public var skipped: Set<Int> = []
    /// Extra minutes added to the end of each block.
    public var extraMinutes: [Int: Int] = [:]

    public init(skipped: Set<Int> = [], extraMinutes: [Int: Int] = [:]) {
        self.skipped = skipped
        self.extraMinutes = extraMinutes
    }

    public var isEmpty: Bool { skipped.isEmpty && extraMinutes.isEmpty }
}

/// A block as it actually happens on one date.
public struct PlannedBlock: Identifiable, Hashable, Sendable {
    /// The id of the weekly block this came from.
    public let id: Int
    public let label: String
    public let color: String
    /// Minutes past midnight.
    public let start: Int
    public let end: Int
    public let extraMinutes: Int
    /// True when another block's extension pushed the start back.
    public let wasPushed: Bool

    public var timeLabel: String { "\(clockLabel(start)) - \(clockLabel(end))" }
}

/// One or more touching blocks with the same label, which read as a single
/// thing to do. (Moving a block across another can leave one split in two.)
public struct Thing: Identifiable, Hashable, Sendable {
    public let blocks: [PlannedBlock]

    public init(blocks: [PlannedBlock]) {
        self.blocks = blocks
    }

    public var id: Int { blocks[0].id }
    public var label: String { blocks[0].label }
    public var color: String { blocks[0].color }
    public var start: Int { blocks[0].start }
    public var end: Int { blocks[blocks.count - 1].end }
    /// The block +15 min lengthens.
    public var lastBlockId: Int { blocks[blocks.count - 1].id }
    public var extraMinutes: Int { blocks.reduce(0) { $0 + $1.extraMinutes } }
    public var timeLabel: String { "\(clockLabel(start)) - \(clockLabel(end))" }
}

public struct DayPlan: Hashable, Sendable {
    public let date: CivilDate
    /// What is happening this date, earliest first.
    public let blocks: [PlannedBlock]
    /// Blocks skipped on this date, shown so they can be brought back.
    public let skipped: [PlannedBlock]

    public var things: [Thing] {
        var result: [[PlannedBlock]] = []
        for block in blocks {
            if let last = result.last?.last, last.end == block.start, last.label == block.label {
                result[result.count - 1].append(block)
            } else {
                result.append([block])
            }
        }
        return result.map(Thing.init)
    }

    public func now(at minute: Int) -> NowState {
        let things = things
        return NowState(
            minute: minute,
            current: things.first { $0.start <= minute && minute < $0.end },
            next: things.first { $0.start > minute },
            last: things.last { $0.end <= minute })
    }
}

/// What is going on at one minute of a day.
public struct NowState: Hashable, Sendable {
    public let minute: Int
    public let current: Thing?
    public let next: Thing?
    /// The most recent thing that already finished.
    public let last: Thing?

    public var minutesLeft: Int? {
        current.map { $0.end - minute }
    }

    /// How far through the current thing, from 0 to 1.
    public var progress: Double {
        guard let current, current.end > current.start else { return 0 }
        return Double(minute - current.start) / Double(current.end - current.start)
    }
}

/// "6h 31m", "6h", or "31m".
public func durationLabel(minutes: Int) -> String {
    let hours = minutes / 60
    let rest = minutes % 60
    if hours > 0 && rest > 0 { return "\(hours)h \(rest)m" }
    return hours > 0 ? "\(hours)h" : "\(rest)m"
}

/// Applies a date's changes to the weekly schedule. A lengthened block takes
/// time from whatever follows: the next block starts late but still ends on
/// time, and disappears for the day if nothing is left of it.
public func dayPlan(for date: CivilDate, schedule: Schedule, override: DayOverride?) -> DayPlan {
    let weekly =
        schedule.blocks
        .filter { $0.day == date.mondayIndex }
        .sorted { $0.start < $1.start }
    var active: [PlannedBlock] = []
    var skipped: [PlannedBlock] = []
    var covered = 0

    for block in weekly {
        let start = block.startMinutes
        let end = block.endMinutes
        if override?.skipped.contains(block.id) == true {
            skipped.append(
                PlannedBlock(
                    id: block.id, label: block.label, color: block.color, start: start, end: end,
                    extraMinutes: 0, wasPushed: false))
            continue
        }
        let extra = override?.extraMinutes[block.id] ?? 0
        let actualStart = max(start, covered)
        let actualEnd = min(end + extra, 24 * 60)
        guard actualStart < actualEnd else { continue }
        active.append(
            PlannedBlock(
                id: block.id, label: block.label, color: block.color, start: actualStart,
                end: actualEnd, extraMinutes: extra, wasPushed: actualStart > start))
        covered = max(covered, actualEnd)
    }
    return DayPlan(date: date, blocks: active, skipped: skipped)
}
