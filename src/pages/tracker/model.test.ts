import { produce } from "immer"
import { describe, expect, it } from "vitest"

import * as actions from "@/pages/tracker/actions"
import { buildCalendarMonth, type CalendarPill } from "@/pages/tracker/calendar"
import {
  defaultTracker,
  monthlyCost,
  projectBalances,
  reviveTracker,
  safeHref,
  summarize,
  waterfallAllocate,
  type TrackerData,
} from "@/pages/tracker/model"

const ALL = { paydays: true, bills: true, savings: true }
const OCTOBER_2026 = [2026, 9] as const

function withBuckets(data: TrackerData, current: number[]) {
  return produce(data, (d) => {
    d.savingsBuckets.forEach((bucket, i) => (bucket.current = current[i] ?? 0))
  })
}

describe("summarize", () => {
  it("matches the numbers the tracker showed for the default data", () => {
    const s = summarize(defaultTracker())
    expect(s.gross).toBe(6920)
    expect(s.taxed).toBe(6280)
    expect(s.untaxed).toBe(640)
    expect(s.earn).toBe(5350)
    expect(s.expenses).toBe(1992)
    expect(s.game).toBe(3358)
    expect(s.annualGross).toBe(83040)
    expect(s.afterTax).toBe(64200)
    expect(s.pureSavings).toBe(40296)
    expect(s.checkingGoal).toBe(3984)
    expect(s.emergencyGoal).toBe(11952)
    expect(s.byCategory).toEqual({
      Loans: 628,
      Necessities: 1085,
      Luxury: 71,
      Fuckery: 208,
    })
  })

  it("counts a salaried source's bonus in annual figures only", () => {
    const data = produce(defaultTracker(), (d) => {
      d.income[0].rate = 6000
    })
    const s = summarize(data)
    expect(s.game).toBe(3358)
    expect(s.annualBonus).toBe(6000)
    expect(s.annualBonusNet).toBe(4500)
    expect(s.annualGross).toBe(83040 + 6000)
  })

  it("ignores uncategorized expenses until they get a category", () => {
    const data = produce(defaultTracker(), (d) => actions.addExpense(d))
    const s = summarize(
      produce(data, (d) => actions.updateExpense(d, 20, { cost: 500 }))
    )
    expect(s.expenses).toBe(1992)
  })

  it("prices weekday expenses per occurrence", () => {
    const data = produce(defaultTracker(), (d) =>
      actions.updateExpense(d, 9, {
        dueType: "weekdays",
        dueWeekdays: [1, 3, 5],
        cost: 10,
      })
    )
    expect(monthlyCost(data.expenses[8])).toBeCloseTo(10 * 3 * (52 / 12))
  })
})

describe("savings waterfall", () => {
  const buckets = defaultTracker().savingsBuckets

  it("fills buckets in order and overflows into the last one", () => {
    expect(waterfallAllocate(1500, { 1: 3000 }, buckets)).toEqual({
      1: 1000,
      2: 500,
    })
    expect(waterfallAllocate(5000, { 1: 4000, 2: 12000 }, buckets)).toEqual({
      3: 5000,
    })
  })

  it("projects balances month by month", () => {
    const after = projectBalances(12, 1500, { 1: 2500, 2: 0, 3: 0 }, buckets)
    expect(after).toEqual({ 1: 4000, 2: 12000, 3: 4500 })
  })
})

describe("calendar", () => {
  it("places default paydays and bills like the original calendar", () => {
    const month = buildCalendarMonth(defaultTracker(), ...OCTOBER_2026, ALL, {})
    const labels = (day: number) => (month.pills[day] ?? []).map((p) => p.label)
    expect(month.firstWeekday).toBe(4)
    expect(labels(1)).toEqual(["Young", "Rent"])
    expect(labels(2)).toEqual(["Auto Ins", "Health"])
    expect(labels(3)).toEqual(["Student"])
    expect(labels(16)).toEqual(["Young"])
    // The 31st is a Saturday; there is no Monday left in the month to move to.
    expect(labels(31)).toEqual(["Steven"])
    expect(month.runningNet[1]).toBe(1175)
    expect(month.runningNet[31]).toBe(3382)
  })

  it("moves weekend paydays to Monday and routes savings by date", () => {
    const data = produce(withBuckets(defaultTracker(), [3500]), (d) => {
      d.income[0].paydayDates = [17] // Saturday, October 17
      actions.addContribution(d)
      actions.updateContribution(d, 20, { name: "Save", amount: 1000, due: 18 })
    })
    const month = buildCalendarMonth(data, ...OCTOBER_2026, ALL, {
      1: 3500,
      2: 0,
      3: 0,
    })
    const young = month.pills[19].find((p) => p.label === "Young")!
    expect(young).toMatchObject({
      shifted: true,
      shiftLabel: "17th",
      fromDay: 17,
    })
    const save = month.pills[19].find((p) => p.kind === "sav")!
    expect(save.destination).toBe("Checking $500 + Emergency $500")
  })

  it("hides filtered pill types but keeps the running net", () => {
    const month = buildCalendarMonth(
      defaultTracker(),
      ...OCTOBER_2026,
      { paydays: false, bills: true, savings: true },
      {}
    )
    expect(month.pills[16]).toBeUndefined()
    expect(month.runningNet[31]).toBe(3382)
  })
})

