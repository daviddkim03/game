import type { IconType } from "react-icons"
import { LuCalendarClock, LuReceiptText, LuWallet } from "react-icons/lu"

export type AppId = "tracker" | "schedule" | "payment"

export type AppInfo = {
  id: AppId
  /** Folder under the site root; it is also the page's public URL. */
  path: string
  /** Cloud document the page syncs (personal_app_state/main_<syncId>). */
  syncId: string
  name: string
  /** Short label on the home page card. */
  tag: string
  icon: IconType
}

export const apps: AppInfo[] = [
  {
    id: "tracker",
    path: "game_tracker/",
    syncId: "game_tracker",
    name: "GAME Tracker",
    tag: "Finance",
    icon: LuWallet,
  },
  {
    id: "schedule",
    path: "schedule/",
    syncId: "schedule",
    name: "Weekly Schedule",
    tag: "Planning",
    icon: LuCalendarClock,
  },
  {
    id: "payment",
    path: "payment/",
    syncId: "payment_report",
    name: "Payment Report",
    tag: "Billing",
    icon: LuReceiptText,
  },
]

/** Relative link to the site root from the current page (app pages sit one folder deep). */
export function rootHref(current?: AppId) {
  return current ? "../" : "./"
}

export function appHref(app: AppInfo, current?: AppId) {
  return rootHref(current) + app.path
}

export function getApp(id: AppId) {
  return apps.find((app) => app.id === id)!
}
