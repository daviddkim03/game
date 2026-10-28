import type { ComponentProps, ReactNode } from "react"
import { LuCheck, LuEye, LuEyeOff, LuTrash2 } from "react-icons/lu"

import { NumberInput } from "@/components/number-input"
import { Button } from "@/components/ui/button"
import { Field, FieldLabel } from "@/components/ui/field"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupText,
} from "@/components/ui/input-group"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"
import {
  DAYS_SHORT,
  ordinalSuffix,
  type ScheduleKind,
} from "@/pages/tracker/model"

export function ColorDot({
  color,
  className,
}: {
  color: string
  className?: string
}) {
  return (
    <span
      aria-hidden
      className={cn("inline-block size-2 shrink-0 rounded-full", className)}
      style={{ backgroundColor: color }}
    />
  )
}

/** Summary on the left, actions on the right, above each tab's content. */
export function TabToolbar({
  summary,
  actions,
}: {
  summary: ReactNode
  actions?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="text-sm text-muted-foreground [&_strong]:font-medium [&_strong]:text-foreground [&_strong]:tabular-nums">
        {summary}
      </p>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </div>
  )
}

/** A short muted hint under a list. */
export function Hint({ children }: { children: ReactNode }) {
  return (
    <p className="flex flex-wrap items-center gap-x-1.5 text-xs text-muted-foreground [&_svg]:size-3.5">
      {children}
    </p>
  )
}

export function CalendarToggle({
  shown,
  color,
  name,
  onToggle,
}: {
  shown: boolean
  color: string
  name: string
  onToggle: () => void
}) {
  const label = shown
    ? `Hide ${name} on the calendar`
    : `Show ${name} on the calendar`
  return (
    <Tooltip>
      <TooltipTrigger
        render={
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={label}
            aria-pressed={shown}
            onClick={(event) => {
              event.stopPropagation()
              onToggle()
            }}
          />
        }
      >
        {shown ? (
          <LuEye style={{ color }} />
        ) : (
          <LuEyeOff className="text-muted-foreground/60" />
        )}
      </TooltipTrigger>
      <TooltipContent>
        {shown ? "Shown on the calendar" : "Hidden from the calendar"}
      </TooltipContent>
    </Tooltip>
  )
}

/** Labeled control inside the inline editors. */
export function EditorField({
  label,
  htmlFor,
  className,
  children,
}: {
  label: ReactNode
  htmlFor?: string
  className?: string
  children: ReactNode
}) {
  return (
    <Field className={cn("gap-1.5", className)}>
      <FieldLabel htmlFor={htmlFor} className="text-xs text-muted-foreground">
        {label}
      </FieldLabel>
      {children}
    </Field>
  )
}

/** The expanded edit form that replaces a row while it is being edited. */
export function EditorPanel({
  children,
  onDone,
  onDelete,
  deleteLabel = "Delete",
}: {
  children: ReactNode
  onDone: () => void
  onDelete: () => void
  deleteLabel?: string
}) {
  return (
    // Pinned to the card's visible width when its table scrolls sideways.
    <div className="sticky left-0 flex max-w-[100cqw] flex-col gap-4 bg-muted/40 p-4">
      {children}
      <div className="flex items-center gap-2">
        <Button size="sm" onClick={onDone}>
          <LuCheck />
          Done
        </Button>
        <Button
          size="sm"
          variant="ghost"
          className="text-destructive hover:bg-destructive/10 hover:text-destructive"
          onClick={onDelete}
        >
          <LuTrash2 />
          {deleteLabel}
        </Button>
      </div>
    </div>
  )
}

export function MoneyInput({
  value,
  onValueChange,
  className,
  ...props
}: ComponentProps<typeof NumberInput>) {
  return (
    <InputGroup className={className}>
      <InputGroupAddon>
        <InputGroupText>$</InputGroupText>
      </InputGroupAddon>
      <NumberInput
        grouped
        min={0}
        className="tabular-nums"
        value={value}
        onValueChange={onValueChange}
        {...props}
      />
    </InputGroup>
  )
}

