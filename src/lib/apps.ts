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
  shortName: string
  description: string
  tag: string
  icon: IconType
}

export const apps: AppInfo[] = [
  {
    id: "tracker",
    path: "game_tracker/",
    syncId: "game_tracker",
    name: "GAME Tracker",
    shortName: "GAME",
    description:
      "Track income sources, expenses by category, savings rate, and bill due dates on a live calendar.",
    tag: "Finance",
    icon: LuWallet,
  },
  {
    id: "schedule",
    path: "schedule/",
    syncId: "schedule",
    name: "Weekly Schedule",
    shortName: "Schedule",
    description:
      "Build your weekly routine with color-coded time blocks. Drag to create, move, and copy across days.",
    tag: "Planning",
    icon: LuCalendarClock,
  },
  {
    id: "payment",
    path: "payment/",
    syncId: "payment_report",
    name: "Payment Report",
    shortName: "Billing",
    description:
      "Log tutoring sessions, calculate totals by hourly rate, and export clean PDF reports.",
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
