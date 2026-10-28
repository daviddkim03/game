import { expect, test } from "./fixtures"

test("links to every tool", async ({ page, setup }) => {
  await setup({})
  await page.goto("/")
  const tools = page
    .getByRole("navigation", { name: "Tools" })
    .getByRole("link")
  await expect(tools).toHaveCount(3)
  await expect(tools.nth(0)).toHaveAttribute("href", "./game_tracker/")
  await expect(tools.nth(1)).toHaveAttribute("href", "./schedule/")
  await expect(tools.nth(2)).toHaveAttribute("href", "./payment/")

  await tools.filter({ hasText: "Weekly Schedule" }).click()
  await expect(page).toHaveURL(/\/schedule\/$/)
  await page.getByRole("button", { name: "Weekly Schedule" }).click()
  await page.getByRole("menuitem", { name: /Payment Report/ }).click()
  await expect(page).toHaveURL(/\/payment\/$/)
  await expect(page.getByRole("heading", { name: /David Kim/ })).toBeVisible()
})

test("asks signed-out visitors to sign in before showing anything", async ({
  page,
  setup,
}) => {
  await setup({ signedOut: true })
  await page.goto("/schedule/")
  await expect(page.getByText("Sign in", { exact: true }).first()).toBeVisible()
  await expect(page.locator("[data-slot=day-column]")).toHaveCount(0)

  await page.getByLabel("Email").fill("admin")
  await page.getByLabel("Password").fill("wrong")
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page.getByRole("alert")).toContainText("Sign-in failed")

  await page.getByLabel("Password").fill("password")
  await page.getByRole("button", { name: "Sign in" }).click()
  await expect(page.locator("[data-slot=day-column]")).toHaveCount(7)
  await page.getByRole("button", { name: "Account" }).click()
  await expect(page.getByRole("menu")).toContainText("admin@app.local")
})

test("remembers the chosen theme across pages", async ({ page, setup }) => {
  await setup({})
  await page.emulateMedia({ colorScheme: "light" })
  await page.goto("/")
  await expect(page.locator("html")).toHaveClass(/light/)
  await page.getByRole("button", { name: "Theme" }).click()
  await page.getByRole("menuitemradio", { name: "Dark" }).click()
  await expect(page.locator("html")).toHaveClass(/dark/)
  await page.goto("/payment/")
  await expect(page.locator("html")).toHaveClass(/dark/)
})
