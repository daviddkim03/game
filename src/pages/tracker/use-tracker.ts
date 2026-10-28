import { useCallback, useMemo } from "react"
import { produce, type Draft } from "immer"

import { useSyncedState } from "@/hooks/use-synced-state"
import { getApp } from "@/lib/apps"
import {
  defaultTracker,
  reviveTracker,
  STORAGE_KEY,
  summarize,
  type Summary,
  type TrackerData,
} from "@/pages/tracker/model"

export type Update = (recipe: (draft: Draft<TrackerData>) => void) => void

/** What every tab gets: the data, its derived numbers, and a way to edit it. */
export type TrackerApi = {
  data: TrackerData
  summary: Summary
  update: Update
}

export function useTracker(): TrackerApi {
  const [data, setData] = useSyncedState({
    pageId: getApp("tracker").syncId,
    storageKey: STORAGE_KEY,
    initial: defaultTracker,
    revive: reviveTracker,
  })
  const update = useCallback<Update>(
    (recipe) => setData(produce(recipe)),
    [setData]
  )
  const summary = useMemo(() => summarize(data), [data])
  return { data, summary, update }
}
