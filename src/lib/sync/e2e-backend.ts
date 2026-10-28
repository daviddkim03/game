import type { AuthUser, SyncBackend } from "./types"

/**
 * In-memory stand-in for Firebase used by the Playwright suite (`--mode e2e`).
 * Tests seed and inspect it through `window.__e2e`.
 */
export type E2EHarness = {
  /** Cloud documents returned by `load`, keyed by page id. */
  cloud?: Record<string, unknown>
  /** Last document saved per page id. */
  saved?: Record<string, unknown>
  /** Pushes a remote change into the page, like another device would. */
  receive?: Record<string, (data: unknown) => void>
  signedOut?: boolean
}

declare global {
  interface Window {
    __e2e?: E2EHarness
  }
}

const TEST_USER: AuthUser = { uid: "e2e", email: "admin@app.local" }

export function createE2EBackend(): SyncBackend {
  const harness = (window.__e2e ??= {})
  const authListeners = new Set<(user: AuthUser | null) => void>()
  let user: AuthUser | null = harness.signedOut ? null : TEST_USER

  return {
    watchAuth(listener) {
      authListeners.add(listener)
      queueMicrotask(() => listener(user))
      return () => authListeners.delete(listener)
    },
    async signIn(email, password) {
      if (!email || password !== "password") {
        throw Object.assign(new Error("Invalid credentials"), {
          code: "auth/invalid-credential",
        })
      }
      user = { uid: "e2e", email }
      authListeners.forEach((listener) => listener(user))
    },
    async signOut() {
      user = null
      authListeners.forEach((listener) => listener(user))
    },
    async load(pageId) {
      return structuredClone(harness.cloud?.[pageId] ?? null)
    },
    async save(pageId, data) {
      harness.saved = { ...harness.saved, [pageId]: structuredClone(data) }
    },
    subscribe(pageId, onData) {
      harness.receive = { ...harness.receive, [pageId]: onData }
      return () => {
        if (harness.receive?.[pageId] === onData) delete harness.receive[pageId]
      }
    },
  }
}
