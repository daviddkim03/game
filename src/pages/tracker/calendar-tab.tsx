import { useMemo, useState, type CSSProperties } from "react"
import {
  DndContext,
  DragOverlay,
  useDndContext,
  useDraggable,
  useDroppable,
} from "@dnd-kit/core"
import {
  LuArrowDown,
  LuArrowRightLeft,
  LuArrowUp,
  LuChevronLeft,
  LuChevronRight,
  LuGripVertical,
  LuLink,
  LuStar,
} from "react-icons/lu"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardAction,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Toggle } from "@/components/ui/toggle"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { formatUSD } from "@/lib/format"
import { cn } from "@/lib/utils"
import * as actions from "@/pages/tracker/actions"
import {
  buildCalendarMonth,
  type CalendarFilters,
  type CalendarPill,
} from "@/pages/tracker/calendar"
import { CalendarToggle, ColorDot } from "@/pages/tracker/components"
import {
  collisionFor,
  DragChip,
  DragHandle,
  useDragSensors,
} from "@/pages/tracker/dnd"
import {
  categoryColor,
  DAYS_SHORT,
  dueLabel,
  dueSortKey,
  monthlyCost,
  MONTHS,
  PAYDAY_COLOR,
  safeHref,
  UNCATEGORIZED,
  type Expense,
} from "@/pages/tracker/model"
import { PaymentLinkDialog } from "@/pages/tracker/payment-link-dialog"
import type { TrackerApi } from "@/pages/tracker/use-tracker"

/** Pills that fit in a day before "+N more". */
const MAX_PILLS = 3
const PILL_ICONS = { pay: LuArrowUp, bill: LuArrowDown, sav: LuStar }
const FILTERS: { key: keyof CalendarFilters; label: string; color: string }[] =
  [
    { key: "paydays", label: "Paydays", color: PAYDAY_COLOR },
    { key: "bills", label: "Bills", color: "#E24B4A" },
    { key: "savings", label: "Savings", color: "#7F77DD" },
  ]

type PillData = { type: "pill"; pill: CalendarPill }
type BillData = { type: "bill"; id: number; label: string; color: string }

const collision = collisionFor((active, target) => {
  if (active?.type === "pill") return target?.type === "day"
  if (active?.type === "bill") {
    return (
      target?.type === "day" ||
      (target?.type === "bill-row" && target.id !== active.id)
    )
  }
  return false
})

