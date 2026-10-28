import { useSyncExternalStore } from "react"

import { toast } from "@/components/ui/toast"
import { firebaseConfig, firebaseLoginUsers } from "@/lib/firebase-config"
import { createE2EBackend } from "@/lib/sync/e2e-backend"
import { createFirebaseBackend } from "@/lib/sync/firebase-backend"
import type { AuthUser, SyncBackend } from "@/lib/sync/types"

const PLACEHOLDER = /^(PASTE_|YOUR_)|firebase_project_id/i

/** False when firebase-config.ts still holds placeholders: pages then stay local-only. */
export const syncEnabled =
  import.meta.env.MODE === "e2e" ||
  [firebaseConfig.apiKey, firebaseConfig.projectId, firebaseConfig.appId].every(
    (value) => value && !PLACEHOLDER.test(value)
  )

let backendInstance: SyncBackend | null = null
function backend() {
  backendInstance ??=
    import.meta.env.MODE === "e2e"
      ? createE2EBackend()
      : createFirebaseBackend()
  return backendInstance
}

/* ── Small observable stores ─────────────────────────────────────────── */

function createStore<T>(initial: T) {
  let value = initial
  const listeners = new Set<() => void>()
  return {
    get: () => value,
    set(next: T) {
      value = next
      listeners.forEach((listener) => listener())
    },
    subscribe(listener: () => void) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
  }
}

/* ── Auth ────────────────────────────────────────────────────────────── */

export type AuthState =
  | { status: "local" }
  | { status: "loading" }
  | { status: "signed-out" }
  | { status: "signed-in"; user: AuthUser }

const authStore = createStore<AuthState>(
  syncEnabled ? { status: "loading" } : { status: "local" }
)
let authWatched = false

function subscribeAuth(listener: () => void) {
  if (syncEnabled && !authWatched) {
    authWatched = true
    backend().watchAuth((user) =>
      authStore.set(
        user ? { status: "signed-in", user } : { status: "signed-out" }
      )
    )
  }
  return authStore.subscribe(listener)
}

export function useAuth() {
  return useSyncExternalStore(subscribeAuth, authStore.get)
}

/** Shows an alias from firebase-config.ts (e.g. "admin") instead of the email. */
export function displayName(user: AuthUser) {
  const alias = Object.entries(firebaseLoginUsers).find(
    ([, email]) => email === user.email
  )?.[0]
  return alias ?? user.email ?? "Signed in"
}

export async function signIn(username: string, password: string) {
  const key = username.trim()
  const email = firebaseLoginUsers[key] ?? key
  if (!email || !password) {
    throw new Error("Enter your Firebase Auth email and password.")
  }
  try {
    await backend().signIn(email, password)
  } catch (error) {
    throw new Error(authErrorMessage(error), { cause: error })
  }
}

export async function signOut() {
  await backend().signOut()
  // Start clean rather than keep the previous account's data in memory.
  location.reload()
}

function authErrorMessage(error: unknown) {
  const code = (error as { code?: string } | null)?.code ?? ""
  const suffix = code ? ` (${code})` : ""
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return `Sign-in failed. Check that this email exists in Firebase Authentication and the password is correct.${suffix}`
    case "auth/operation-not-allowed":
      return `Email/password sign-in is not enabled in Firebase Authentication.${suffix}`
    case "auth/invalid-email":
      return `Enter the full Firebase Auth email address.${suffix}`
    case "auth/unauthorized-domain":
      return `This website's domain is not authorized in Firebase Authentication settings.${suffix}`
    case "auth/network-request-failed":
      return `Firebase Auth could not reach the network.${suffix}`
    case "auth/too-many-requests":
      return `Too many attempts. Wait a moment and try again.${suffix}`
    default:
      return `${error instanceof Error ? error.message : String(error)}${suffix}`
  }
}

/* ── Per-page sync status ────────────────────────────────────────────── */

export type SyncPhase = "local" | "connecting" | "saving" | "synced" | "error"

