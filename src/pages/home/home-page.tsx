import { LuArrowUpRight } from "react-icons/lu"

import { AppHeader } from "@/components/app-header"
import { appHref, apps } from "@/lib/apps"

export function HomePage() {
  const today = new Date().toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  })

  return (
    <div className="flex min-h-svh flex-col">
      <AppHeader />
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col justify-center gap-3 px-4 py-12 sm:px-6">
        <p className="text-sm text-muted-foreground">{today}</p>
        <nav aria-label="Tools" className="grid gap-3 sm:grid-cols-3">
          {apps.map((app) => (
            <a
              key={app.id}
              href={appHref(app)}
              className="group/tool flex items-center gap-3 rounded-xl bg-card p-3 text-card-foreground ring-1 ring-foreground/10 transition-colors outline-none hover:bg-muted/50 focus-visible:ring-3 focus-visible:ring-ring/50"
            >
              <span className="flex size-9 shrink-0 items-center justify-center rounded-lg border bg-background [&_svg]:size-4.5">
                <app.icon />
              </span>
              <span className="truncate text-sm font-medium">{app.name}</span>
              <LuArrowUpRight className="ml-auto size-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover/tool:opacity-100 group-focus-visible/tool:opacity-100" />
            </a>
          ))}
        </nav>
      </main>
    </div>
  )
}
