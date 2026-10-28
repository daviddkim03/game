import { describe, expect, it } from "vitest"

import {
  clockTime,
  defaultReport,
  reportHours,
  reportTotal,
  reviveReport,
  shortDate,
  studentTotal,
} from "@/pages/payment/model"

describe("payment report", () => {
  it("totals hours at the hourly rate", () => {
    const report = defaultReport()
    expect(reportHours(report)).toBe(8.5)
    expect(reportTotal(report)).toBe(340)
    expect(studentTotal(report.students[2], report.rate)).toBe(60)
  })

  it("fills in missing fields and numbers from saved reports", () => {
    const revived = reviveReport({
      name: "Tutor",
      rate: "45",
      students: [
        {
          id: 1,
          name: "A",
          subject: "Math",
          sessions: [{ id: 2, date: "", hrs: "1.5" }],
        },
      ],
    })!
    expect(revived.rate).toBe(45)
    expect(revived.every).toBe("10th & 25th")
    expect(revived.students[0].sessions[0]).toEqual({
      id: 2,
      date: "",
      startTime: "",
      hrs: 1.5,
    })
  })

  it("formats dates and times like the printed report", () => {
    expect(shortDate("2026-05-02")).toBe("5/2")
    expect(clockTime("14:00")).toBe("2:00 PM")
    expect(clockTime("00:30")).toBe("12:30 AM")
    expect(clockTime("")).toBe("")
  })
})
