import {
  categoryColor,
  DAYS_SHORT,
  monthlyNet,
  ordinalSuffix,
  PAYDAY_COLOR,
  UNCATEGORIZED,
  type TrackerData,
} from "@/pages/tracker/model"

export type PillKind = "pay" | "bill"

export type CalendarPill = {
  key: string
  kind: PillKind
  label: string
  color: string
  amount: number
  /** Income source or expense id. */
  refId: number
  /** Scheduled day of month, or weekday for weekday schedules, before any weekend shift. */
  fromDay: number
  isWeekday: boolean
  /** Moved off a weekend onto the next Monday. */
  shifted: boolean
  shiftLabel: string | null
}

export type CalendarFilters = {
  paydays: boolean
  bills: boolean
}

export type CalendarMonth = {
  daysInMonth: number
  /** Weekday of the 1st (0 = Sunday). */
  firstWeekday: number
  pills: Record<number, CalendarPill[]>
  /** Paydays minus bills, accumulated through each day (index = day). */
  runningNet: number[]
}

/** Pills and running totals for one month of the calendar tab. */
export function buildCalendarMonth(
  data: TrackerData,
  year: number,
  month: number,
  filters: CalendarFilters
): CalendarMonth {
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const weekday = (day: number) => new Date(year, month, day).getDay()
  const days = Array.from({ length: daysInMonth }, (_, i) => i + 1)

  // Weekend days move to the following Monday unless that leaves the month.
  const shiftWeekend = (day: number) => {
    if (day < 1 || day > daysInMonth) return day
    let current = day
    while (weekday(current) === 0 || weekday(current) === 6) {
      current += 1
      if (current > daysInMonth) return day
    }
    return current
  }

  const payCount = (source: TrackerData["income"][number]) =>
    source.paydayType === "weekdays"
      ? days.filter((d) => source.paydayWeekdays.includes(weekday(d))).length ||
        1
      : source.paydayDates.filter((d) => d <= daysInMonth).length || 1

  const dayNet = Array<number>(daysInMonth + 1).fill(0)
  const addNet = (day: number, amount: number) => {
    if (day >= 1 && day <= daysInMonth) dayNet[day] += amount
  }
  const pills: Record<number, CalendarPill[]> = {}
  const addPill = (day: number, pill: Omit<CalendarPill, "key">) => {
    if (day < 1 || day > daysInMonth) return
    ;(pills[day] ??= []).push({
      ...pill,
      key: `${pill.kind}-${pill.refId}-${pill.fromDay}-${day}`,
    })
  }

  const bills = data.expenses.filter(
    (e) => e.cat !== UNCATEGORIZED && e.showOnCal !== false
  )

  /* Running net, independent of which pill types are shown. */
  for (const source of data.income) {
    if (source.showOnCal === false) continue
    const amount = Math.round(
      monthlyNet(source, data.taxRate) / payCount(source)
    )
    if (source.paydayType === "weekdays") {
      for (const d of days) {
        if (source.paydayWeekdays.includes(weekday(d)))
          addNet(shiftWeekend(d), amount)
      }
    } else {
      for (const d of source.paydayDates) {
        if (d <= daysInMonth) addNet(shiftWeekend(d), amount)
      }
    }
  }
  for (const bill of bills) {
    const amount = bill.cost || 0
    if (bill.dueType === "weekdays") {
      for (const d of days) {
        if (bill.dueWeekdays.includes(weekday(d))) addNet(d, -amount)
      }
    } else if (bill.due) {
      addNet(bill.due, -amount)
    }
  }
  const runningNet = [0]
  for (const d of days) runningNet[d] = runningNet[d - 1] + dayNet[d]

  /* Paydays */
  if (filters.paydays) {
    for (const source of data.income) {
      if (!source.showOnCal) continue
      const amount = Math.round(
        monthlyNet(source, data.taxRate) / payCount(source)
      )
      const base = {
        kind: "pay" as const,
        label: source.name,
        color: PAYDAY_COLOR,
        amount,
        refId: source.id,
      }
      if (source.paydayType === "weekdays") {
        for (const d of days) {
          const dow = weekday(d)
          if (!source.paydayWeekdays.includes(dow)) continue
          const shifted = shiftWeekend(d) !== d
          addPill(shiftWeekend(d), {
            ...base,
            fromDay: dow,
            isWeekday: true,
            shifted,
            shiftLabel: shifted ? DAYS_SHORT[dow] : null,
          })
        }
      } else {
        for (const d of source.paydayDates) {
          if (d > daysInMonth) continue
          const shifted = shiftWeekend(d) !== d
          addPill(shiftWeekend(d), {
            ...base,
            fromDay: d,
            isWeekday: false,
            shifted,
            shiftLabel: shifted ? d + ordinalSuffix(d) : null,
          })
        }
      }
    }
  }

  /* Bills (never shifted: they are due when they are due) */
  if (filters.bills) {
    for (const bill of bills) {
      const base = {
        kind: "bill" as const,
        label: bill.name,
        color: categoryColor(data, bill.cat),
        amount: bill.cost,
        refId: bill.id,
        shifted: false,
        shiftLabel: null,
      }
      if (bill.dueType === "weekdays") {
        for (const d of days) {
          const dow = weekday(d)
          if (bill.dueWeekdays.includes(dow)) {
            addPill(d, { ...base, fromDay: dow, isWeekday: true })
          }
        }
      } else if (bill.due) {
        addPill(bill.due, { ...base, fromDay: bill.due, isWeekday: false })
      }
    }
  }

  return {
    daysInMonth,
    firstWeekday: new Date(year, month, 1).getDay(),
    pills,
    runningNet,
  }
}
