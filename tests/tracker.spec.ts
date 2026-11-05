import type { Page } from "@playwright/test"

import type { TrackerData } from "../src/pages/tracker/model"
import { expect, readStorage, savedDocument, test } from "./fixtures"
import { sampleTracker } from "./sample-data"

const seeded = { storage: { game_tracker_v3: sampleTracker() } }
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

test("dashboard summarizes the budget", async ({ page, setup }) => {
  await setup(seeded)
  await page.goto("/game_tracker/")
  await expect(page.getByText("$4,130").first()).toBeVisible()
  await expect(page.getByText("56% of take-home saved")).toBeVisible()
  await page.getByLabel("Tax rate on taxed income").fill("20")
  await expect(page.getByText("After 20% tax on taxed income")).toBeVisible()
  await expect.poll(async () => (await stored(page))?.taxRate).toBe(0.2)
})

test("the open tab is kept in the URL", async ({ page, setup }) => {
  await setup(seeded)
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
  await setup(seeded)
  await page.goto("/game_tracker/#expenses")
  await page.getByRole("button", { name: "Add expense" }).click()
  const review = page.getByRole("region", { name: "Uncategorized" })
  await expect(review).toContainText("Review: assign a category")
  await review.getByLabel("Name").fill("Phone")
  await review.getByLabel("Monthly cost").fill("45")
  await review.getByRole("combobox", { name: "Category" }).click()
  await page.getByRole("option", { name: "Home" }).click()

  await expect(review).toHaveCount(0)
  const home = page.getByRole("region", { name: "Home" })
  await expect(home).toContainText("$1,330")
  await home.getByRole("button", { name: "Done" }).click()
  await expect(home.getByRole("row", { name: /Phone/ })).toBeVisible()
  await expect(page.getByText("$1,861")).toBeVisible()
  await expect
    .poll(() => expense(page, "Phone"))
    .toMatchObject({ cat: "Home", cost: 45 })
  await expect
    .poll(async () =>
      (await savedDocument<TrackerData>(page, "game_tracker"))?.expenses.find(
        (e) => e.name === "Phone"
      )
    )
    .toMatchObject({ cat: "Home", cost: 45 })
})

test("Enter in an editor field works like Done", async ({ page, setup }) => {
  await setup(seeded)
  await page.goto("/game_tracker/#expenses")
  const debt = page.getByRole("region", { name: "Debt" })
  const row = debt.getByRole("row", { name: /Insurance/ })
  const done = debt.getByRole("button", { name: "Done" })

  await row.click()
  await debt.getByLabel("Monthly cost").fill("75")
  await debt.getByLabel("Monthly cost").press("Enter")
  await expect(done).toBeHidden()
  await expect(row).toContainText("$75")
  await expect
    .poll(() => expense(page, "Insurance"))
    .toMatchObject({ cost: 75 })

  await row.click()
  await debt.getByLabel("Name").fill("Coverage")
  await debt.getByLabel("Name").press("Enter")
  await expect(done).toBeHidden()
  await expect(debt.getByRole("row", { name: /Coverage/ })).toBeVisible()

  // Enter on the editor's buttons and menus still does their own thing.
  await debt.getByRole("row", { name: /Coverage/ }).click()
  await debt.getByRole("button", { name: "Days of week" }).press("Enter")
  await expect(debt.getByRole("group", { name: "Payment days" })).toBeVisible()
  await debt.getByRole("combobox", { name: "Category" }).press("Enter")
  await expect(page.getByRole("listbox")).toBeVisible()
  await page.keyboard.press("Escape")
  await expect(done).toBeVisible()
})

test("dragging an expense onto another category moves it", async ({
  page,
  setup,
}) => {
  await setup(seeded)
  await page.goto("/game_tracker/#expenses")
  const handle = page.getByRole("button", { name: "Reorder Climbing" })
  const target = page
    .getByRole("region", { name: "Debt" })
    .getByRole("row", { name: /Insurance/ })
  await drag(page, await center(handle), await center(target))
  await expect(page.getByRole("region", { name: "Debt" })).toContainText(
    "Climbing"
  )
  await expect
    .poll(() => expense(page, "Climbing"))
    .toMatchObject({ cat: "Debt" })
})

test("calendar pills move to the day they are dropped on", async ({
  page,
  setup,
}) => {
  await setup(seeded)
  await page.goto("/game_tracker/#calendar")
  await expect(
    page.getByRole("heading", { name: "October 2026" })
  ).toBeVisible()
  const day = (n: number) => page.locator(`[data-day="${n}"]`)
  await expect(day(31)).toContainText("+$2,670")

  const car = day(12).locator("[data-pill=bill]", { hasText: "Car" })
  await drag(page, await center(car), await center(day(14)))
  await expect(
    day(14).locator("[data-pill=bill]", { hasText: "Car" })
  ).toBeVisible()
  await expect.poll(() => expense(page, "Car")).toMatchObject({ due: 14 })

  await page.getByRole("button", { name: "Next month" }).click()
  await expect(
    page.getByRole("heading", { name: "November 2026" })
  ).toBeVisible()
  await expect(
    day(14).locator("[data-pill=bill]", { hasText: "Car" })
  ).toBeVisible()
})

test("bills get a payment link from the calendar", async ({ page, setup }) => {
  await setup(seeded)
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
        expenses: [{ id: 2, name: "Rent", cat: "Home", cost: 1000, due: 1 }],
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
