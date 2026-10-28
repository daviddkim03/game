import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type SetStateAction,
} from "react"

import {
  loadDocument,
  saveDocument,
  subscribeDocument,
  syncEnabled,
} from "@/lib/sync"

type SyncedStateOptions<T> = {
  /** Firestore document suffix, e.g. "schedule" -> personal_app_state/main_schedule. */
  pageId: string
  /** localStorage key that caches the document on this device. */
  storageKey: string
  initial: () => T
  /**
   * Turns stored or cloud data (possibly written by older versions) into
   * current state, or returns null when it is unusable. Must be stable.
   */
  revive: (raw: unknown) => T | null
}

function readLocal<T>(key: string, revive: (raw: unknown) => T | null) {
  try {
    const raw = localStorage.getItem(key)
    return raw ? revive(JSON.parse(raw)) : null
  } catch {
    return null
  }
}

/**
 * State that is cached in localStorage and synced to the cloud.
 *
 * The cloud copy is the source of truth when the page opens. After that, every
 * change is saved locally right away and sent to the cloud, one write at a
 * time with the newest state winning. Changes from other devices stream in.
 */
export function useSyncedState<T>({
  pageId,
  storageKey,
  initial,
  revive,
}: SyncedStateOptions<T>) {
  const [state, setState] = useState<T>(
    () => readLocal(storageKey, revive) ?? initial()
  )
  const [cloudReady, setCloudReady] = useState(false)
  const editedLocally = useRef(false)
  const [saver] = useState(() => createSaver(pageId))

  const update = useCallback((action: SetStateAction<T>) => {
    editedLocally.current = true
    setState(action)
  }, [])

  useEffect(() => {
    try {
      localStorage.setItem(storageKey, JSON.stringify(state))
    } catch {
      // Storage can be full or blocked; the cloud copy still works.
    }
    if (cloudReady) saver.push(state)
  }, [state, cloudReady, storageKey, saver])

  useEffect(() => {
    if (!syncEnabled) return
    let stopped = false
    let unsubscribe = () => {}

    async function connect() {
      try {
        const data = await loadDocument(pageId)
        if (stopped) return
        const remote = data == null ? null : revive(data)
        // Edits made while the cloud copy was still loading (e.g. offline)
        // are newer than it, so they win and get uploaded instead.
        if (remote && !editedLocally.current) setState(remote)
        setCloudReady(true)
        unsubscribe = subscribeDocument(pageId, (incoming) => {
          const next = revive(incoming)
          if (next) setState(next)
        })
      } catch {
        if (!stopped) window.addEventListener("online", connect, { once: true })
      }
    }

    void connect()
    return () => {
      stopped = true
      unsubscribe()
      window.removeEventListener("online", connect)
    }
  }, [pageId, revive])

  return [state, update] as const
}

/** Sends at most one write at a time; later states replace queued ones. */
function createSaver(pageId: string) {
  let queued: { data: unknown } | null = null
  let running = false

  async function drain() {
    running = true
    while (queued) {
      const { data } = queued
      queued = null
      await saveDocument(pageId, data)
    }
    running = false
  }

  return {
    push(data: unknown) {
      queued = { data }
      if (!running) void drain()
    },
  }
}
