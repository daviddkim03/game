import type { Draft } from "immer"

import type { CalendarPill } from "@/pages/tracker/calendar"
import {
  COLOR_POOL,
  UNCATEGORIZED,
  type Contribution,
  type Expense,
  type IncomeSource,
  type SavingsBucket,
  type TrackerData,
} from "@/pages/tracker/model"

/*
 * Each action edits an immer draft of the tracker data. "add" actions use
 * `nextId`, so callers can read `data.nextId` beforehand to know the new id.
 */

type D = Draft<TrackerData>

function toggle(list: number[], value: number, sort = true) {
  const index = list.indexOf(value)
  if (index >= 0) list.splice(index, 1)
  else list.push(value)
  if (sort) list.sort((a, b) => a - b)
}

/** Moves `list[from]` so it sits right before the item now at `beforeIndex`. */
function moveBefore<T>(list: T[], item: T, before: T) {
  list.splice(list.indexOf(item), 1)
  list.splice(list.indexOf(before), 0, item)
}

function insertAfterLast<T>(list: T[], item: T, belongs: (x: T) => boolean) {
  const last = list.reduce((found, x, i) => (belongs(x) ? i : found), -1)
  list.splice(last + 1, 0, item)
}

function unusedColor(used: string[], fallbackIndex: number) {
  return (
    COLOR_POOL.find((color) => !used.includes(color)) ??
    COLOR_POOL[fallbackIndex % COLOR_POOL.length]
  )
}

export function setTaxRate(d: D, percent: number) {
  d.taxRate = Math.min(0.99, Math.max(0, percent / 100))
}

/* ── Income ──────────────────────────────────────────────────────────── */

export function updateSource(d: D, id: number, changes: Partial<IncomeSource>) {
  const source = d.income.find((s) => s.id === id)
  if (source) Object.assign(source, changes)
}

export function addSource(d: D, incomeType?: string) {
  const source: IncomeSource = {
    id: d.nextId++,
    name: "New Source",
    incomeType: incomeType || d.incomeTypes[0] || "Other",
    type: "Taxed",
    payType: "Salary",
    monthly: 0,
    rate: null,
    hrsPerWeek: null,
    paydayType: "dates",
    paydayDates: [],
    paydayWeekdays: [],
    weekendShift: "none",
    showOnCal: true,
  }
  if (!d.incomeTypes.includes(source.incomeType))
    d.incomeTypes.push(source.incomeType)
  d.income.push(source)
}

export function deleteSource(d: D, id: number) {
  d.income = d.income.filter((s) => s.id !== id)
}

export function toggleSourceOnCalendar(d: D, id: number) {
  const source = d.income.find((s) => s.id === id)
  if (source) source.showOnCal = source.showOnCal === false
}

export function togglePaydayDate(d: D, id: number, day: number) {
  const source = d.income.find((s) => s.id === id)
  if (source) toggle(source.paydayDates, day)
}

export function togglePaydayWeekday(d: D, id: number, weekday: number) {
  const source = d.income.find((s) => s.id === id)
  if (source) toggle(source.paydayWeekdays, weekday, false)
}

export function addIncomeType(d: D, name: string) {
  d.incomeTypes.push(name)
}

export function renameIncomeType(d: D, from: string, to: string) {
  d.incomeTypes = d.incomeTypes.map((t) => (t === from ? to : t))
  for (const s of d.income) {
    if ((s.incomeType || "Other") === from) s.incomeType = to
  }
}

/** Where a deleted income type's sources go. */
export function incomeTypeFallback(types: string[], type: string) {
  return type === "Other" ? types.find((t) => t !== type)! : "Other"
}

export function deleteIncomeType(d: D, type: string) {
  if (type !== "Other" && !d.incomeTypes.includes("Other")) {
    d.incomeTypes.push("Other")
  }
  const fallback = incomeTypeFallback(d.incomeTypes, type)
  for (const s of d.income) {
    if ((s.incomeType || "Other") === type) s.incomeType = fallback
  }
  d.incomeTypes = d.incomeTypes.filter((t) => t !== type)
}

/** Dropped onto another source: take its place and its income type. */
export function moveSourceBefore(d: D, id: number, targetId: number) {
  const source = d.income.find((s) => s.id === id)
  const target = d.income.find((s) => s.id === targetId)
  if (!source || !target || source === target) return
  source.incomeType = target.incomeType || "Other"
  moveBefore(d.income, source, target)
}

