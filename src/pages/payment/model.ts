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

export function emptyReport(): PaymentReport {
  return {
    name: "",
    start: "",
    end: "",
    rate: 0,
    every: "",
    students: [],
    nextId: 1,
  }
}

const toNumber = (value: unknown) => {
  const n = typeof value === "number" ? value : parseFloat(String(value))
  return Number.isFinite(n) ? n : 0
}

/** Accepts saved reports, leaving anything they lack blank. */
export function reviveReport(raw: unknown): PaymentReport | null {
  if (!raw || typeof raw !== "object") return null
  const saved = raw as Partial<PaymentReport>
  const merged = { ...emptyReport(), ...saved }
  const students = (Array.isArray(merged.students) ? merged.students : []).map(
    (student) => ({
      ...student,
      sessions: (student.sessions ?? []).map((session) => ({
        ...session,
        startTime: session.startTime ?? "",
        hrs: toNumber(session.hrs),
      })),
    })
  )
  const ids = students.flatMap((student) => [
    student.id,
    ...student.sessions.map((session) => session.id),
  ])
  return {
    ...merged,
    rate: toNumber(merged.rate),
    students,
    nextId: saved.nextId ?? Math.max(0, ...ids) + 1,
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
