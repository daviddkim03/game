import type { PaymentReport } from "../src/pages/payment/model"
import type {
  Expense,
  IncomeSource,
  TrackerData,
} from "../src/pages/tracker/model"

/** Made-up data for tests. The site itself starts empty. */
export function sampleTracker(): TrackerData {
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
  const hourly = (rate: number, hrsPerWeek: number) =>
    ({ payType: "Hourly", monthly: null, rate, hrsPerWeek }) as const
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
        "Northwind",
        "Work",
        "Taxed",
        { payType: "Salary", monthly: 4200, rate: null, hrsPerWeek: null },
        [1, 16]
      ),
      source(2, "Cafe", "Work", "Taxed", hourly(18, 10), [15, 31]),
      source(3, "Bookshop", "Work", "Taxed", hourly(16, 5), [20, 5]),
      source(4, "Dog walking", "Side", "Untaxed", hourly(25, 2), []),
    ],
    incomeTypes: ["Work", "Business", "Side", "Other"],
    categories: ["Debt", "Home", "Fun", "Extras"],
    catColors: {
      Debt: "#378ADD",
      Home: "#1D9E75",
      Fun: "#7F77DD",
      Extras: "#D85A30",
    },
    expenses: [
      expense(1, "Rent", "Home", 900, 1),
      expense(2, "Food", "Home", 300),
      expense(3, "Bus pass", "Home", 60),
      expense(4, "Laundry", "Home", 25),
      expense(5, "Car", "Debt", 180, 12),
      expense(6, "Insurance", "Debt", 90, 2),
      expense(7, "Laptop", "Debt", 50, 3),
      expense(8, "Dentist", "Debt", 40, 2),
      expense(9, "Climbing", "Fun", 30),
      expense(10, "Music", "Fun", 11),
      expense(11, "Storage", "Fun", 3),
      expense(12, "Games", "Fun", 15),
      expense(13, "Coffee", "Extras", 12),
      expense(14, "Odds and ends", "Extras", 100),
    ],
    nextId: 20,
    tabOrder: ["dashboard", "income", "expenses", "calendar"],
  }
}

export function sampleReport(): PaymentReport {
  return {
    name: "Sam Lee",
    start: "2026-03-01",
    end: "2026-03-15",
    rate: 30,
    every: "1st & 15th",
    students: [
      {
        id: 1,
        name: "Ana",
        subject: "Algebra",
        sessions: [
          { id: 101, date: "2026-03-07", startTime: "10:00", hrs: 2 },
          { id: 102, date: "2026-03-14", startTime: "10:00", hrs: 2 },
        ],
      },
      {
        id: 2,
        name: "Ben",
        subject: "Chemistry",
        sessions: [
          { id: 201, date: "2026-03-01", startTime: "12:00", hrs: 1 },
          { id: 202, date: "2026-03-07", startTime: "12:00", hrs: 1 },
          { id: 203, date: "2026-03-14", startTime: "12:00", hrs: 1 },
        ],
      },
      {
        id: 3,
        name: "Cara",
        subject: "Physics",
        sessions: [
          { id: 301, date: "2026-03-01", startTime: "14:00", hrs: 1.5 },
        ],
      },
    ],
    nextId: 10,
  }
}
