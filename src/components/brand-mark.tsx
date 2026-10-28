import { LuLayoutGrid } from "react-icons/lu"

import { cn } from "@/lib/utils"

export function BrandMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={cn(
        "flex size-7 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground [&_svg]:size-4",
        className
      )}
    >
      <LuLayoutGrid />
    </span>
  )
}
