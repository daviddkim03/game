import Foundation

public struct Block: Identifiable, Hashable, Sendable {
    public var id: Int
    /// 0 = Monday ... 6 = Sunday.
    public var day: Int
    /// Half-hour slots from `ScheduleGrid.firstHour`; `end` is exclusive.
    public var start: Int
    public var end: Int
    public var label: String
    public var color: String

    public init(id: Int, day: Int, start: Int, end: Int, label: String, color: String) {
        self.id = id
        self.day = day
        self.start = start
        self.end = end
        self.label = label
        self.color = color
    }

    public var startMinutes: Int { ScheduleGrid.minutes(slot: start) }
    public var endMinutes: Int { ScheduleGrid.minutes(slot: end) }
}

public enum ScheduleGrid {
    public static let firstHour = 6
    public static let lastHour = 24
    public static let slotCount = (lastHour - firstHour) * 2
    public static let dayNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    ]
    public static let shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    public static let defaultColor = "#5aab3f"
    public static let colors: [(value: String, name: String)] = [
        ("#e8c323", "Yellow"), ("#5aab3f", "Green"), ("#378ADD", "Blue"), ("#E24B4A", "Red"),
        ("#7F77DD", "Purple"), ("#f07830", "Orange"), ("#e91e8c", "Pink"), ("#888780", "Gray"),
        ("#1abc9c", "Teal"), ("#c0392b", "Crimson"), ("#2980b9", "Ocean"), ("#8e44ad", "Violet"),
    ]

    public static func minutes(slot: Int) -> Int {
        firstHour * 60 + slot * 30
    }

    /// "6:00 AM" for slot 0; the last slot ends at "12:00 AM" (midnight).
    public static func slotLabel(_ slot: Int) -> String {
        clockLabel(minutes(slot: slot))
    }
}

/// "6:00 AM" for 360 minutes past midnight.
public func clockLabel(_ minutes: Int) -> String {
    let hour = (minutes / 60) % 24
    let minute = minutes % 60
    return "\(hour % 12 == 0 ? 12 : hour % 12):\(String(format: "%02d", minute)) \(hour >= 12 ? "PM" : "AM")"
}

/// The changed block owns its time range. Other blocks on that day keep only
/// their uncovered parts, including both sides of a block it lands inside.
public func resolveOverlaps(
    _ blocks: [Block],
    active: Block,
    nextId: Int
) -> (blocks: [Block], nextId: Int) {
    var next = nextId
    var resolved: [Block] = []
    for block in blocks {
        if block.id == active.id || block.day != active.day || block.end <= active.start
            || block.start >= active.end
        {
            resolved.append(block)
            continue
        }
        var remaining: [Block] = []
        if block.start < active.start {
            var before = block
            before.end = active.start
            remaining.append(before)
        }
        if block.end > active.end {
            var after = block
            if !remaining.isEmpty {
                after.id = next
                next += 1
            }
            after.start = active.end
            remaining.append(after)
        }
        resolved += remaining
    }
    return (resolved, next)
}

/// Adds or replaces `block`, then trims whatever it now covers.
public func placeBlock(
    _ blocks: [Block],
    block: Block,
    nextId: Int
) -> (blocks: [Block], nextId: Int) {
    let exists = blocks.contains { $0.id == block.id }
    let updated = exists ? blocks.map { $0.id == block.id ? block : $0 } : blocks + [block]
    return resolveOverlaps(updated, active: block, nextId: nextId)
}

public struct Schedule: CloudValue {
    public var blocks: [Block]
    public var nextId: Int
    /// Color used for new blocks.
    public var selColor: String
    /// First hour of the grid when this was saved, so times survive changes.
    public var hStart: Int

    public static let empty = Schedule(
        blocks: [], nextId: 1, selColor: ScheduleGrid.defaultColor, hStart: ScheduleGrid.firstHour)

    public init(blocks: [Block], nextId: Int, selColor: String, hStart: Int) {
        self.blocks = blocks
        self.nextId = nextId
        self.selColor = selColor
        self.hStart = hStart
    }

    /// Times saved with a different start hour are shifted to keep their
    /// wall-clock time, and overlaps saved by older versions are repaired in
    /// paint order so the block that was shown on top keeps its range.
    public init?(json: JSONValue) {
        guard case .object = json else { return nil }
        var blocks: [Block] = (json["blocks"]?.arrayValue ?? []).compactMap { item in
            guard let id = item["id"]?.intValue,
                let day = item["day"]?.intValue,
                let start = item["start"]?.intValue,
                let end = item["end"]?.intValue
            else { return nil }
            return Block(
                id: id,
                day: day,
                start: start,
                end: end,
                label: item["label"]?.stringValue ?? "Block",
                color: item["color"]?.stringValue ?? ScheduleGrid.defaultColor)
        }
        var nextId = json["nextId"]?.intValue ?? 1
        if nextId == 0 { nextId = 1 }
        let savedStart = json["hStart"]?.intValue ?? ScheduleGrid.firstHour

        if savedStart != ScheduleGrid.firstHour {
            let shift = (savedStart - ScheduleGrid.firstHour) * 2
            blocks =
                blocks
                .map { block in
                    var moved = block
                    moved.start += shift
                    moved.end += shift
                    return moved
                }
                .filter { $0.end > 0 && $0.start < ScheduleGrid.slotCount }
                .map { block in
                    var clipped = block
                    clipped.start = max(0, block.start)
                    clipped.end = min(ScheduleGrid.slotCount, block.end)
                    return clipped
                }
        }

        for block in blocks { nextId = max(nextId, block.id + 1) }
        var repaired: [Block] = []
        for block in blocks {
            (repaired, nextId) = resolveOverlaps(repaired + [block], active: block, nextId: nextId)
        }

        let color = json["selColor"]?.stringValue ?? ""
        self.init(
            blocks: repaired,
            nextId: nextId,
            selColor: color.isEmpty ? ScheduleGrid.defaultColor : color,
            hStart: ScheduleGrid.firstHour)
    }

    public func toJSON() -> JSONValue {
        [
            "blocks": .array(
                blocks.map { block in
                    [
                        "id": .number(Double(block.id)),
                        "day": .number(Double(block.day)),
                        "start": .number(Double(block.start)),
                        "end": .number(Double(block.end)),
                        "label": .string(block.label),
                        "color": .string(block.color),
                    ]
                }),
            "nextId": .number(Double(nextId)),
            "selColor": .string(selColor),
            "hStart": .number(Double(hStart)),
        ]
    }

    /// Adds a new block or saves changes to an existing one.
    public mutating func save(_ block: Block) {
        var placed = block
        let isNew = block.id == 0
        if isNew { placed.id = nextId }
        let result = placeBlock(blocks, block: placed, nextId: isNew ? nextId + 1 : nextId)
        blocks = result.blocks
        nextId = result.nextId
        selColor = block.color
    }

    public mutating func delete(_ id: Int) {
        blocks.removeAll { $0.id == id }
    }
}