export function CalendarTab({ data, summary, update }: TrackerApi) {
  const today = new Date()
  const [view, setView] = useState({
    year: today.getFullYear(),
    month: today.getMonth(),
  })
  const [filters, setFilters] = useState<CalendarFilters>({
    paydays: true,
    bills: true,
    savings: true,
  })
  const [linkFor, setLinkFor] = useState<number | null>(null)
  const [linkOpen, setLinkOpen] = useState(false)
  const [dragged, setDragged] = useState<PillData | BillData | null>(null)
  const sensors = useDragSensors()

  const calendar = useMemo(
    () =>
      buildCalendarMonth(
        data,
        view.year,
        view.month,
        filters,
        summary.startBalances
      ),
    [data, view, filters, summary.startBalances]
  )
  const isCurrentMonth =
    view.year === today.getFullYear() && view.month === today.getMonth()

  const cells: (number | null)[] = [
    ...Array<null>(calendar.firstWeekday).fill(null),
    ...Array.from({ length: calendar.daysInMonth }, (_, i) => i + 1),
  ]
  while (cells.length % 7) cells.push(null)

  const bills = data.expenses
    .filter(
      (e) =>
        (e.due != null || e.dueWeekdays.length > 0) && e.cat !== UNCATEGORIZED
    )
    .sort((a, b) => dueSortKey(a) - dueSortKey(b))
  const linkExpense = data.expenses.find((e) => e.id === linkFor) ?? null

  function shiftMonth(delta: number) {
    setView(({ year, month }) => {
      const next = new Date(year, month + delta, 1)
      return { year: next.getFullYear(), month: next.getMonth() }
    })
  }

  function openLink(expenseId: number) {
    setLinkFor(expenseId)
    setLinkOpen(true)
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={collision}
      onDragStart={({ active }) =>
        setDragged((active.data.current as PillData | BillData) ?? null)
      }
      onDragCancel={() => setDragged(null)}
      onDragEnd={({ active, over }) => {
        setDragged(null)
        const from = active.data.current as PillData | BillData | undefined
        const to = over?.data.current
        if (!from || !to) return
        if (to.type === "day") {
          const date = new Date(view.year, view.month, to.day)
          if (from.type === "pill")
            update((d) => actions.movePill(d, from.pill, date))
          else update((d) => actions.setBillDay(d, from.id, date))
        } else if (from.type === "bill" && to.type === "bill-row") {
          update((d) => actions.moveBillBefore(d, from.id, to.id))
        }
      }}
    >
      <div className="flex flex-col gap-4">
        <Card className="gap-0 py-0">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-3 border-b px-3 py-3 sm:px-4">
            <div className="flex items-center gap-1">
              <Button
                variant="outline"
                size="icon-sm"
                aria-label="Previous month"
                onClick={() => shiftMonth(-1)}
              >
                <LuChevronLeft />
              </Button>
              <Button
                variant="outline"
                size="icon-sm"
                aria-label="Next month"
                onClick={() => shiftMonth(1)}
              >
                <LuChevronRight />
              </Button>
              <h2 className="ml-2 min-w-36 text-base font-semibold tabular-nums">
                {MONTHS[view.month]} {view.year}
              </h2>
              <Button
                variant="ghost"
                size="sm"
                disabled={isCurrentMonth}
                onClick={() =>
                  setView({
                    year: today.getFullYear(),
                    month: today.getMonth(),
                  })
                }
              >
                Today
              </Button>
            </div>
            <div className="flex flex-wrap items-center gap-1.5 sm:ml-auto">
              {FILTERS.map(({ key, label, color }) => (
                <Toggle
                  key={key}
                  variant="outline"
                  size="sm"
                  pressed={filters[key]}
                  onPressedChange={(pressed) =>
                    setFilters((current) => ({ ...current, [key]: pressed }))
                  }
                  className="gap-1.5 px-2.5 text-muted-foreground aria-pressed:bg-transparent aria-pressed:text-foreground"
                >
                  <span
                    aria-hidden
                    className="size-2.5 rounded-full border-2"
                    style={{
                      borderColor: color,
                      backgroundColor: filters[key] ? color : "transparent",
                    }}
                  />
                  {label}
                </Toggle>
              ))}
            </div>
          </div>

          <div className="overflow-x-auto">
            <div className="grid min-w-[44rem] grid-cols-7">
              {DAYS_SHORT.map((day) => (
                <div
                  key={day}
                  className="border-b py-2 text-center text-xs font-medium text-muted-foreground"
                >
                  {day}
                </div>
              ))}
              {cells.map((day, index) =>
                day === null ? (
                  <div
                    key={`blank-${index}`}
                    className={cn(
                      "min-h-30 border-b bg-muted/30",
                      index % 7 !== 6 && "border-r"
                    )}
                  />
                ) : (
                  <DayCell
                    key={day}
                    day={day}
                    lastInRow={index % 7 === 6}
                    isToday={isCurrentMonth && day === today.getDate()}
                    pills={calendar.pills[day] ?? []}
                    net={Math.round(calendar.runningNet[day] ?? 0)}
                    data={data}
                    onOpenLink={openLink}
                  />
                )
              )}
            </div>
          </div>
        </Card>

        <Card className="gap-0 py-0">
          <CardHeader className="border-b bg-muted/40 py-3">
            <CardTitle>Bills with due dates</CardTitle>
            <CardDescription className="flex flex-wrap items-center gap-x-1">
              <span>
                <span className="font-medium text-foreground tabular-nums">
                  {formatUSD(bills.reduce((sum, b) => sum + monthlyCost(b), 0))}
                </span>
                /mo · drag
              </span>
              <LuGripVertical className="size-3.5" />
              <span>
                to reorder, or onto the calendar to change the due date
              </span>
            </CardDescription>
            <CardAction />
          </CardHeader>
          {bills.length ? (
            <Table className="min-w-[36rem] table-fixed">
              <colgroup>
                <col className="w-10" />
                <col className="w-12" />
                <col />
                <col className="w-36" />
                <col className="w-36" />
                <col className="w-28" />
              </colgroup>
              <TableHeader className="sr-only">
                <TableRow>
                  <TableHead>Reorder</TableHead>
                  <TableHead>Calendar</TableHead>
                  <TableHead>Bill</TableHead>
                  <TableHead>Due</TableHead>
                  <TableHead>Category</TableHead>
                  <TableHead>Cost</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {bills.map((bill) => (
                  <BillRow
                    key={bill.id}
                    bill={bill}
                    color={categoryColor(data, bill.cat)}
                    today={today.getDate()}
                    onToggleCalendar={() =>
                      update((d) => actions.toggleBillOnCalendar(d, bill.id))
                    }
                  />
                ))}
              </TableBody>
            </Table>
          ) : (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              No bills have a due date yet. Set one on the Expenses tab.
            </p>
          )}
        </Card>
      </div>

      <DragOverlay dropAnimation={null}>
        {dragged?.type === "pill" && (
          <PillBody pill={dragged.pill} className="w-36 shadow-lg" />
        )}
        {dragged?.type === "bill" && (
          <DragChip color={dragged.color}>{dragged.label}</DragChip>
        )}
      </DragOverlay>

      <PaymentLinkDialog
        expense={linkExpense}
        color={linkExpense ? categoryColor(data, linkExpense.cat) : ""}
        open={linkOpen}
        onOpenChange={setLinkOpen}
        onSave={(link) =>
          linkFor !== null &&
          update((d) => actions.setPaymentLink(d, linkFor, link))
        }
      />
    </DndContext>
  )
}

