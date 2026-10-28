export type Session = {
  id: number
  /** "YYYY-MM-DD", or "" until picked. */
  date: string
  /** "HH:MM" (24h), or "". */
  startTime: string
  hrs: number
}

export type Student = {
  id: number
  name: string
  subject: string
  sessions: Session[]
}

export type PaymentReport = {
  name: string
  /** Report period, "YYYY-MM-DD". */
  start: string
  end: string
  rate: number
  every: string
  students: Student[]
  nextId: number
}

export const STORAGE_KEY = "payment_v2"

export function defaultReport(): PaymentReport {
  return {
    name: "David Kim",
    start: "2026-04-26",
    end: "2026-05-10",
    rate: 40,
    every: "10th & 25th",
    students: [
      {
        id: 1,
        name: "Ian",
        subject: "SAT MATH",
        sessions: [
          { id: 101, date: "2026-05-02", startTime: "10:00", hrs: 2 },
          { id: 102, date: "2026-05-09", startTime: "10:00", hrs: 2 },
        ],
      },
      {
        id: 2,
        name: "Siwoo",
        subject: "AMC 10 MATH",
        sessions: [
          { id: 201, date: "2026-04-26", startTime: "12:00", hrs: 1 },
          { id: 202, date: "2026-05-02", startTime: "12:00", hrs: 1 },
          { id: 203, date: "2026-05-09", startTime: "12:00", hrs: 1 },
        ],
      },
      {
        id: 3,
        name: "Doyun",
        subject: "SAT MATH",
        sessions: [
          { id: 301, date: "2026-04-26", startTime: "14:00", hrs: 1.5 },
        ],
      },
    ],
    nextId: 10,
  }
}

const toNumber = (value: unknown) => {
  const n = typeof value === "number" ? value : parseFloat(String(value))
  return Number.isFinite(n) ? n : 0
}

/** Accepts saved reports, filling gaps with defaults like earlier versions did. */
export function reviveReport(raw: unknown): PaymentReport | null {
  if (!raw || typeof raw !== "object") return null
  const merged = { ...defaultReport(), ...(raw as Partial<PaymentReport>) }
  return {
    ...merged,
    rate: toNumber(merged.rate),
    students: (Array.isArray(merged.students) ? merged.students : []).map(
      (student) => ({
        ...student,
        sessions: (student.sessions ?? []).map((session) => ({
          ...session,
          startTime: session.startTime ?? "",
          hrs: toNumber(session.hrs),
        })),
      })
    ),
  }
}

export function studentHours(student: Student) {
  return student.sessions.reduce((sum, session) => sum + (session.hrs || 0), 0)
}

export function studentTotal(student: Student, rate: number) {
  return studentHours(student) * (rate || 0)
}

export function reportHours(report: PaymentReport) {
  return report.students.reduce(
    (sum, student) => sum + studentHours(student),
    0
  )
}

export function reportTotal(report: PaymentReport) {
  return reportHours(report) * (report.rate || 0)
}

/** "5/2" for "2026-05-02", as on the printed report. */
export function shortDate(value: string) {
  const parts = value.split("-")
  return parts.length === 3 ? `${+parts[1]}/${+parts[2]}` : value
}

/** "10:00 AM" for "10:00". */
export function clockTime(value: string) {
  if (!value) return ""
  const [h, m] = value.split(":").map(Number)
  return `${h % 12 || 12}:${String(m).padStart(2, "0")} ${h >= 12 ? "PM" : "AM"}`
}