/** Dropped onto an income type: becomes its last source. */
export function moveSourceToType(d: D, id: number, type: string) {
  const index = d.income.findIndex((s) => s.id === id)
  if (index < 0) return
  const [source] = d.income.splice(index, 1)
  source.incomeType = type
  insertAfterLast(d.income, source, (s) => (s.incomeType || "Other") === type)
}

/** Reorders income types; `before` null moves `type` to the end. */
export function moveIncomeType(d: D, type: string, before: string | null) {
  if (type === before || !d.incomeTypes.includes(type)) return
  if (before === null) {
    d.incomeTypes = [...d.incomeTypes.filter((t) => t !== type), type]
  } else if (d.incomeTypes.includes(before)) {
    moveBefore(d.incomeTypes, type, before)
  }
}

/* ── Expenses ────────────────────────────────────────────────────────── */

export function updateExpense(d: D, id: number, changes: Partial<Expense>) {
  const expense = d.expenses.find((e) => e.id === id)
  if (expense) Object.assign(expense, changes)
}

/** Without a category it lands at the top, in the review list. */
export function addExpense(d: D, category?: string) {
  const expense: Expense = {
    id: d.nextId++,
    name: "New Expense",
    cat: category || UNCATEGORIZED,
    cost: 0,
    dueType: "dates",
    due: null,
    dueWeekdays: [],
    showOnCal: true,
  }
  if (expense.cat === UNCATEGORIZED) d.expenses.unshift(expense)
  else insertAfterLast(d.expenses, expense, (e) => e.cat === expense.cat)
}

export function deleteExpense(d: D, id: number) {
  d.expenses = d.expenses.filter((e) => e.id !== id)
}

export function toggleExpenseWeekday(d: D, id: number, weekday: number) {
  const expense = d.expenses.find((e) => e.id === id)
  if (expense) toggle(expense.dueWeekdays, weekday)
}

export function toggleBillOnCalendar(d: D, id: number) {
  const expense = d.expenses.find((e) => e.id === id)
  if (expense) expense.showOnCal = expense.showOnCal === false
}

export function addCategory(d: D, name: string) {
  d.catColors[name] = unusedColor(
    Object.values(d.catColors),
    d.categories.length
  )
  d.categories.push(name)
}

export function renameCategory(d: D, from: string, to: string) {
  d.categories = d.categories.map((c) => (c === from ? to : c))
  for (const e of d.expenses) if (e.cat === from) e.cat = to
  d.catColors[to] =
    d.catColors[from] || COLOR_POOL[d.categories.length % COLOR_POOL.length]
  delete d.catColors[from]
}

/** Its expenses move to the review list. */
export function deleteCategory(d: D, category: string) {
  for (const e of d.expenses) if (e.cat === category) e.cat = UNCATEGORIZED
  d.categories = d.categories.filter((c) => c !== category)
  delete d.catColors[category]
}

export function moveExpenseBefore(d: D, id: number, targetId: number) {
  const expense = d.expenses.find((e) => e.id === id)
  const target = d.expenses.find((e) => e.id === targetId)
  if (!expense || !target || expense === target) return
  expense.cat = target.cat
  moveBefore(d.expenses, expense, target)
}

export function moveExpenseToCategory(d: D, id: number, category: string) {
  const index = d.expenses.findIndex((e) => e.id === id)
  if (index < 0) return
  const [expense] = d.expenses.splice(index, 1)
  expense.cat = category
  insertAfterLast(d.expenses, expense, (e) => e.cat === category)
}

export function moveCategory(d: D, category: string, before: string | null) {
  if (category === before || !d.categories.includes(category)) return
  if (before === null) {
    d.categories = [...d.categories.filter((c) => c !== category), category]
  } else if (d.categories.includes(before)) {
    moveBefore(d.categories, category, before)
  }
}

/** Reorders the bills list (the category stays the same). */
export function moveBillBefore(d: D, id: number, targetId: number) {
  const expense = d.expenses.find((e) => e.id === id)
  const target = d.expenses.find((e) => e.id === targetId)
  if (!expense || !target || expense === target) return
  moveBefore(d.expenses, expense, target)
}

/** A bill row dropped on a calendar day. Weekday bills take that weekday. */
export function setBillDay(d: D, id: number, date: Date) {
  const expense = d.expenses.find((e) => e.id === id)
  if (!expense) return
  if (expense.dueType === "weekdays") expense.dueWeekdays = [date.getDay()]
  else expense.due = date.getDate()
}

