export type ScheduleKind = "dates" | "weekdays"

export type IncomeSource = {
  id: number
  name: string
  /** Group shown on the Income tab (Work, Business, ...). */
  incomeType: string
  type: "Taxed" | "Untaxed"
  payType: "Salary" | "Hourly"
  /** Monthly salary (Salary only). */
  monthly: number | null
  /** Hourly rate, or the annual bonus for a Salary source. */
  rate: number | null
  hrsPerWeek: number | null
  paydayType: ScheduleKind
  /** Days of the month (1-31). */
  paydayDates: number[]
  /** Date.getDay() values (0 = Sunday). */
  paydayWeekdays: number[]
  weekendShift: string
  showOnCal: boolean
}

export type Expense = {
  id: number
  name: string
  cat: string
  /** Monthly cost, or the cost per occurrence for weekday bills. */
  cost: number
  dueType: ScheduleKind
  due: number | null
  dueWeekdays: number[]
  showOnCal: boolean
  paymentLink?: string
}

export type SavingsBucket = {
  id: number
  name: string
  target: number
  current: number
  color: string
}

export type Contribution = {
  id: number
  name: string
  /** Monthly amount, or the amount per occurrence on weekdays. */
  amount: number
  dueType: ScheduleKind
  due: number | null
  dueWeekdays: number[]
  weekendShift: string
  showOnCal: boolean
}

export type TrackerData = {
  taxRate: number
  income: IncomeSource[]
  incomeTypes: string[]
  categories: string[]
  catColors: Record<string, string>
  expenses: Expense[]
  /** Fill order: each bucket fills to its target before the next one. */
  savingsBuckets: SavingsBucket[]
  savingsContribs: Contribution[]
  nextId: number
  /** Kept for older clients; the tab order is fixed. */
  tabOrder: string[]
}

export const STORAGE_KEY = "game_tracker_v3"
export const UNCATEGORIZED = "Uncategorized"
export const DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
export const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]
export const INCOME_COLORS = [
  "#639922",
  "#378ADD",
  "#7F77DD",
  "#D85A30",
  "#1abc9c",
  "#e67e22",
  "#e91e8c",
]
/** Colors handed to new categories and buckets. */
export const COLOR_POOL = [
  "#E24B4A",
  "#ea9f27",
  "#1abc9c",
  "#e91e8c",
  "#00bcd4",
  "#8bc34a",
  "#ff5722",
]
export const NEUTRAL_COLOR = "#888780"
export const PAYDAY_COLOR = "#639922"
export const WEEKS_PER_MONTH = 52 / 12
const TAB_ORDER = ["dashboard", "income", "expenses", "savings", "calendar"]

