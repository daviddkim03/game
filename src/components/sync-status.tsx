import { useSyncExternalStore } from "react"
import type { IconType } from "react-icons"
import {
  LuCloud,
  LuCloudAlert,
  LuCloudOff,
  LuCloudUpload,
  LuHardDrive,
  LuLoaderCircle,
} from "react-icons/lu"

import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"
import { useSyncStatus, type SyncPhase } from "@/lib/sync"

const ICONS: Record<SyncPhase, IconType> = {
  local: LuHardDrive,
  connecting: LuLoaderCircle,
  saving: LuCloudUpload,
  synced: LuCloud,
  error: LuCloudAlert,
}

function subscribeOnline(listener: () => void) {
  window.addEventListener("online", listener)
  window.addEventListener("offline", listener)
  return () => {
    window.removeEventListener("online", listener)
    window.removeEventListener("offline", listener)
  }
}

function useOnline() {
  return useSyncExternalStore(subscribeOnline, () => navigator.onLine)
}

/** Compact cloud-sync indicator for the header; details live in the tooltip. */
export function SyncStatus({ pageId }: { pageId: string }) {
  const status = useSyncStatus(pageId)
  const online = useOnline()
  const offline = !online && status.phase !== "local"

  const Icon = offline ? LuCloudOff : ICONS[status.phase]
  const label = offline ? "Offline" : status.label
  const detail = offline
    ? "You're offline. Changes are saved on this device and sync when you're back online."
    : status.detail
  const time = new Date(status.at).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  })

  return (
    <Tooltip>
      <TooltipTrigger
        render={
          <span
            role="status"
            tabIndex={0}
            data-phase={offline ? "offline" : status.phase}
            className="inline-flex h-8 items-center gap-1.5 rounded-lg px-2 text-xs text-muted-foreground outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
          />
        }
      >
        <Icon
          aria-hidden
          className={cn(
            "size-4 shrink-0",
            status.phase === "connecting" && !offline && "animate-spin",
            status.phase === "saving" && !offline && "animate-pulse",
            status.phase === "error" && !offline && "text-destructive"
          )}
        />
        <span className="hidden md:inline">{label}</span>
      </TooltipTrigger>
      <TooltipContent side="bottom" className="flex-col items-start gap-0.5">
        <span className="font-medium">{label}</span>
        <span className="opacity-80">{detail}</span>
        <span className="opacity-60">Updated {time}</span>
      </TooltipContent>
    </Tooltip>
  )
}
