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

  it("never shows the same quote twice in a row", () => {
    let previous = pickQuote()
    for (let i = 0; i < 200; i++) {
      const next = pickQuote()
      expect(next).not.toBe(previous)
      previous = next
    }
  })

  it("can pick every quote, including the first and last", () => {
    expect(pickQuote(() => 0)).toBe(QUOTES[0])
    expect(pickQuote(() => 0.9999)).toBe(QUOTES.at(-1))
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
