import type { Page } from "@playwright/test"

import type { PaymentReport } from "../src/pages/payment/model"
import { expect, readStorage, savedDocument, test } from "./fixtures"

const stored = (page: Page) => readStorage<PaymentReport>(page, "payment_v2")

test.beforeEach(async ({ page, setup }) => {
  await setup({})
  await page.goto("/payment/")
  await expect(page.getByRole("heading", { name: /David Kim/ })).toBeVisible()
})

test("shows the report totals", async ({ page }) => {
  await expect(page.getByText("$340.00")).toBeVisible()
  await expect(page.getByText("8.5h × $40.00/hr · 3 students")).toBeVisible()
})

test("adds a student and a session, then saves and syncs", async ({ page }) => {
  await page.getByRole("button", { name: "Add student" }).first().click()
  const dialog = page.getByRole("dialog")
  await dialog.getByRole("button", { name: "Add student" }).click()
  await expect(dialog.getByText("Enter the student's name.")).toBeVisible()
  await dialog.getByLabel("Student name").fill("Mina")
  await dialog.getByLabel("Subject").fill("AP Calc")
  await dialog.getByRole("button", { name: "Add student" }).click()
  await expect(dialog).toBeHidden()

  const card = page.locator("#student-10")
  await expect(card.getByText("Mina")).toBeVisible()
  await card.getByRole("button", { name: "Add session" }).click()
  await card.getByRole("spinbutton", { name: "Session 1 hours" }).fill("2.5")
  await expect(card.getByText("$100.00").first()).toBeVisible()
  await expect(page.getByText("$440.00")).toBeVisible()

  const expected = {
    id: 10,
    name: "Mina",
    subject: "AP Calc",
    sessions: [{ id: 11, date: "", startTime: "", hrs: 2.5 }],
  }
  await expect
    .poll(async () => (await stored(page)).students.at(-1))
    .toEqual(expected)
  await expect
    .poll(async () =>
      (await savedDocument<PaymentReport>(page, "payment_report"))?.students.at(
        -1
      )
    )
    .toEqual(expected)

  await page.reload()
  await expect(page.locator("#student-10").getByText("AP Calc")).toBeVisible()
})

test("picks session dates from the calendar", async ({ page }) => {
  const ian = page.locator("#student-1")
  await ian.getByRole("button", { name: "Session 1 date" }).click()
  await page.getByRole("button", { name: /May 5th, 2026/ }).click()
  await expect(ian.getByRole("button", { name: "Session 1 date" })).toHaveText(
    "May 5, 2026"
  )
  await expect
    .poll(async () => (await stored(page)).students[0].sessions[0].date)
    .toBe("2026-05-05")
})

test("removes a student after confirming", async ({ page }) => {
  await page.getByRole("button", { name: "Remove Siwoo" }).click()
  const confirm = page.getByRole("alertdialog")
  await expect(confirm).toContainText("Remove Siwoo?")
  await confirm.getByRole("button", { name: "Cancel" }).click()
  await expect(page.locator("#student-2")).toBeVisible()

  await page.getByRole("button", { name: "Remove Siwoo" }).click()
  await page
    .getByRole("alertdialog")
    .getByRole("button", { name: "Remove" })
    .click()
  await expect(page.locator("#student-2")).toHaveCount(0)
  await expect(page.getByText("$220.00").first()).toBeVisible()
})

test("prints only the spreadsheet report", async ({ page }) => {
  await page.emulateMedia({ media: "print" })
  const printout = page.locator(".print-report")
  await expect(printout).toBeVisible()
  await expect(page.getByRole("main")).toBeHidden()
  await expect(printout).toContainText("David Kim (4/26-5/10)")
  await expect(printout).toContainText("Ian – SAT MATH")
  await expect(printout.locator("tr").last()).toContainText("340.0")
})
