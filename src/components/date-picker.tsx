import { useState } from "react"
import { LuCalendarDays } from "react-icons/lu"

import { Button } from "@/components/ui/button"
import { Calendar } from "@/components/ui/calendar"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { parseISODate, toISODate } from "@/lib/format"
import { cn } from "@/lib/utils"

type DatePickerProps = {
  /** "YYYY-MM-DD", or "" for no date. */
  value: string
  onChange: (value: string) => void
  id?: string
  placeholder?: string
  size?: "default" | "sm"
  className?: string
  "aria-label"?: string
}

export function DatePicker({
  value,
  onChange,
  id,
  placeholder = "Pick a date",
  size = "default",
  className,
  "aria-label": ariaLabel,
}: DatePickerProps) {
  const [open, setOpen] = useState(false)
  const date = parseISODate(value)

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger
        render={
          <Button
            id={id}
            variant="outline"
            size={size}
            aria-label={ariaLabel}
            className={cn(
              "justify-start font-normal tabular-nums",
              !date && "text-muted-foreground",
              className
            )}
          />
        }
      >
        <LuCalendarDays className="text-muted-foreground" />
        {date
          ? date.toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            })
          : placeholder}
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={date}
          defaultMonth={date}
          captionLayout="dropdown"
          onSelect={(next) => {
            onChange(next ? toISODate(next) : "")
            setOpen(false)
          }}
        />
      </PopoverContent>
    </Popover>
  )
}