export function setPaymentLink(d: D, id: number, link: string) {
  const expense = d.expenses.find((e) => e.id === id)
  if (expense) expense.paymentLink = link
}

/* ── Savings ─────────────────────────────────────────────────────────── */

export function updateBucket(
  d: D,
  id: number,
  changes: Partial<SavingsBucket>
) {
  const bucket = d.savingsBuckets.find((b) => b.id === id)
  if (bucket) Object.assign(bucket, changes)
}

export function addBucket(d: D, name: string) {
  d.savingsBuckets.push({
    id: d.nextId++,
    name,
    target: 0,
    current: 0,
    color: unusedColor(
      d.savingsBuckets.map((b) => b.color),
      d.savingsBuckets.length
    ),
  })
}

export function deleteBucket(d: D, id: number) {
  d.savingsBuckets = d.savingsBuckets.filter((b) => b.id !== id)
}

/** Moves a bucket up (-1) or down (+1) in the fill order. */
export function moveBucket(d: D, id: number, direction: -1 | 1) {
  const i = d.savingsBuckets.findIndex((b) => b.id === id)
  const j = i + direction
  if (i < 0 || j < 0 || j >= d.savingsBuckets.length) return
  ;[d.savingsBuckets[i], d.savingsBuckets[j]] = [
    d.savingsBuckets[j],
    d.savingsBuckets[i],
  ]
}

export function updateContribution(
  d: D,
  id: number,
  changes: Partial<Contribution>
) {
  const contribution = d.savingsContribs.find((c) => c.id === id)
  if (contribution) Object.assign(contribution, changes)
}

export function addContribution(d: D) {
  d.savingsContribs.push({
    id: d.nextId++,
    name: "New Contribution",
    amount: 0,
    dueType: "dates",
    due: null,
    dueWeekdays: [],
    weekendShift: "none",
    showOnCal: true,
  })
}

export function deleteContribution(d: D, id: number) {
  d.savingsContribs = d.savingsContribs.filter((c) => c.id !== id)
}

export function toggleContributionOnCalendar(d: D, id: number) {
  const contribution = d.savingsContribs.find((c) => c.id === id)
  if (contribution) contribution.showOnCal = contribution.showOnCal === false
}

export function toggleContributionWeekday(d: D, id: number, weekday: number) {
  const contribution = d.savingsContribs.find((c) => c.id === id)
  if (contribution) toggle(contribution.dueWeekdays, weekday)
}

/* ── Calendar ────────────────────────────────────────────────────────── */

/**
 * A pill dragged to another day. Date-based items move to that date;
 * weekday-based items swap the old weekday for the new one.
 */
export function movePill(d: D, pill: CalendarPill, date: Date) {
  const day = date.getDate()
  const weekday = date.getDay()
  if (pill.isWeekday ? weekday === pill.fromDay : day === pill.fromDay) return

  const swapWeekday = (weekdays: number[], sort: boolean) => {
    const index = weekdays.indexOf(pill.fromDay)
    if (index >= 0) weekdays.splice(index, 1)
    if (!weekdays.includes(weekday)) weekdays.push(weekday)
    if (sort) weekdays.sort((a, b) => a - b)
  }

  if (pill.kind === "bill") {
    const expense = d.expenses.find((e) => e.id === pill.refId)
    if (!expense) return
    if (pill.isWeekday && expense.dueType === "weekdays") {
      swapWeekday(expense.dueWeekdays, true)
    } else if (expense.dueType === "dates") {
      expense.due = day
    }
  } else if (pill.kind === "sav") {
    const contribution = d.savingsContribs.find((c) => c.id === pill.refId)
    if (!contribution) return
    if (pill.isWeekday && contribution.dueType === "weekdays") {
      swapWeekday(contribution.dueWeekdays, true)
    } else if (contribution.dueType === "dates") {
      contribution.due = day
    }
  } else {
    const source = d.income.find((s) => s.id === pill.refId)
    if (!source) return
    if (pill.isWeekday && source.paydayType === "weekdays") {
      swapWeekday(source.paydayWeekdays, false)
    } else if (source.paydayType === "dates") {
      const index = source.paydayDates.indexOf(pill.fromDay)
      if (index >= 0) source.paydayDates.splice(index, 1)
      if (!source.paydayDates.includes(day)) source.paydayDates.push(day)
      source.paydayDates.sort((a, b) => a - b)
    }
  }
}
