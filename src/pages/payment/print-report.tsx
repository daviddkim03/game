import "./print-report.css"

import type { ReactNode } from "react"

import {
  clockTime,
  reportTotal,
  shortDate,
  studentTotal,
  type PaymentReport,
  type Student,
} from "@/pages/payment/model"

/** Session columns per student row; grows if someone has more sessions. */
const MIN_SESSION_COLUMNS = 8

/** The printed (PDF) report, laid out like the original spreadsheet. */
export function PrintReport({ report }: { report: PaymentReport }) {
  const rate = report.rate || 0
  const sessionColumns = Math.max(
    MIN_SESSION_COLUMNS,
    ...report.students.map((student) => student.sessions.length)
  )
  const width = sessionColumns + 3
  const padding = (count: number) =>
    Array.from({ length: sessionColumns - count }, (_, i) => (
      <td key={`pad-${i}`} />
    ))

  return (
    <div className="print-report" aria-hidden>
      <table>
        <tbody>
          <tr className="pr-header-row">
            <td colSpan={width}>Report every {report.every || "—"}</td>
          </tr>
          <tr className="pr-header-row">
            <td colSpan={Math.ceil(width / 2)} style={{ fontSize: "13pt" }}>
              {report.name || "Tutor"} ({shortDate(report.start) || "?"}-
              {shortDate(report.end) || "?"})
            </td>
            <td colSpan={Math.floor(width / 2) - 2} />
            <td style={{ textAlign: "right", fontSize: "9pt", color: "#555" }}>
              Rate
            </td>
            <td style={{ textAlign: "right", fontWeight: "bold" }}>
              {rate.toFixed(1)}
            </td>
          </tr>
          <tr className="pr-spacer">
            <td colSpan={width} />
          </tr>
          {report.students.map((student) => (
            <StudentRows
              key={student.id}
              student={student}
              rate={rate}
              width={width}
              padding={padding}
            />
          ))}
          <tr className="pr-grand-total">
            {Array.from({ length: sessionColumns + 1 }, (_, i) => (
              <td key={i} />
            ))}
            <td style={{ textAlign: "right", textDecoration: "underline" }}>
              Total
            </td>
            <td style={{ textAlign: "right", textDecoration: "underline" }}>
              {reportTotal(report).toFixed(1)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  )
}

function StudentRows({
  student,
  rate,
  width,
  padding,
}: {
  student: Student
  rate: number
  width: number
  padding: (count: number) => ReactNode
}) {
  const { sessions } = student

  return (
    <>
      <tr className="pr-student-name">
        <td colSpan={width}>
          {student.name} – {student.subject}
        </td>
      </tr>
      <tr className="pr-label">
        <td>Day</td>
        {sessions.map((session) => (
          <td key={session.id} className="pr-center">
            {shortDate(session.date)}
          </td>
        ))}
        {padding(sessions.length)}
        <td />
        <td className="pr-right" style={{ fontSize: "9pt", color: "#555" }}>
          Total
        </td>
      </tr>
      <tr className="pr-label">
        <td>Start</td>
        {sessions.map((session) => (
          <td key={session.id} className="pr-center">
            {clockTime(session.startTime) || "—"}
          </td>
        ))}
        {padding(sessions.length)}
        <td colSpan={2} />
      </tr>
      <tr className="pr-label">
        <td>Hours</td>
        {sessions.map((session) => (
          <td key={session.id} className="pr-center">
            {session.hrs}
          </td>
        ))}
        {padding(sessions.length)}
        <td />
        <td className="pr-right">{studentTotal(student, rate).toFixed(1)}</td>
      </tr>
      <tr className="pr-spacer">
        <td colSpan={width} />
      </tr>
    </>
  )
}
