import type { Page } from "@playwright/test"

import type { TrackerData } from "../src/pages/tracker/model"
import { expect, readStorage, savedDocument, test } from "./fixtures"

const stored = (page: Page) => readStorage<TrackerData>(page, "game_tracker_v3")
const expense = async (page: Page, name: string) =>
  (await stored(page))?.expenses.find((e) => e.name === name)

/** Drags with real pointer moves so dnd-kit's 4px activation kicks in. */
async function drag(
  page: Page,
  from: { x: number; y: number },
  to: { x: number; y: number }
) {
  await page.mouse.move(from.x, from.y)
  await page.mouse.down()
  await page.mouse.move(from.x + 8, from.y + 8, { steps: 4 })
  await page.mouse.move(to.x, to.y, { steps: 12 })
  await page.mouse.up()
  // dnd-kit swallows clicks until a 50 ms timer after the drop; a later page
  // timer is guaranteed to run after it.
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 60)))
}

const center = async (locator: ReturnType<Page["locator"]>) => {
  const box = (await locator.boundingBox())!
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
}

test.beforeEach(async ({ page }) => {
  // October 2026 starts on a Thursday; the calendar assertions rely on it.
  await page.clock.setFixedTime(new Date(2026, 9, 28, 10))
})

test("dashboard summarizes the default budget", async ({ page, setup }) => {
  await setup({})
  await page.goto("/game_tracker/")
  await expect(page.getByText("$5,350").first()).toBeVisible()
  await expect(page.getByText("63% of take-home saved")).toBeVisible()
  await page.getByLabel("Tax rate on taxed income").fill("20")
  await expect(page.getByText("After 20% tax on taxed income")).toBeVisible()
  await expect.poll(async () => (await stored(page))?.taxRate).toBe(0.2)
})

