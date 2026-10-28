export type Block = {
  id: number
  /** 0 = Monday … 6 = Sunday. */
  day: number
  /** Half-hour slots from H_START; `end` is exclusive. */
  start: number
  end: number
  label: string
  color: string
}

export type Schedule = {
  blocks: Block[]
  nextId: number
  /** Color used for new blocks. */
  selColor: string
  /** First hour of the grid when this was saved, so times survive changes. */
  hStart: number
}

export const STORAGE_KEY = "schedule_v2"
export const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
export const DAY_NAMES = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
]
/** Date.getDay() for each column (Monday first). */
export const DAY_TO_WEEKDAY = [1, 2, 3, 4, 5, 6, 0]
export const H_START = 6
export const H_END = 24
export const SLOT_COUNT = (H_END - H_START) * 2
/** Pixel height of one half-hour slot; tall enough for a label and a time. */
export const SLOT_HEIGHT = 48

export const COLORS = [
  { value: "#e8c323", name: "Yellow" },
  { value: "#5aab3f", name: "Green" },
  { value: "#378ADD", name: "Blue" },
  { value: "#E24B4A", name: "Red" },
  { value: "#7F77DD", name: "Purple" },
  { value: "#f07830", name: "Orange" },
  { value: "#e91e8c", name: "Pink" },
  { value: "#888780", name: "Gray" },
  { value: "#1abc9c", name: "Teal" },
  { value: "#c0392b", name: "Crimson" },
  { value: "#2980b9", name: "Ocean" },
  { value: "#8e44ad", name: "Violet" },
]
export const DEFAULT_COLOR = COLORS[1].value

export function emptySchedule(): Schedule {
  return { blocks: [], nextId: 1, selColor: DEFAULT_COLOR, hStart: H_START }
}

/** "6:00 AM" for slot 0; the last slot ends at "12:00 AM" (midnight). */
export function slotLabel(slot: number) {
  const minutes = H_START * 60 + slot * 30
  const h = Math.floor(minutes / 60) % 24
  const m = minutes % 60
  return `${h % 12 || 12}:${String(m).padStart(2, "0")} ${h >= 12 ? "PM" : "AM"}`
}

export function clampSlot(slot: number) {
  return Math.max(0, Math.min(SLOT_COUNT - 1, slot))
}

/**
 * The changed block owns its time range. Other blocks on that day keep only
 * their uncovered parts, including both sides of a block it lands inside.
 */
export function resolveOverlaps(
  blocks: Block[],
  active: Block,
  nextId: number
) {
  let next = nextId
  const resolved = blocks.flatMap((block) => {
    if (
      block.id === active.id ||
      block.day !== active.day ||
      block.end <= active.start ||
      block.start >= active.end
    ) {
      return [block]
    }
    const remaining: Block[] = []
    if (block.start < active.start) {
      remaining.push({ ...block, end: active.start })
    }
    if (block.end > active.end) {
      remaining.push({
        ...block,
        id: remaining.length ? next++ : block.id,
        start: active.end,
      })
    }
    return remaining
  })
  return { blocks: resolved, nextId: next }
}

/** Adds or replaces `block`, then trims whatever it now covers. */
export function placeBlock(blocks: Block[], block: Block, nextId: number) {
  const exists = blocks.some((b) => b.id === block.id)
  const updated = exists
    ? blocks.map((b) => (b.id === block.id ? block : b))
    : [...blocks, block]
  return resolveOverlaps(updated, block, nextId)
}

/**
 * Reads a saved schedule. Times saved with a different start hour are shifted
 * to keep their wall-clock time, and overlaps saved by older versions are
 * repaired in paint order so the block that was shown on top keeps its range.
 */
export function reviveSchedule(raw: unknown): Schedule | null {
  if (!raw || typeof raw !== "object") return null
  const data = raw as Partial<Schedule>
  let blocks = (Array.isArray(data.blocks) ? data.blocks : []).map((b) => ({
    ...b,
  }))
  let nextId = data.nextId || 1
  const savedHStart = data.hStart ?? 6

  if (savedHStart !== H_START) {
    const shift = (savedHStart - H_START) * 2
    blocks = blocks
      .map((b) => ({ ...b, start: b.start + shift, end: b.end + shift }))
      .filter((b) => b.end > 0 && b.start < SLOT_COUNT)
      .map((b) => ({
        ...b,
        start: Math.max(0, b.start),
        end: Math.min(SLOT_COUNT, b.end),
      }))
  }

  for (const b of blocks) nextId = Math.max(nextId, b.id + 1)
  let repaired: Block[] = []
  for (const block of blocks) {
    ;({ blocks: repaired, nextId } = resolveOverlaps(
      [...repaired, block],
      block,
      nextId
    ))
  }

  return {
    blocks: repaired,
    nextId,
    selColor: data.selColor || DEFAULT_COLOR,
    hStart: H_START,
  }
}