/** "Specific dates" vs "Days of week", styled like the page tabs. */
export function ScheduleKindToggle({
  value,
  onChange,
  datesLabel,
  weekdaysLabel,
}: {
  value: ScheduleKind
  onChange: (kind: ScheduleKind) => void
  datesLabel: string
  weekdaysLabel: string
}) {
  const item =
    "h-7 rounded-md px-3 text-muted-foreground hover:bg-transparent aria-pressed:bg-background aria-pressed:text-foreground aria-pressed:shadow-sm dark:aria-pressed:bg-input/50"
  return (
    <ToggleGroup
      spacing={0}
      className="w-fit gap-0 rounded-lg bg-muted p-[3px]"
      value={[value]}
      onValueChange={([next]) => next && onChange(next as ScheduleKind)}
    >
      <ToggleGroupItem value="dates" className={item}>
        {datesLabel}
      </ToggleGroupItem>
      <ToggleGroupItem value="weekdays" className={item}>
        {weekdaysLabel}
      </ToggleGroupItem>
    </ToggleGroup>
  )
}

const pressedClass =
  "aria-pressed:bg-primary aria-pressed:text-primary-foreground aria-pressed:hover:bg-primary/90"

export function WeekdayToggles({
  value,
  onToggle,
  label,
}: {
  value: number[]
  onToggle: (weekday: number) => void
  label: string
}) {
  return (
    <ToggleGroup
      multiple
      variant="outline"
      size="sm"
      aria-label={label}
      className="flex-wrap"
      value={value.map(String)}
      onValueChange={(next) => {
        const changed =
          next.find((v) => !value.includes(+v)) ??
          value.map(String).find((v) => !next.includes(v))
        if (changed !== undefined) onToggle(+changed)
      }}
    >
      {DAYS_SHORT.map((day, index) => (
        <ToggleGroupItem
          key={day}
          value={String(index)}
          className={cn("w-12", pressedClass)}
        >
          {day}
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}

/** Days 1-31 laid out like a month, for picking paydays. */
export function MonthDayToggles({
  value,
  onToggle,
  label,
}: {
  value: number[]
  onToggle: (day: number) => void
  label: string
}) {
  return (
    <ToggleGroup
      multiple
      variant="outline"
      size="sm"
      spacing={1}
      aria-label={label}
      className="grid w-fit grid-cols-7"
      value={value.map(String)}
      onValueChange={(next) => {
        const changed =
          next.find((v) => !value.includes(+v)) ??
          value.map(String).find((v) => !next.includes(v))
        if (changed !== undefined) onToggle(+changed)
      }}
    >
      {Array.from({ length: 31 }, (_, i) => i + 1).map((day) => (
        <ToggleGroupItem
          key={day}
          value={String(day)}
          aria-label={day + ordinalSuffix(day)}
          className={cn("w-9 px-0 tabular-nums", pressedClass)}
        >
          {day}
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}

const DAY_OF_MONTH_ITEMS = [
  { label: "No set day", value: null },
  ...Array.from({ length: 31 }, (_, i) => ({
    label: `${i + 1}${ordinalSuffix(i + 1)}`,
    value: i + 1,
  })),
]

export function DayOfMonthSelect({
  id,
  value,
  onChange,
}: {
  id?: string
  value: number | null
  onChange: (day: number | null) => void
}) {
  return (
    <Select
      items={DAY_OF_MONTH_ITEMS}
      value={value}
      onValueChange={(day) => onChange(day ?? null)}
    >
      <SelectTrigger id={id} className="w-40">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {DAY_OF_MONTH_ITEMS.map((item) => (
          <SelectItem key={item.label} value={item.value}>
            {item.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

export function OptionSelect<T extends string>({
  id,
  value,
  options,
  onChange,
}: {
  id?: string
  value: T
  options: readonly T[]
  onChange: (value: T) => void
}) {
  const items = options.map((option) => ({ label: option, value: option }))
  return (
    <Select
      items={items}
      value={value}
      onValueChange={(next) => next !== null && onChange(next)}
    >
      <SelectTrigger id={id} className="w-full">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {items.map((item) => (
          <SelectItem key={item.value} value={item.value}>
            {item.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
