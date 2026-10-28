import type { ReactNode } from "react"
import { LuCheck, LuChevronsUpDown, LuHouse } from "react-icons/lu"

import { BrandMark } from "@/components/brand-mark"
import { SyncStatus } from "@/components/sync-status"
import { ThemeToggle } from "@/components/theme-toggle"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuLabel,
  DropdownMenuLinkItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Separator } from "@/components/ui/separator"
import { UserMenu } from "@/components/user-menu"
import { appHref, apps, getApp, rootHref, type AppId } from "@/lib/apps"
import { cn } from "@/lib/utils"

type AppHeaderProps = {
  /** The tool this page belongs to; omitted on the home page. */
  current?: AppId
  /** Page-specific buttons, shown before the sync, theme, and account controls. */
  actions?: ReactNode
  className?: string
}

export function AppHeader({ current, actions, className }: AppHeaderProps) {
  return (
    <header
      className={cn(
        "sticky top-0 z-40 shrink-0 border-b bg-background/85 backdrop-blur-md print:hidden",
        className
      )}
    >
      <div className="flex h-14 items-center gap-1 px-3 sm:px-5">
        {/* On phones the tool switcher (which links home) stands in for the logo. */}
        <a
          href={rootHref(current)}
          className={cn(
            "shrink-0 items-center gap-2 rounded-lg p-1 text-sm font-semibold tracking-tight outline-none focus-visible:ring-3 focus-visible:ring-ring/50",
            current ? "hidden sm:flex" : "flex"
          )}
        >
          <BrandMark />
          System
        </a>
        {current && (
          <>
            <span
              aria-hidden
              className="mx-0.5 hidden text-lg font-light text-muted-foreground/40 select-none sm:inline"
            >
              /
            </span>
            <AppSwitcher current={current} />
          </>
        )}
        <div className="ml-auto flex min-w-0 items-center gap-1">
          {actions && (
            <>
              <div className="flex items-center gap-1.5">{actions}</div>
              <Separator
                orientation="vertical"
                className="mx-1.5 hidden h-5 sm:block"
              />
            </>
          )}
          {current && <SyncStatus pageId={getApp(current).syncId} />}
          <ThemeToggle />
          <UserMenu />
        </div>
      </div>
    </header>
  )
}

function AppSwitcher({ current }: { current: AppId }) {
  const app = getApp(current)

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button
            variant="ghost"
            className="-ml-1 min-w-0 shrink gap-2 px-2 font-medium sm:ml-0"
          />
        }
      >
        <app.icon className="text-muted-foreground" />
        <span className="truncate">{app.name}</span>
        <LuChevronsUpDown className="text-muted-foreground" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-80">
        <DropdownMenuGroup>
          <DropdownMenuLabel>Tools</DropdownMenuLabel>
          {apps.map((item) => (
            <DropdownMenuLinkItem
              key={item.id}
              href={appHref(item, current)}
              className="items-start gap-2.5 py-2"
            >
              <span className="flex size-8 shrink-0 items-center justify-center rounded-md border bg-background">
                <item.icon />
              </span>
              <span className="flex min-w-0 flex-col gap-0.5">
                <span className="font-medium">{item.name}</span>
                <span className="line-clamp-2 text-xs text-muted-foreground">
                  {item.description}
                </span>
              </span>
              {item.id === current && (
                <LuCheck className="ml-auto self-center" />
              )}
            </DropdownMenuLinkItem>
          ))}
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <DropdownMenuLinkItem href={rootHref(current)}>
          <LuHouse />
          All tools
        </DropdownMenuLinkItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
