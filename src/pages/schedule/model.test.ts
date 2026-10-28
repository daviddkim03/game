import { describe, expect, it } from "vitest"

import {
  placeBlock,
  resolveOverlaps,
  reviveSchedule,
  slotLabel,
  type Block,
} from "@/pages/schedule/model"

const block = (id: number, day: number, start: number, end: number): Block => ({
  id,
  day,
  start,
  end,
  label: `Event ${id}`,
  color: "#5aab3f",
})

describe("slotLabel", () => {
  it("labels half-hour slots from 6 AM to midnight", () => {
    expect(slotLabel(0)).toBe("6:00 AM")
    expect(slotLabel(13)).toBe("12:30 PM")
    expect(slotLabel(36)).toBe("12:00 AM")
  })
})

describe("resolveOverlaps", () => {
  it("trims the parts of other blocks the active block covers", () => {
    const active = block(2, 0, 2, 4)
    const { blocks, nextId } = resolveOverlaps(
      [block(1, 0, 0, 8), active],
      active,
      3
    )
    expect(blocks).toEqual([
      { ...block(1, 0, 0, 8), end: 2 },
      { ...block(1, 0, 0, 8), id: 3, start: 4 },
      active,
    ])
    expect(nextId).toBe(4)
  })

  it("leaves other days and touching blocks alone", () => {
    const active = block(3, 0, 4, 6)
    const others = [block(1, 0, 2, 4), block(2, 1, 4, 6)]
    expect(resolveOverlaps([...others, active], active, 4).blocks).toEqual([
      ...others,
      active,
    ])
  })

  it("removes blocks that end up fully covered", () => {
    const active = block(1, 0, 0, 10)
    expect(placeBlock([block(2, 0, 2, 4)], active, 3).blocks).toEqual([active])
  })
})

describe("reviveSchedule", () => {
  it("repairs overlaps saved by older versions in paint order", () => {
    const repaired = reviveSchedule({
      blocks: [block(1, 0, 0, 12), block(2, 0, 4, 6), block(3, 0, 2, 8)],
      nextId: 4,
      hStart: 6,
    })!
    expect(repaired.blocks).toEqual([
      { ...block(1, 0, 0, 12), end: 2 },
      { ...block(1, 0, 0, 12), id: 4, start: 8 },
      block(3, 0, 2, 8),
    ])
    expect(repaired.nextId).toBe(5)
  })

  it("keeps wall-clock times when the grid used to start at another hour", () => {
    // Saved when the grid started at 8 AM: slot 0 was 8:00 AM.
    const revived = reviveSchedule({
      blocks: [block(1, 2, 0, 2)],
      nextId: 2,
      hStart: 8,
    })!
    expect(revived.blocks).toEqual([block(1, 2, 4, 6)])
    expect(revived.hStart).toBe(6)
  })

  it("fills in defaults", () => {
    expect(reviveSchedule({})).toEqual({
      blocks: [],
      nextId: 1,
      selColor: "#5aab3f",
      hStart: 6,
    })
    expect(reviveSchedule(null)).toBeNull()
  })
})
