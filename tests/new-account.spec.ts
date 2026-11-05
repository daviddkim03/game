import type { Page } from "@playwright/test"

import type { PaymentReport } from "../src/pages/payment/model"
import type { TrackerData } from "../src/pages/tracker/model"
import { expect, readStorage, savedDocument, test } from "./fixtures"
import { sampleReport, sampleTracker } from "./sample-data"

const budget = (page: Page) => readStorage<TrackerData>(page, "game_tracker_v3")
const report = (page: Page) => readStorage<PaymentReport>(page, "payment_v2")

test("the budget starts empty and can be filled in", async ({
  page,
  setup,
}) => {
  await setup({})
  await page.goto("/game_tracker/")
  await expect(page.getByText("0% of take-home saved")).toBeVisible()
  await expect(page.getByText("No income or expenses yet.")).toBeVisible()

  await page.getByRole("tab", { name: "Expenses" }).click()
  await expect(page.getByText("No expenses yet", { exact: true })).toBeVisible()
  await page.getByRole("button", { name: "Category" }).click()
  const dialog = page.getByRole("dialog")
  await dialog.getByLabel("Name").fill("Home")
  await dialog.getByRole("button", { name: "Add category" }).click()

  const home = page.getByRole("region", { name: "Home" })
  await home.getByRole("button", { name: "Expense" }).click()
  await home.getByLabel("Name").fill("Rent")
  await home.getByLabel("Monthly cost").fill("900")
  await home.getByRole("button", { name: "Done" }).click()
  await expect(home.getByRole("row", { name: /Rent/ })).toContainText("$900")

  await page.getByRole("tab", { name: "Dashboard" }).click()
  await expect(page.getByText("No income or expenses yet.")).toBeHidden()
  await expect
    .poll(async () =>
      (await savedDocument<TrackerData>(page, "game_tracker"))?.expenses.at(0)
    )
    .toMatchObject({ id: 1, name: "Rent", cat: "Home", cost: 900 })
})

test("the report starts blank", async ({ page, setup }) => {
  await setup({})
  await page.goto("/payment/")
  await expect(page.getByRole("heading", { name: "Tutor" })).toBeVisible()
  await expect(page.getByText("No students yet")).toBeVisible()
  await page.emulateMedia({ media: "print" })
  await expect(page.locator(".print-report")).toContainText("Tutor (?-?)")
})

test("a new device shows the cloud copy and leaves it alone", async ({
  page,
  setup,
}) => {
  await setup({
    cloud: { game_tracker: sampleTracker(), payment_report: sampleReport() },
  })

  await page.goto("/game_tracker/")
  await expect(page.getByText("$4,130").first()).toBeVisible()
  await expect.poll(() => budget(page)).toEqual(sampleTracker())
  expect(await savedDocument(page, "game_tracker")).toBeNull()

  await page.goto("/payment/")
  await expect(page.getByRole("heading", { name: /Sam Lee/ })).toBeVisible()
  await expect.poll(() => report(page)).toEqual(sampleReport())
  expect(await savedDocument(page, "payment_report")).toBeNull()
})

test("a new device that can't reach the cloud uploads nothing", async ({
  page,
  setup,
}) => {
  await setup({ loadFails: true })
  await page.goto("/game_tracker/")
  await expect(page.getByText("Cloud sync unavailable").first()).toBeVisible()
  await page.getByLabel("Tax rate on taxed income").fill("20")
  await expect.poll(async () => (await budget(page))?.taxRate).toBe(0.2)
  expect(await savedDocument(page, "game_tracker")).toBeNull()
})
