import { LuArrowUpRight } from "react-icons/lu"

import { AppHeader } from "@/components/app-header"
import { Badge } from "@/components/ui/badge"
import { appHref, apps } from "@/lib/apps"
import { syncEnabled } from "@/lib/sync"

export function HomePage() {
  const today = new Date().toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric",
  })

  return (
    <div className="flex min-h-svh flex-col">
      <AppHeader />
      <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col justify-center gap-10 px-4 py-12 sm:px-6 sm:py-20">
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">{today}</p>
          <h1 className="text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
            Offline tools. All yours.
          </h1>
          <p className="max-w-xl text-base text-pretty text-muted-foreground">
            Money, time, and billing in one private workspace that follows you
            across devices.
          </p>
        </div>

        <nav aria-label="Tools" className="grid gap-4 md:grid-cols-3">
          {apps.map((app, index) => (
            <a
              key={app.id}
              href={appHref(app)}
              className="group/tool relative flex flex-col gap-6 rounded-xl bg-card p-5 text-card-foreground ring-1 ring-foreground/10 transition-[box-shadow,background-color] outline-none hover:bg-muted/40 hover:ring-foreground/20 focus-visible:ring-3 focus-visible:ring-ring/50"
            >
              <div className="flex items-start justify-between">
                <span className="flex size-10 items-center justify-center rounded-lg border bg-background shadow-xs [&_svg]:size-5">
                  <app.icon />
                </span>
                <LuArrowUpRight className="size-5 text-muted-foreground transition-transform group-hover/tool:translate-x-0.5 group-hover/tool:-translate-y-0.5 group-hover/tool:text-foreground" />
              </div>
              <div className="flex flex-1 flex-col gap-1.5">
                <h2 className="font-heading text-lg font-semibold tracking-tight">
                  {app.name}
                </h2>
                <p className="text-sm leading-relaxed text-muted-foreground">
                  {app.description}
                </p>
              </div>
              <div className="flex items-center justify-between">
                <Badge variant="secondary">{app.tag}</Badge>
                <span className="text-xs text-muted-foreground tabular-nums">
                  {String(index + 1).padStart(2, "0")}
                </span>
              </div>
            </a>
          ))}
        </nav>
      </main>
      <footer className="border-t">
        <div className="mx-auto flex h-14 w-full max-w-5xl items-center gap-2 px-4 text-xs text-muted-foreground sm:px-6">
          <span className="relative flex size-2">
            <span className="absolute inline-flex size-full animate-ping rounded-full bg-positive opacity-60 motion-reduce:hidden" />
            <span className="relative inline-flex size-2 rounded-full bg-positive" />
          </span>
          {syncEnabled
            ? "Private sync across your devices"
            : "Saved in this browser"}
        </div>
      </footer>
    </div>
  )
}