test("the open tab is kept in the URL", async ({ page, setup }) => {
  await setup({})
  await page.goto("/game_tracker/#calendar")
  await expect(page.getByRole("tab", { name: "Calendar" })).toHaveAttribute(
    "aria-selected",
    "true"
  )
  await page.getByRole("tab", { name: "Expenses" }).click()
  await expect(page).toHaveURL(/#expenses$/)
  await page.reload()
  await expect(page.getByRole("tab", { name: "Expenses" })).toHaveAttribute(
    "aria-selected",
    "true"
  )
})

test("new expenses wait for review, then join their category", async ({
  page,
  setup,
}) => {
  await setup({})
  await page.goto("/game_tracker/#expenses")
  await page.getByRole("button", { name: "Add expense" }).click()
  const review = page.getByRole("region", { name: "Uncategorized" })
  await expect(review).toContainText("Review: assign a category")
  await review.getByLabel("Name").fill("Phone")
  await review.getByLabel("Monthly cost").fill("45")
  await review.getByRole("combobox", { name: "Category" }).click()
  await page.getByRole("option", { name: "Necessities" }).click()

  await expect(review).toHaveCount(0)
  const necessities = page.getByRole("region", { name: "Necessities" })
  await expect(necessities).toContainText("$1,130")
  await necessities.getByRole("button", { name: "Done" }).click()
  await expect(necessities.getByRole("row", { name: /Phone/ })).toBeVisible()
  await expect(page.getByText("$2,037")).toBeVisible()
  await expect
    .poll(() => expense(page, "Phone"))
    .toMatchObject({ cat: "Necessities", cost: 45 })
  await expect
    .poll(async () =>
      (await savedDocument<TrackerData>(page, "game_tracker"))?.expenses.find(
        (e) => e.name === "Phone"
      )
    )
    .toMatchObject({ cat: "Necessities", cost: 45 })
})

test("Enter in an editor field works like Done", async ({ page, setup }) => {
  await setup({})
  await page.goto("/game_tracker/#expenses")
  const loans = page.getByRole("region", { name: "Loans" })
  const row = loans.getByRole("row", { name: /Auto Ins/ })
  const done = loans.getByRole("button", { name: "Done" })

  await row.click()
  await loans.getByLabel("Monthly cost").fill("180")
  await loans.getByLabel("Monthly cost").press("Enter")
  await expect(done).toBeHidden()
  await expect(row).toContainText("$180")
  await expect
    .poll(() => expense(page, "Auto Ins"))
    .toMatchObject({ cost: 180 })

  await row.click()
  await loans.getByLabel("Name").fill("Car insurance")
  await loans.getByLabel("Name").press("Enter")
  await expect(done).toBeHidden()
  await expect(loans.getByRole("row", { name: /Car insurance/ })).toBeVisible()

  // Enter on the editor's buttons and menus still does their own thing.
  await loans.getByRole("row", { name: /Car insurance/ }).click()
  await loans.getByRole("button", { name: "Days of week" }).press("Enter")
  await expect(loans.getByRole("group", { name: "Payment days" })).toBeVisible()
  await loans.getByRole("combobox", { name: "Category" }).press("Enter")
  await expect(page.getByRole("listbox")).toBeVisible()
  await page.keyboard.press("Escape")
  await expect(done).toBeVisible()
})

test("dragging an expense onto another category moves it", async ({
  page,
  setup,
}) => {
  await setup({})
  await page.goto("/game_tracker/#expenses")
  const handle = page.getByRole("button", { name: "Reorder Gym" })
  const target = page
    .getByRole("region", { name: "Loans" })
    .getByRole("row", { name: /Auto Ins/ })
  await drag(page, await center(handle), await center(target))
  await expect(page.getByRole("region", { name: "Loans" })).toContainText("Gym")
  await expect.poll(() => expense(page, "Gym")).toMatchObject({ cat: "Loans" })
})

test("calendar pills move to the day they are dropped on", async ({
  page,
  setup,
}) => {
  await setup({})
  await page.goto("/game_tracker/#calendar")
  await expect(
    page.getByRole("heading", { name: "October 2026" })
  ).toBeVisible()
  const day = (n: number) => page.locator(`[data-day="${n}"]`)
  await expect(day(31)).toContainText("+$3,382")

  const auto = day(12).locator("[data-pill=bill]", { hasText: "Auto" })
  await drag(page, await center(auto), await center(day(14)))
  await expect(
    day(14).locator("[data-pill=bill]", { hasText: "Auto" })
  ).toBeVisible()
  await expect.poll(() => expense(page, "Auto")).toMatchObject({ due: 14 })

  await page.getByRole("button", { name: "Next month" }).click()
  await expect(
    page.getByRole("heading", { name: "November 2026" })
  ).toBeVisible()
  await expect(
    day(14).locator("[data-pill=bill]", { hasText: "Auto" })
  ).toBeVisible()
})

test("bills get a payment link from the calendar", async ({ page, setup }) => {
  await setup({})
  await page.goto("/game_tracker/#calendar")
  await page
    .locator('[data-day="1"] [data-pill=bill]', { hasText: "Rent" })
    .click({ button: "right" })
  const dialog = page.getByRole("dialog", { name: "Rent" })
  await dialog.getByLabel("Payment site").fill("rent.example.com")
  await dialog.getByRole("button", { name: "Save" }).click()
  await expect(dialog).toBeHidden()

  const link = page.getByRole("link", {
    name: "Open the payment site for Rent",
  })
  await expect(link).toHaveAttribute("href", "https://rent.example.com")
  await expect
    .poll(() => expense(page, "Rent"))
    .toMatchObject({ paymentLink: "rent.example.com" })
})

test("data saved by the previous version still loads", async ({
  page,
  setup,
}) => {
  await setup({
    storage: {
      game_tracker_v3: {
        taxRate: 0.25,
        income: [
          {
            id: 1,
            name: "Job",
            type: "Taxed",
            monthly: 4000,
            rate: null,
            payday: "1st & 15th",
          },
        ],
        expenses: [
          { id: 2, name: "Rent", cat: "Necessities", cost: 1000, due: 1 },
        ],
        nextId: 3,
      },
    },
  })
  await page.goto("/game_tracker/#income")
  const other = page.getByRole("region", { name: "Other" })
  await expect(other.getByRole("row", { name: /Job/ })).toContainText(
    "1st, 15th"
  )
  await page.getByRole("tab", { name: "Dashboard" }).click()
  await expect(page.getByText("$2,000").first()).toBeVisible()
})

test("the cloud copy wins when the page opens", async ({ page, setup }) => {
  await setup({
    cloud: { game_tracker: { taxRate: 0.1, nextId: 20 } },
  })
  await page.goto("/game_tracker/")
  await expect(page.getByText("After 10% tax on taxed income")).toBeVisible()
  await expect.poll(async () => (await stored(page))?.taxRate).toBe(0.1)
})
