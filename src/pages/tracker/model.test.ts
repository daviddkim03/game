import { produce } from "immer"
import { describe, expect, it } from "vitest"

import * as actions from "@/pages/tracker/actions"
import { buildCalendarMonth, type CalendarPill } from "@/pages/tracker/calendar"
import {
  emptyTracker,
  monthlyCost,
  reviveTracker,
  safeHref,
  summarize,
} from "@/pages/tracker/model"

import { sampleTracker } from "../../../tests/sample-data"

const ALL = { paydays: true, bills: true }
const OCTOBER_2026 = [2026, 9] as const

describe("summarize", () => {
  it("adds up income, expenses, and goals", () => {
    const s = summarize(sampleTracker())
    expect(s.gross).toBe(5440)
    expect(s.taxed).toBe(5240)
    expect(s.untaxed).toBe(200)
    expect(s.earn).toBe(4130)
    expect(s.expenses).toBe(1816)
    expect(s.game).toBe(2314)
    expect(s.annualGross).toBe(65280)
    expect(s.afterTax).toBe(49560)
    expect(s.pureSavings).toBe(27768)
    expect(s.checkingGoal).toBe(3632)
    expect(s.emergencyGoal).toBe(10896)
    expect(s.byCategory).toEqual({
      Debt: 360,
      Home: 1285,
      Fun: 59,
      Extras: 112,
    })
  })

  it("counts a salaried source's bonus in annual figures only", () => {
    const data = produce(sampleTracker(), (d) => {
      d.income[0].rate = 6000
    })
    const s = summarize(data)
    expect(s.game).toBe(2314)
    expect(s.annualBonus).toBe(6000)
    expect(s.annualBonusNet).toBe(4500)
    expect(s.annualGross).toBe(65280 + 6000)
  })

  it("ignores uncategorized expenses until they get a category", () => {
    const data = produce(sampleTracker(), (d) => actions.addExpense(d))
    const s = summarize(
      produce(data, (d) => actions.updateExpense(d, 20, { cost: 500 }))
    )
    expect(s.expenses).toBe(1816)
  })

  it("is all zeros for an empty budget", () => {
    const s = summarize(emptyTracker())
    expect(s.gross).toBe(0)
    expect(s.earn).toBe(0)
    expect(s.expenses).toBe(0)
    expect(s.game).toBe(0)
    expect(s.byCategory).toEqual({})
  })

  it("prices weekday expenses per occurrence", () => {
    const data = produce(sampleTracker(), (d) =>
      actions.updateExpense(d, 9, {
        dueType: "weekdays",
        dueWeekdays: [1, 3, 5],
        cost: 10,
      })
    )
    expect(monthlyCost(data.expenses[8])).toBeCloseTo(10 * 3 * (52 / 12))
  })
})

describe("calendar", () => {
  it("places paydays and bills on their days", () => {
    const month = buildCalendarMonth(sampleTracker(), ...OCTOBER_2026, ALL)
    const labels = (day: number) => (month.pills[day] ?? []).map((p) => p.label)
    expect(month.firstWeekday).toBe(4)
    expect(labels(1)).toEqual(["Northwind", "Rent"])
    expect(labels(2)).toEqual(["Insurance", "Dentist"])
    expect(labels(3)).toEqual(["Laptop"])
    expect(labels(16)).toEqual(["Northwind"])
    // The 31st is a Saturday; there is no Monday left in the month to move to.
    expect(labels(31)).toEqual(["Cafe"])
    expect(month.runningNet[1]).toBe(675)
    expect(month.runningNet[31]).toBe(2670)
  })

  it("moves weekend paydays to Monday", () => {
    const data = produce(sampleTracker(), (d) => {
      d.income[0].paydayDates = [17] // Saturday, October 17
    })
    const month = buildCalendarMonth(data, ...OCTOBER_2026, ALL)
    const payday = month.pills[19].find((p) => p.label === "Northwind")!
    expect(payday).toMatchObject({
      shifted: true,
      shiftLabel: "17th",
      fromDay: 17,
    })
  })

  it("hides filtered pill types but keeps the running net", () => {
    const month = buildCalendarMonth(sampleTracker(), ...OCTOBER_2026, {
      paydays: false,
      bills: true,
    })
    expect(month.pills[16]).toBeUndefined()
    expect(month.runningNet[31]).toBe(2670)
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
    const data = produce(sampleTracker(), (d) =>
      actions.movePill(
        d,
        pill({ kind: "pay", refId: 1, fromDay: 16 }),
        new Date(2026, 9, 20)
      )
    )
    expect(data.income[0].paydayDates).toEqual([1, 20])
  })

  it("moves a weekday bill to the dropped weekday", () => {
    const base = produce(sampleTracker(), (d) =>
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
    const data = produce(sampleTracker(), (d) =>
      actions.moveExpenseBefore(d, 1, 5)
    )
    const rent = data.expenses.find((e) => e.id === 1)!
    expect(rent.cat).toBe("Debt")
    expect(data.expenses.map((e) => e.id).slice(0, 5)).toEqual([2, 3, 4, 1, 5])
  })

  it("sends a deleted income type's sources to Other", () => {
    const data = produce(sampleTracker(), (d) =>
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
      expenses: [{ id: 3, name: "Rent", cat: "Home", cost: 900, due: 1 }],
      nextId: 4,
      tabOrder: ["dashboard", "income", "expenses", "calendar"],
      // The Savings tab's data, which is no longer used.
      savingsBuckets: [
        { id: 5, name: "Checking", target: 4000, current: 0, color: "#378ADD" },
      ],
      savingsContribs: [{ id: 6, name: "Save", amount: 500, due: 1 }],
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
    expect(data.incomeTypes).toEqual(["Other"])
    expect(data.categories).toEqual(["Home"])
    expect(data).not.toHaveProperty("savingsBuckets")
    expect(data).not.toHaveProperty("savingsContribs")
    expect(data.taxRate).toBe(0.3)
  })

  it("does not change current data", () => {
    const current = sampleTracker()
    expect(reviveTracker(structuredClone(current))).toEqual(current)
  })

  it("leaves missing parts empty", () => {
    expect(reviveTracker({})).toEqual(emptyTracker())
  })

  it("keeps uncategorized expenses out of the rebuilt category list", () => {
    const data = reviveTracker({
      expenses: [
        { id: 1, name: "Rent", cat: "Home", cost: 900 },
        { id: 2, name: "New", cat: "Uncategorized", cost: 0 },
        { id: 3, name: "Food", cat: "Home", cost: 300 },
      ],
    })!
    expect(data.categories).toEqual(["Home"])
  })

  it("does not reuse an id when the next one was never saved", () => {
    const data = reviveTracker({
      income: [{ id: 7, name: "Job" }],
      expenses: [{ id: 12, name: "Rent", cat: "Home", cost: 900 }],
    })!
    expect(data.nextId).toBe(13)
    expect(reviveTracker({ ...data, nextId: 40 })!.nextId).toBe(40)
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