function DayCell({
  day,
  lastInRow,
  isToday,
  pills,
  net,
  data,
  onOpenLink,
}: {
  day: number
  lastInRow: boolean
  isToday: boolean
  pills: CalendarPill[]
  net: number
  data: TrackerApi["data"]
  onOpenLink: (expenseId: number) => void
}) {
  const { active } = useDndContext()
  const { setNodeRef, isOver } = useDroppable({
    id: `day-${day}`,
    data: { type: "day", day },
  })
  const hasPills = pills.length > 0
  const netColor = net >= 0 ? "var(--positive)" : "var(--destructive)"

  return (
    <div
      ref={setNodeRef}
      data-day={day}
      aria-label={`Day ${day}`}
      className={cn(
        "relative flex min-h-30 min-w-0 flex-col gap-[3px] border-b p-1",
        !lastInRow && "border-r",
        isToday && "bg-sky-500/[0.07]",
        isOver && active && "bg-muted ring-2 ring-primary ring-inset"
      )}
    >
      {!hasPills && (
        <span
          className={cn(
            "ml-auto flex size-6 items-center justify-center rounded-full text-xs tabular-nums",
            isToday
              ? "bg-primary font-semibold text-primary-foreground"
              : "text-muted-foreground"
          )}
        >
          {day}
        </span>
      )}
      {pills.slice(0, MAX_PILLS).map((pill) => (
        <Pill
          key={pill.key}
          pill={pill}
          link={
            pill.kind === "bill"
              ? safeHref(
                  data.expenses.find((e) => e.id === pill.refId)?.paymentLink
                )
              : null
          }
          onOpenLink={onOpenLink}
        />
      ))}
      {pills.length > MAX_PILLS && (
        <span className="px-1 text-[0.625rem] text-muted-foreground">
          +{pills.length - MAX_PILLS} more
        </span>
      )}
      {hasPills && (
        <span
          className="mt-auto truncate rounded-[5px] px-1.5 py-0.5 text-[0.625rem] font-bold tabular-nums"
          style={{
            color: netColor,
            backgroundColor: `color-mix(in oklab, ${netColor} 14%, transparent)`,
          }}
          title="Running total for the month through this day"
        >
          {net >= 0 ? "+" : "-"}
          {formatUSD(Math.abs(net))}
        </span>
      )}
    </div>
  )
}

function pillDetails(pill: CalendarPill) {
  return [
    pill.shifted && `Moved from the ${pill.shiftLabel} (weekend)`,
    pill.destination && `Goes to ${pill.destination}`,
    pill.kind === "bill"
      ? "Drag to move · right-click to add or edit a payment link"
      : "Drag to move",
  ].filter(Boolean)
}