export type SyncStatus = {
  phase: SyncPhase
  /** Short label for the header. */
  label: string
  /** Longer explanation for the tooltip. */
  detail: string
  at: number
}

const statusStores = new Map<
  string,
  ReturnType<typeof createStore<SyncStatus>>
>()

function statusStore(pageId: string) {
  let store = statusStores.get(pageId)
  if (!store) {
    store = createStore<SyncStatus>(
      syncEnabled
        ? {
            phase: "connecting",
            label: "Connecting",
            detail: "Loading your data from the cloud.",
            at: Date.now(),
          }
        : {
            phase: "local",
            label: "Saved locally",
            detail:
              "Cloud sync is not configured, so data stays in this browser.",
            at: Date.now(),
          }
    )
    statusStores.set(pageId, store)
  }
  return store
}

function setStatus(
  pageId: string,
  phase: SyncPhase,
  label: string,
  detail: string
) {
  const store = statusStore(pageId)
  const wasError = store.get().phase === "error"
  store.set({ phase, label, detail, at: Date.now() })
  if (phase === "error" && !wasError) {
    toast.add({ type: "error", title: label, description: detail })
  }
}

export function useSyncStatus(pageId: string) {
  const store = statusStore(pageId)
  return useSyncExternalStore(store.subscribe, store.get)
}

/* ── Documents ───────────────────────────────────────────────────────── */

/** JSON with sorted keys, so documents compare equal regardless of key order. */
function canonical(value: unknown) {
  return JSON.stringify(value, (_key, v: unknown) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(
          Object.entries(v).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
        )
      : v
  )
}

/** What the cloud holds for each page, as far as this tab knows. */
const cloudCopies = new Map<string, string>()

function errorDetail(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

export async function loadDocument(pageId: string) {
  try {
    const data = await backend().load(pageId)
    if (data != null) cloudCopies.set(pageId, canonical(data))
    setStatus(
      pageId,
      "synced",
      "Synced",
      "Your data is up to date across devices."
    )
    return data
  } catch (error) {
    setStatus(
      pageId,
      "error",
      "Cloud sync unavailable",
      `Changes are saved on this device and will sync when the connection is back. ${errorDetail(error)}`
    )
    throw error
  }
}

/** Saves to the cloud unless the cloud already holds exactly this data. */
export async function saveDocument(pageId: string, data: unknown) {
  const copy = canonical(data)
  const previous = cloudCopies.get(pageId)
  if (previous === copy) return
  // Record it before the write resolves so the server echo is recognized.
  cloudCopies.set(pageId, copy)
  setStatus(
    pageId,
    "saving",
    "Saving",
    "Saving your latest changes to the cloud."
  )
  try {
    await backend().save(pageId, JSON.parse(copy))
    if (cloudCopies.get(pageId) === copy) {
      setStatus(
        pageId,
        "synced",
        "Synced",
        "Your data is up to date across devices."
      )
    }
  } catch (error) {
    if (cloudCopies.get(pageId) === copy) {
      if (previous === undefined) cloudCopies.delete(pageId)
      else cloudCopies.set(pageId, previous)
    }
    setStatus(
      pageId,
      "error",
      "Cloud save failed",
      `Your changes are saved on this device. ${errorDetail(error)}`
    )
  }
}

/** Calls `onData` for changes made on other devices. */
export function subscribeDocument(
  pageId: string,
  onData: (data: unknown) => void
) {
  return backend().subscribe(
    pageId,
    (data) => {
      const copy = canonical(data)
      if (cloudCopies.get(pageId) === copy) return
      cloudCopies.set(pageId, copy)
      setStatus(
        pageId,
        "synced",
        "Synced",
        "Received an update from another device."
      )
      onData(data)
    },
    (error) =>
      setStatus(
        pageId,
        "error",
        "Live sync stopped",
        `Reload the page to reconnect. ${errorDetail(error)}`
      )
  )
}