export function defaultTracker(): TrackerData {
  const source = (
    id: number,
    name: string,
    incomeType: string,
    type: IncomeSource["type"],
    pay: Pick<IncomeSource, "payType" | "monthly" | "rate" | "hrsPerWeek">,
    paydayDates: number[]
  ): IncomeSource => ({
    id,
    name,
    incomeType,
    type,
    ...pay,
    paydayType: "dates",
    paydayDates,
    paydayWeekdays: [],
    weekendShift: "none",
    showOnCal: true,
  })
  const hourly = {
    payType: "Hourly",
    monthly: null,
    rate: 40,
    hrsPerWeek: 4,
  } as const
  const expense = (
    id: number,
    name: string,
    cat: string,
    cost: number,
    due: number | null = null
  ): Expense => ({
    id,
    name,
    cat,
    cost,
    dueType: "dates",
    due,
    dueWeekdays: [],
    showOnCal: true,
  })

  return {
    taxRate: 0.25,
    income: [
      source(
        1,
        "Young",
        "Work",
        "Taxed",
        { payType: "Salary", monthly: 5000, rate: null, hrsPerWeek: null },
        [1, 16]
      ),
      source(2, "Steven", "Work", "Taxed", hourly, [15, 31]),
      source(3, "Prime", "Work", "Taxed", hourly, [20, 5]),
      source(4, "Twins", "Side", "Untaxed", hourly, []),
    ],
    incomeTypes: ["Work", "Business", "Side", "Other"],
    categories: ["Loans", "Necessities", "Luxury", "Fuckery"],
    catColors: {
      Loans: "#378ADD",
      Necessities: "#1D9E75",
      Luxury: "#7F77DD",
      Fuckery: "#D85A30",
    },
    expenses: [
      expense(1, "Rent", "Necessities", 700, 1),
      expense(2, "Groceries", "Necessities", 250),
      expense(3, "Gas", "Necessities", 100),
      expense(4, "Haircut", "Necessities", 35),
      expense(5, "Auto", "Loans", 202, 12),
      expense(6, "Auto Ins", "Loans", 200, 2),
      expense(7, "Student", "Loans", 100, 3),
      expense(8, "Health", "Loans", 126, 2),
      expense(9, "Gym", "Luxury", 20),
      expense(10, "Spotify", "Luxury", 22),
      expense(11, "iCloud", "Luxury", 1),
      expense(12, "AI", "Luxury", 28),
      expense(13, "Lottery", "Fuckery", 8),
      expense(14, "Misc (untracked)", "Fuckery", 200),
    ],
    savingsBuckets: [
      { id: 1, name: "Checking", target: 4000, current: 0, color: "#378ADD" },
      { id: 2, name: "Emergency", target: 12000, current: 0, color: "#1abc9c" },
      {
        id: 3,
        name: "Investment",
        target: 50000,
        current: 0,
        color: "#7F77DD",
      },
    ],
    savingsContribs: [],
    nextId: 20,
    tabOrder: [...TAB_ORDER],
  }
}

type Loose<T> = { [K in keyof T]?: T[K] | null } & Record<string, unknown>

/** Upgrades data saved by any earlier version to the current shape. */
export function reviveTracker(raw: unknown): TrackerData | null {
  if (!raw || typeof raw !== "object") return null
  const saved = structuredClone(raw) as Loose<TrackerData>
  const defaults = defaultTracker()

  const income = (saved.income ?? defaults.income).map((raw) => {
    const s = raw as IncomeSource & { payday?: string; guar?: unknown }
    if (!s.paydayType) {
      const days = s.payday ? s.payday.match(/\d+/g) : []
      s.paydayType = "dates"
      s.paydayDates = days ? days.map(Number) : []
      s.paydayWeekdays = []
    }
    if (s.showOnCal === undefined) s.showOnCal = true
    if (!s.payType) s.payType = s.rate && !s.monthly ? "Hourly" : "Salary"
    if (!s.incomeType) s.incomeType = "Other"
    if (!s.weekendShift) s.weekendShift = "none"
    s.paydayDates ??= []
    s.paydayWeekdays ??= []
    s.hrsPerWeek = s.hrsPerWeek || null
    delete s.guar
    return s
  })

  const incomeTypes = saved.incomeTypes ?? [...defaults.incomeTypes]
  for (const s of income) {
    if (!incomeTypes.includes(s.incomeType)) incomeTypes.push(s.incomeType)
  }

  const expenses = (saved.expenses ?? defaults.expenses).map((e) => {
    if (e.showOnCal === undefined) e.showOnCal = true
    if (!e.dueType) e.dueType = "dates"
    if (!e.dueWeekdays) e.dueWeekdays = []
    e.due ??= null
    return e
  })

  const savingsContribs = (saved.savingsContribs ?? []).map((c) => {
    if (c.showOnCal === undefined) c.showOnCal = true
    if (!c.dueType) c.dueType = "dates"
    if (!c.dueWeekdays) c.dueWeekdays = []
    if (!c.weekendShift) c.weekendShift = "none"
    c.due ??= null
    return c
  })

  let tabOrder = saved.tabOrder ?? [...TAB_ORDER]
  if (!tabOrder.includes("savings")) {
    tabOrder = [...tabOrder]
    const calendar = tabOrder.indexOf("calendar")
    if (calendar >= 0) tabOrder.splice(calendar, 0, "savings")
    else tabOrder.push("savings")
  }

  return {
    taxRate: saved.taxRate ?? defaults.taxRate,
    income,
    incomeTypes,
    categories: saved.categories ?? [...defaults.categories],
    catColors: saved.catColors ?? { ...defaults.catColors },
    expenses,
    savingsBuckets:
      saved.savingsBuckets ?? structuredClone(defaults.savingsBuckets),
    savingsContribs,
    nextId: saved.nextId ?? defaults.nextId,
    tabOrder,
  }
}