function Pill({
  pill,
  link,
  onOpenLink,
}: {
  pill: CalendarPill
  link: string | null
  onOpenLink: (expenseId: number) => void
}) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: pill.key,
    data: { type: "pill", pill },
  })

  return (
    <Tooltip>
      <TooltipTrigger
        render={
          <div
            ref={setNodeRef}
            {...attributes}
            {...listeners}
            data-pill={pill.kind}
            aria-label={`${pill.label}, ${formatUSD(pill.amount)}`}
            onContextMenu={(event) => {
              if (pill.kind !== "bill") return
              event.preventDefault()
              onOpenLink(pill.refId)
            }}
            className={cn(
              "cursor-grab touch-none outline-none select-none focus-visible:ring-2 focus-visible:ring-ring active:cursor-grabbing",
              isDragging && "opacity-40"
            )}
          />
        }
      >
        <PillBody pill={pill} link={link} />
      </TooltipTrigger>
      <TooltipContent className="flex-col items-start gap-0.5">
        {pillDetails(pill).map((line) => (
          <span key={line as string}>{line}</span>
        ))}
      </TooltipContent>
    </Tooltip>
  )
}

function PillBody({
  pill,
  link,
  className,
}: {
  pill: CalendarPill
  link?: string | null
  className?: string
}) {
  const Icon = PILL_ICONS[pill.kind]
  return (
    <div
      className={cn("rounded-[5px] px-1.5 py-[3px] text-white", className)}
      style={{ backgroundColor: pill.color } as CSSProperties}
    >
      <div className="flex items-center gap-1 text-[0.6875rem] leading-tight font-semibold">
        <Icon className="size-3 shrink-0" />
        <span className="truncate">{pill.label}</span>
        {pill.shifted && (
          <LuArrowRightLeft
            aria-label="Moved off a weekend"
            className="size-2.5 shrink-0 opacity-85"
          />
        )}
        {link && (
          <a
            href={link}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={`Open the payment site for ${pill.label}`}
            className="ml-auto shrink-0 rounded-sm p-px hover:bg-white/20"
            onPointerDown={(event) => event.stopPropagation()}
            onClick={(event) => event.stopPropagation()}
          >
            <LuLink className="size-3" />
          </a>
        )}
      </div>
      <div className="text-[0.625rem] leading-tight font-medium text-white/90 tabular-nums">
        {formatUSD(pill.amount)}
      </div>
    </div>
  )
}

function BillRow({
  bill,
  color,
  today,
  onToggleCalendar,
}: {
  bill: Expense
  color: string
  today: number
  onToggleCalendar: () => void
}) {
  const { active } = useDndContext()
  const data: BillData = { type: "bill", id: bill.id, label: bill.name, color }
  const drag = useDraggable({ id: `bill:${bill.id}`, data })
  const drop = useDroppable({
    id: `bill-row:${bill.id}`,
    data: { type: "bill-row", id: bill.id },
  })
  const weekly = bill.dueType === "weekdays"
  const due = bill.due ?? 0
  const relative = weekly
    ? null
    : due < today
      ? "past"
      : due === today
        ? "today"
        : `in ${due - today}d`

  return (
    <TableRow
      ref={(element) => {
        drag.setNodeRef(element)
        drop.setNodeRef(element)
      }}
      className={cn(
        drag.isDragging && "opacity-40",
        drop.isOver &&
          active?.data.current?.type === "bill" &&
          "[&>td]:shadow-[inset_0_2px_0_0_var(--color-primary)]"
      )}
    >
      <TableCell className="pl-2">
        <DragHandle
          label={`Move ${bill.name}`}
          attributes={drag.attributes}
          listeners={drag.listeners}
          setActivatorNodeRef={drag.setActivatorNodeRef}
        />
      </TableCell>
      <TableCell>
        <CalendarToggle
          shown={bill.showOnCal !== false}
          color={color}
          name={bill.name}
          onToggle={onToggleCalendar}
        />
      </TableCell>
      <TableCell className="truncate font-medium">{bill.name}</TableCell>
      <TableCell
        className={cn(
          "truncate",
          relative === "today"
            ? "font-medium text-warning"
            : relative === "past"
              ? "text-muted-foreground/60"
              : "text-muted-foreground"
        )}
      >
        {dueLabel(bill)}
        {relative && <span className="ml-1">({relative})</span>}
      </TableCell>
      <TableCell>
        <Badge
          variant="secondary"
          className="max-w-full gap-1.5"
          style={{
            color,
            backgroundColor: `color-mix(in oklab, ${color} 13%, transparent)`,
          }}
        >
          <ColorDot color={color} className="size-1.5" />
          <span className="truncate">{bill.cat}</span>
        </Badge>
      </TableCell>
      <TableCell className="pr-4 text-right font-medium tabular-nums">
        {formatUSD(bill.cost)}
      </TableCell>
    </TableRow>
  )
}
