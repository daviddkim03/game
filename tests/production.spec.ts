import { expect, test } from "@playwright/test"

// Catches problems the e2e build cannot, such as Firebase failing to start
// (for example when two copies of @firebase/app end up in the bundle).
for (const path of ["/", "/game_tracker/", "/schedule/", "/payment/"]) {
  test(`the production build boots to sign-in at ${path}`, async ({ page }) => {
    const errors: Error[] = []
    page.on("pageerror", (error) => errors.push(error))
    await page.goto(path)
    await expect(page.getByRole("button", { name: "Sign in" })).toBeVisible()
    await expect(page.getByLabel("Email")).toBeFocused()
    expect(errors).toEqual([])
  })
}