/* ── Money math ──────────────────────────────────────────────────────── */

/** Gross monthly pay. Hourly pay counts four weeks a month. */
export function monthlyGross(source: IncomeSource) {
  return source.payType === "Hourly"
    ? (source.rate || 0) * (source.hrsPerWeek || 0) * 4
    : source.monthly || 0
}

export function monthlyNet(source: IncomeSource, taxRate: number) {
  const gross = monthlyGross(source)
  return source.type === "Taxed" ? gross * (1 - taxRate) : gross
}

export function monthlyCost(expense: Expense) {
  if (expense.dueType === "weekdays") {
    return (expense.cost || 0) * expense.dueWeekdays.length * WEEKS_PER_MONTH
  }
  return expense.cost || 0
}

export function monthlyContribution(contribution: Contribution) {
  if (contribution.dueType === "weekdays") {
    return (
      (contribution.amount || 0) *
      contribution.dueWeekdays.length *
      WEEKS_PER_MONTH
    )
  }
  return contribution.amount || 0
}

export function categoryColor(data: TrackerData, category: string) {
  return data.catColors[category] || NEUTRAL_COLOR
}

export function incomeColor(index: number) {
  return INCOME_COLORS[index % INCOME_COLORS.length]
}

/**
 * Splits `amount` across buckets in priority order. Each bucket except the
 * last fills up to its target; the last one takes the overflow, uncapped.
 */
export function waterfallAllocate(
  amount: number,
  balances: Record<number, number>,
  buckets: SavingsBucket[]
) {
  const allocations: Record<number, number> = {}
  let remaining = amount
  for (let i = 0; i < buckets.length && remaining > 0; i++) {
    const bucket = buckets[i]
    if (i === buckets.length - 1) {
      allocations[bucket.id] = (allocations[bucket.id] || 0) + remaining
      remaining = 0
    } else {
      const room = Math.max(
        0,
        (bucket.target || 0) - (balances[bucket.id] || 0)
      )
      const fill = Math.min(remaining, room)
      if (fill > 0) {
        allocations[bucket.id] = (allocations[bucket.id] || 0) + fill
        remaining -= fill
      }
    }
  }
  return allocations
}

/** Bucket balances after `months` of contributing `monthlyTotal` each month. */
export function projectBalances(
  months: number,
  monthlyTotal: number,
  startBalances: Record<number, number>,
  buckets: SavingsBucket[]
) {
  const balances = { ...startBalances }
  for (let m = 0; m < months; m++) {
    const allocations = waterfallAllocate(monthlyTotal, balances, buckets)
    for (const id in allocations) {
      balances[id] = (balances[id] || 0) + allocations[id]
    }
  }
  return balances
}

export type Summary = ReturnType<typeof summarize>

