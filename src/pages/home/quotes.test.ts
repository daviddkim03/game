import { beforeEach, describe, expect, it, vi } from "vitest"

import { pickQuote, QUOTES } from "@/pages/home/quotes"

describe("pickQuote", () => {
  beforeEach(() => {
    const store = new Map<string, string>()
    vi.stubGlobal("localStorage", {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => store.set(key, value),
    })
  })

  it("shows every quote once before repeating any", () => {
    for (let round = 0; round < 3; round++) {
      const seen = new Set(QUOTES.map(() => pickQuote()))
      expect(seen.size).toBe(QUOTES.length)
    }
  })

  it("never shows the same quote twice in a row, even between rounds", () => {
    let previous = pickQuote()
    for (let i = 0; i < QUOTES.length * 5; i++) {
      const next = pickQuote()
      expect(next).not.toBe(previous)
      previous = next
    }
  })

  it("starts over when the quote list has changed", () => {
    localStorage.setItem(
      "home:quote-deck",
      JSON.stringify({ size: 3, order: [999], last: 0 })
    )
    expect(QUOTES).toContain(pickQuote())
  })

  it("still works when storage is blocked", () => {
    vi.stubGlobal("localStorage", {
      getItem: () => {
        throw new Error("blocked")
      },
      setItem: () => {
        throw new Error("blocked")
      },
    })
    expect(QUOTES).toContain(pickQuote())
  })
})