describe("actions", () => {
  const pill = (overrides: Partial<CalendarPill>): CalendarPill => ({
    key: "k",
    kind: "bill",
    label: "",
    color: "",
    amount: 0,
    refId: 1,
    fromDay: 1,
    isWeekday: false,
    shifted: false,
    shiftLabel: null,
    ...overrides,
  })

  it("moves a dragged payday to the dropped date", () => {
    const data = produce(defaultTracker(), (d) =>
      actions.movePill(
        d,
        pill({ kind: "pay", refId: 1, fromDay: 16 }),
        new Date(2026, 9, 20)
      )
    )
    expect(data.income[0].paydayDates).toEqual([1, 20])
  })

  it("moves a weekday bill to the dropped weekday", () => {
    const base = produce(defaultTracker(), (d) =>
      actions.updateExpense(d, 9, { dueType: "weekdays", dueWeekdays: [1, 3] })
    )
    const data = produce(base, (d) =>
      actions.movePill(
        d,
        pill({ refId: 9, fromDay: 1, isWeekday: true }),
        new Date(2026, 9, 9)
      )
    )
    expect(data.expenses[8].dueWeekdays).toEqual([3, 5])
  })

  it("takes the target's group when a row is dropped on another row", () => {
    const data = produce(defaultTracker(), (d) =>
      actions.moveExpenseBefore(d, 1, 5)
    )
    const rent = data.expenses.find((e) => e.id === 1)!
    expect(rent.cat).toBe("Loans")
    expect(data.expenses.map((e) => e.id).slice(0, 5)).toEqual([2, 3, 4, 1, 5])
  })

  it("sends a deleted income type's sources to Other", () => {
    const data = produce(defaultTracker(), (d) =>
      actions.deleteIncomeType(d, "Work")
    )
    expect(data.incomeTypes).toEqual(["Business", "Side", "Other"])
    expect(data.income.filter((s) => s.incomeType === "Other")).toHaveLength(3)
  })
})

describe("reviveTracker", () => {
  it("upgrades data saved by the first versions", () => {
    const legacy = {
      taxRate: 0.3,
      income: [
        {
          id: 1,
          name: "Job",
          type: "Taxed",
          monthly: 4000,
          rate: null,
          payday: "1st & 15th",
          guar: true,
        },
        {
          id: 2,
          name: "Gig",
          type: "Untaxed",
          monthly: null,
          rate: 30,
          hrsPerWeek: 0,
        },
      ],
      expenses: [
        { id: 3, name: "Rent", cat: "Necessities", cost: 900, due: 1 },
      ],
      nextId: 4,
      tabOrder: ["dashboard", "income", "expenses", "calendar"],
    }
    const data = reviveTracker(legacy)!
    expect(data.income[0]).toMatchObject({
      paydayType: "dates",
      paydayDates: [1, 15],
      payType: "Salary",
      incomeType: "Other",
      showOnCal: true,
    })
    expect(data.income[0]).not.toHaveProperty("guar")
    expect(data.income[1]).toMatchObject({
      payType: "Hourly",
      hrsPerWeek: null,
    })
    expect(data.expenses[0]).toMatchObject({
      dueType: "dates",
      dueWeekdays: [],
      showOnCal: true,
    })
    expect(data.incomeTypes).toEqual(["Work", "Business", "Side", "Other"])
    expect(data.savingsBuckets).toHaveLength(3)
    expect(data.savingsContribs).toEqual([])
    expect(data.tabOrder).toEqual([
      "dashboard",
      "income",
      "expenses",
      "savings",
      "calendar",
    ])
    expect(data.taxRate).toBe(0.3)
  })

  it("does not change current data", () => {
    const current = defaultTracker()
    expect(reviveTracker(structuredClone(current))).toEqual(current)
  })

  it("rejects data that is not an object", () => {
    expect(reviveTracker(null)).toBeNull()
    expect(reviveTracker("oops")).toBeNull()
  })
})

describe("safeHref", () => {
  it("allows web and mail links and adds https to bare domains", () => {
    expect(safeHref("https://pay.example.com")).toBe("https://pay.example.com")
    expect(safeHref("mailto:billing@example.com")).toBe(
      "mailto:billing@example.com"
    )
    expect(safeHref("pay.example.com/bill")).toBe(
      "https://pay.example.com/bill"
    )
    expect(safeHref("javascript:alert(1)")).toBeNull()
    expect(safeHref("")).toBeNull()
  })
})
