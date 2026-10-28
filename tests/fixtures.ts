import { expect, test as base, type Page } from "@playwright/test"

import type { E2EHarness } from "../src/lib/sync/e2e-backend"

export type Setup = {
  /** Documents the fake cloud returns on load, keyed by page id. */
  cloud?: Record<string, unknown>
  /** localStorage entries to seed before the page's scripts run. */
  storage?: Record<string, unknown>
  signedOut?: boolean
}

export type SetupFn = (setup: Setup) => Promise<void>

export const test = base.extend<{ setup: SetupFn }>({
  page: async ({ page }, use) => {
    const errors: Error[] = []
    page.on("pageerror", (error) => errors.push(error))
    await use(page)
    expect(errors, "uncaught page errors").toEqual([])
  },
  setup: async ({ page }, use) => {
    await use(async ({ cloud = {}, storage = {}, signedOut = false }) => {
      await page.addInitScript(
        ({ cloud, storage, signedOut }) => {
          const harness: E2EHarness = { cloud, signedOut }
          window.__e2e = harness
          for (const [key, value] of Object.entries(storage)) {
            // Only seed the first load, so reloads see what the page saved.
            if (localStorage.getItem(key) === null) {
              localStorage.setItem(key, JSON.stringify(value))
            }
          }
        },
        { cloud, storage, signedOut }
      )
    })
  },
})

export { expect }

/** The document most recently synced to the (fake) cloud for a page. */
export function savedDocument<T>(page: Page, pageId: string) {
  return page.evaluate(
    (id) => window.__e2e?.saved?.[id] ?? null,
    pageId
  ) as Promise<T>
}

/** Simulates a change arriving from another device. */
export async function receiveRemote(page: Page, pageId: string, data: unknown) {
  await page.evaluate(({ id, data }) => window.__e2e?.receive?.[id]?.(data), {
    id: pageId,
    data,
  })
}

export function readStorage<T>(page: Page, key: string) {
  return page.evaluate(
    (key) => JSON.parse(localStorage.getItem(key) ?? "null"),
    key
  ) as Promise<T>
}
