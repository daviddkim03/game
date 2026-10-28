import { useEffect, useState, type ReactNode } from "react"
import type { IconType } from "react-icons"
import {
  LuCalendarDays,
  LuLayoutDashboard,
  LuReceipt,
  LuTrendingUp,
} from "react-icons/lu"

import { AppHeader } from "@/components/app-header"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { CalendarTab } from "@/pages/tracker/calendar-tab"
import { DashboardTab } from "@/pages/tracker/dashboard-tab"
import { ExpensesTab } from "@/pages/tracker/expenses-tab"
import { IncomeTab } from "@/pages/tracker/income-tab"
import { MONTHS } from "@/pages/tracker/model"
import { useTracker, type TrackerApi } from "@/pages/tracker/use-tracker"

type TabId = "dashboard" | "income" | "expenses" | "calendar"

const TABS: {
  id: TabId
  label: string
  icon: IconType
  render: (api: TrackerApi) => ReactNode
}[] = [
  {
    id: "dashboard",
    label: "Dashboard",
    icon: LuLayoutDashboard,
    render: (api) => <DashboardTab {...api} />,
  },
  {
    id: "income",
    label: "Income",
    icon: LuTrendingUp,
    render: (api) => <IncomeTab {...api} />,
  },
  {
    id: "expenses",
    label: "Expenses",
    icon: LuReceipt,
    render: (api) => <ExpensesTab {...api} />,
  },
  {
    id: "calendar",
    label: "Calendar",
    icon: LuCalendarDays,
    render: (api) => <CalendarTab {...api} />,
  },
]

function tabFromHash(): TabId {
  const hash = location.hash.slice(1)
  return TABS.some((tab) => tab.id === hash) ? (hash as TabId) : "dashboard"
}

export function TrackerPage() {
  const api = useTracker()
  const [tab, setTab] = useState<TabId>(tabFromHash)
  const now = new Date()

  // The open tab lives in the URL, so reloads and bookmarks keep it.
  useEffect(() => {
    const onHashChange = () => setTab(tabFromHash())
    window.addEventListener("hashchange", onHashChange)
    return () => window.removeEventListener("hashchange", onHashChange)
  }, [])

  function selectTab(next: TabId) {
    setTab(next)
    history.replaceState(
      null,
      "",
      next === "dashboard" ? location.pathname : `#${next}`
    )
  }

  return (
    <div className="flex min-h-svh flex-col">
      <AppHeader current="tracker" />
      <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col gap-6 px-4 py-6 sm:px-6">
        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-2">
          <div>
            <h1 className="font-heading text-2xl font-semibold tracking-tight">
              GAME Tracker
            </h1>
            <p className="text-sm text-muted-foreground">
              {MONTHS[now.getMonth()]} {now.getFullYear()} · Income, expenses,
              and bills
            </p>
          </div>
        </div>
        <Tabs
          value={tab}
          onValueChange={(value) => selectTab(value as TabId)}
          className="gap-5"
        >
          <div>
            <TabsList>
              {TABS.map(({ id, label, icon: Icon }) => (
                <TabsTrigger
                  key={id}
                  value={id}
                  aria-label={label}
                  className="px-3 max-sm:px-2.5"
                >
                  <Icon />
                  <span className="max-sm:sr-only">{label}</span>
                </TabsTrigger>
              ))}
            </TabsList>
          </div>
          {TABS.map(({ id, render }) => (
            <TabsContent key={id} value={id}>
              {tab === id && render(api)}
            </TabsContent>
          ))}
        </Tabs>
      </main>
    </div>
  )
}