/** Every derived number the tabs show. */
export function summarize(data: TrackerData) {
  const { income, taxRate } = data
  const sumOf = <T>(items: T[], value: (item: T) => number) =>
    items.reduce((total, item) => total + value(item), 0)

  const gross = sumOf(income, monthlyGross)
  const taxed = sumOf(
    income.filter((s) => s.type === "Taxed"),
    monthlyGross
  )
  const untaxed = sumOf(
    income.filter((s) => s.type === "Untaxed"),
    monthlyGross
  )
  const earn = taxed * (1 - taxRate) + untaxed

  // A salaried source's `rate` is its annual bonus: annual figures only.
  const bonus = (type: IncomeSource["type"]) =>
    sumOf(
      income.filter((s) => s.payType === "Salary" && s.type === type && s.rate),
      (s) => s.rate || 0
    )
  const bonusTaxed = bonus("Taxed")
  const bonusUntaxed = bonus("Untaxed")
  const annualBonus = bonusTaxed + bonusUntaxed
  const annualBonusNet = bonusTaxed * (1 - taxRate) + bonusUntaxed

  const annualGross = gross * 12 + annualBonus
  const afterTax = earn * 12 + annualBonusNet
  const counted = data.expenses.filter((e) => e.cat !== UNCATEGORIZED)
  const expenses = sumOf(counted, monthlyCost)
  const pureSavings = afterTax - expenses * 12
  const game = earn - expenses
  const byCategory: Record<string, number> = {}
  for (const e of counted) {
    byCategory[e.cat] = (byCategory[e.cat] || 0) + monthlyCost(e)
  }

  const totalSavings = sumOf(data.savingsBuckets, (b) => b.current || 0)
  const totalTarget = sumOf(data.savingsBuckets, (b) => b.target || 0)
  const monthlyContributions = sumOf(data.savingsContribs, monthlyContribution)
  const startBalances: Record<number, number> = {}
  for (const b of data.savingsBuckets) startBalances[b.id] = b.current || 0
  const monthAllocations = waterfallAllocate(
    monthlyContributions,
    startBalances,
    data.savingsBuckets
  )
  const bucketMonthly: Record<number, number> = {}
  for (const b of data.savingsBuckets) {
    bucketMonthly[b.id] = monthAllocations[b.id] || 0
  }

  return {
    gross,
    taxed,
    untaxed,
    earn,
    annualBonus,
    annualBonusNet,
    annualGross,
    afterTax,
    expenses,
    expenseCount: counted.length,
    pureSavings,
    game,
    byCategory,
    /** Two months of expenses for checking, six for an emergency fund. */
    checkingGoal: expenses * 2,
    emergencyGoal: expenses * 6,
    totalSavings,
    totalTarget,
    monthlyContributions,
    bucketMonthly,
    freeCash: game - monthlyContributions,
    startBalances,
  }
}

/* ── Labels ──────────────────────────────────────────────────────────── */

export function ordinalSuffix(n: number) {
  const suffixes = ["th", "st", "nd", "rd"]
  const v = n % 100
  return suffixes[(v - 20) % 10] || suffixes[v] || suffixes[0]
}

export function weekdaysLabel(weekdays: number[]) {
  return weekdays.map((d) => DAYS_SHORT[d]).join(", ") || "—"
}

export function datesLabel(dates: number[]) {
  return dates.map((d) => d + ordinalSuffix(d)).join(", ") || "—"
}

export function dueLabel(
  item: Pick<Expense, "dueType" | "due" | "dueWeekdays">
) {
  return item.dueType === "weekdays"
    ? weekdaysLabel(item.dueWeekdays)
    : item.due
      ? item.due + ordinalSuffix(item.due)
      : "—"
}

/** Sort key that puts earlier due days first and undated items last. */
export function dueSortKey(
  item: Pick<Expense, "dueType" | "due" | "dueWeekdays">
) {
  return item.dueType === "weekdays"
    ? (item.dueWeekdays[0] ?? 99) + 1
    : item.due || 99
}

/** Accepts "pay.example.com" as https and rejects other schemes. */
export function safeHref(url: string | undefined) {
  const value = (url ?? "").trim()
  if (/^(https?:|mailto:)/i.test(value)) return value
  if (/^[\w.-]+\.[\w.-]+/.test(value)) return `https://${value}`
  return null
}
