import { useState, type CSSProperties } from "react"
import {
  LuArrowRight,
  LuChevronDown,
  LuChevronUp,
  LuEye,
  LuInfo,
  LuPiggyBank,
  LuPlus,
} from "react-icons/lu"

import { useDialogs } from "@/components/dialogs"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { Input } from "@/components/ui/input"
import { Progress } from "@/components/ui/progress"
import {
  Table,
  TableBody,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { formatUSD } from "@/lib/format"
import { cn } from "@/lib/utils"
import * as actions from "@/pages/tracker/actions"
import {
  CalendarToggle,
  ColorDot,
  DayOfMonthSelect,
  EditorField,
  EditorPanel,
  Hint,
  MoneyInput,
  ScheduleKindToggle,
  TabToolbar,
  WeekdayToggles,
} from "@/pages/tracker/components"
import {
  dueLabel,
  dueSortKey,
  NEUTRAL_COLOR,
  projectBalances,
  waterfallAllocate,
  type Contribution,
  type SavingsBucket,
} from "@/pages/tracker/model"
import type { TrackerApi } from "@/pages/tracker/use-tracker"

const HORIZONS = [
  { months: 1, label: "+1 mo" },
  { months: 6, label: "+6 mo" },
  { months: 12, label: "+1 yr" },
]

export function SavingsTab({ data, summary, update }: TrackerApi) {
  const [editing, setEditing] = useState<string | null>(null)
  const { prompt, confirm } = useDialogs()
  const buckets = data.savingsBuckets

  const projections = HORIZONS.map(({ months }) =>
    projectBalances(
      months,
      summary.monthlyContributions,
      summary.startBalances,
      buckets
    )
  )

  // Where each contribution goes today, routing them in calendar order.
  const destinations: Record<number, Record<number, number>> = {}
  const preview = { ...summary.startBalances }
  for (const contribution of [...data.savingsContribs].sort(
    (a, b) => dueSortKey(a) - dueSortKey(b)
  )) {
    const allocation = waterfallAllocate(
      contribution.amount || 0,
      preview,
      buckets
    )
    destinations[contribution.id] = allocation
    for (const id in allocation)
      preview[id] = (preview[id] || 0) + allocation[id]
  }

  async function addBucket() {
    const values = await prompt({
      title: "New savings bucket",
      description: "New buckets fill after the ones above them.",
      fields: [{ name: "name", label: "Name", placeholder: "e.g. Vacation" }],
      confirmLabel: "Add bucket",
      validate: ({ name }) =>
        name ? null : { field: "name", message: "Enter a name." },
    })
    if (!values) return
    const id = data.nextId
    update((d) => actions.addBucket(d, values.name))
    setEditing(`bucket-${id}`)
  }

  async function deleteBucket(bucket: SavingsBucket) {
    const ok = await confirm({
      title: `Delete "${bucket.name}"?`,
      description: "Contributions will route to the remaining buckets.",
      confirmLabel: "Delete",
      destructive: true,
    })
    if (!ok) return
    setEditing(null)
    update((d) => actions.deleteBucket(d, bucket.id))
  }

  function addContribution() {
    const id = data.nextId
    update((d) => actions.addContribution(d))
    setEditing(`contribution-${id}`)
  }

  return (
    <div className="flex flex-col gap-4">
      <TabToolbar
        summary={
          <>
            Net worth <strong>{formatUSD(summary.totalSavings)}</strong>
            {summary.totalTarget > 0 && (
              <>
                {" "}
                · Target <strong>{formatUSD(summary.totalTarget)}</strong>
              </>
            )}{" "}
            · Saving <strong>{formatUSD(summary.monthlyContributions)}</strong>
            /mo · Free cash{" "}
            <strong
              className={cn(
                summary.freeCash >= 0 ? "text-positive!" : "text-destructive!"
              )}
            >
              {formatUSD(summary.freeCash)}
            </strong>
            /mo
          </>
        }
        actions={
          <>
            <Button variant="outline" onClick={addBucket}>
              <LuPiggyBank />
              Bucket
            </Button>
            <Button onClick={addContribution}>
              <LuPlus />
              Contribution
            </Button>
          </>
        }
      />

      <Alert role="note">
        <LuInfo />
        <AlertDescription>
          Buckets fill in priority order, top to bottom. Each contribution goes
          to the first bucket still below its target, and the last bucket takes
          whatever overflows.
        </AlertDescription>
      </Alert>

      {buckets.length === 0 ? (
        <Empty className="border border-dashed">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <LuPiggyBank />
            </EmptyMedia>
            <EmptyTitle>No buckets yet</EmptyTitle>
            <EmptyDescription>
              Add a bucket like Checking or Emergency to start routing savings.
            </EmptyDescription>
          </EmptyHeader>
          <Button onClick={addBucket}>
            <LuPlus />
            Add bucket
          </Button>
        </Empty>
      ) : (
        <div className="flex flex-col gap-3">
          {buckets.map((bucket, index) =>
            editing === `bucket-${bucket.id}` ? (
              <Card key={bucket.id} className="gap-0 py-0">
                <EditorPanel
                  onDone={() => setEditing(null)}
                  onDelete={() => deleteBucket(bucket)}
                >
                  <BucketFields
                    bucket={bucket}
                    isLast={index === buckets.length - 1}
                    onChange={(changes) =>
                      update((d) => actions.updateBucket(d, bucket.id, changes))
                    }
                  />
                </EditorPanel>
              </Card>
            ) : (
              <BucketCard
                key={bucket.id}
                bucket={bucket}
                index={index}
                count={buckets.length}
                monthly={summary.bucketMonthly[bucket.id] || 0}
                onEdit={() => setEditing(`bucket-${bucket.id}`)}
                onMove={(direction) =>
                  update((d) => actions.moveBucket(d, bucket.id, direction))
                }
              />
            )
          )}
        </div>
      )}

      <Card className="@container gap-0 py-0">
        <CardHeader className="border-b bg-muted/40 py-3">
          <CardTitle>Contributions</CardTitle>
          <CardDescription>
            Deducted from the calendar's running net, like expenses.
          </CardDescription>
          <CardAction>
            <Button variant="outline" size="sm" onClick={addContribution}>
              <LuPlus />
              Contribution
            </Button>
          </CardAction>
        </CardHeader>
        {data.savingsContribs.length ? (
          <Table className="min-w-[36rem] table-fixed">
            <colgroup>
              <col className="w-12" />
              <col />
              <col className="w-32" />
              <col className="w-[40%]" />
              <col className="w-28" />
            </colgroup>
            <TableHeader className="sr-only">
              <TableRow>
                <TableHead>Calendar</TableHead>
                <TableHead>Contribution</TableHead>
                <TableHead>Day</TableHead>
                <TableHead>Destination</TableHead>
                <TableHead>Amount</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.savingsContribs.map((contribution) =>
                editing === `contribution-${contribution.id}` ? (
                  <TableRow
                    key={contribution.id}
                    className="hover:bg-transparent"
                  >
                    <TableCell colSpan={5} className="p-0 whitespace-normal">
                      <ContributionEditor
                        contribution={contribution}
                        destination={destinationLabel(
                          destinations[contribution.id],
                          buckets
                        )}
                        onChange={(changes) =>
                          update((d) =>
                            actions.updateContribution(
                              d,
                              contribution.id,
                              changes
                            )
                          )
                        }
                        onToggleWeekday={(weekday) =>
                          update((d) =>
                            actions.toggleContributionWeekday(
                              d,
                              contribution.id,
                              weekday
                            )
                          )
                        }
                        onDone={() => setEditing(null)}
                        onDelete={() => {
                          setEditing(null)
                          update((d) =>
                            actions.deleteContribution(d, contribution.id)
                          )
                        }}
                      />
                    </TableCell>
                  </TableRow>
                ) : (
                  <ContributionRow
                    key={contribution.id}
                    contribution={contribution}
                    allocation={destinations[contribution.id] ?? {}}
                    buckets={buckets}
                    onEdit={() => setEditing(`contribution-${contribution.id}`)}
                    onToggleCalendar={() =>
                      update((d) =>
                        actions.toggleContributionOnCalendar(d, contribution.id)
                      )
                    }
                  />
                )
              )}
            </TableBody>
          </Table>
        ) : (
          <CardContent className="py-6 text-center text-sm text-muted-foreground">
            No contributions yet. Add one to start filling your buckets.
          </CardContent>
        )}
      </Card>

      {buckets.length > 0 && (
        <Card className="gap-0 py-0">
          <CardHeader className="border-b bg-muted/40 py-3">
            <CardTitle>Projection</CardTitle>
            <CardDescription>
              Bucket balances if contributions continue as planned.
            </CardDescription>
          </CardHeader>
          <Table className="[&_tr>*:last-child]:pr-4">
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="pl-4">Bucket</TableHead>
                <TableHead className="text-right">Now</TableHead>
                {HORIZONS.map(({ label }) => (
                  <TableHead key={label} className="text-right">
                    {label}
                  </TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody>
              {buckets.map((bucket) => (
                <TableRow key={bucket.id}>
                  <TableCell className="pl-4">
                    <span className="flex items-center gap-2">
                      <ColorDot color={bucket.color || NEUTRAL_COLOR} />
                      {bucket.name}
                    </span>
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {formatUSD(bucket.current || 0)}
                  </TableCell>
                  {projections.map((balances, i) => (
                    <TableCell key={i} className="text-right tabular-nums">
                      {formatUSD(balances[bucket.id] || 0)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
            <TableFooter>
              <TableRow className="hover:bg-transparent">
                <TableCell className="pl-4">Total</TableCell>
                <TableCell className="text-right tabular-nums">
                  {formatUSD(summary.totalSavings)}
                </TableCell>
                {projections.map((balances, i) => (
                  <TableCell key={i} className="text-right tabular-nums">
                    {formatUSD(
                      Object.values(balances).reduce((s, v) => s + v, 0)
                    )}
                  </TableCell>
                ))}
              </TableRow>
            </TableFooter>
          </Table>
        </Card>
      )}

      <Hint>
        Click a bucket or contribution to edit · use the arrows to change fill
        priority · update Current to match your real balance · <LuEye /> shows
        or hides a contribution on the calendar
      </Hint>
    </div>
  )
}

function destinationLabel(
  allocation: Record<number, number> | undefined,
  buckets: SavingsBucket[]
) {
  const parts = Object.entries(allocation ?? {}).map(([id, amount]) => {
    const bucket = buckets.find((b) => b.id === +id)
    return `${bucket?.name ?? "?"} ${formatUSD(amount)}`
  })
  return parts.length ? parts.join(" + ") : "No bucket"
}

/** The bucket that receives most of a contribution, for its color. */
function mainBucketColor(
  allocation: Record<number, number>,
  buckets: SavingsBucket[]
) {
  const [mainId] = Object.entries(allocation).reduce<[string | null, number]>(
    (best, [id, amount]) => (amount > best[1] ? [id, amount] : best),
    [null, 0]
  )
  return buckets.find((b) => b.id === Number(mainId))?.color || NEUTRAL_COLOR
}

function BucketCard({
  bucket,
  index,
  count,
  monthly,
  onEdit,
  onMove,
}: {
  bucket: SavingsBucket
  index: number
  count: number
  monthly: number
  onEdit: () => void
  onMove: (direction: -1 | 1) => void
}) {
  const isLast = index === count - 1
  const target = bucket.target || 0
  const current = bucket.current || 0
  const percent =
    target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0
  const isFull = !isLast && target > 0 && current >= target
  const monthsToTarget =
    monthly > 0 && target > current
      ? Math.ceil((target - current) / monthly)
      : null
  const status = isLast
    ? "Overflow"
    : isFull
      ? "Full, overflowing to the next bucket"
      : monthly > 0
        ? `Filling +${formatUSD(monthly)}/mo`
        : index > 0
          ? "Waiting for the buckets above"
          : "No contributions yet"
  const color = bucket.color || NEUTRAL_COLOR

  return (
    <Card className="gap-0 py-0">
      <div
        role="button"
        tabIndex={0}
        aria-label={`Edit ${bucket.name}`}
        onClick={onEdit}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault()
            onEdit()
          }
        }}
        className="flex cursor-pointer flex-col gap-3 px-3 py-3 outline-none hover:bg-muted/30 focus-visible:ring-3 focus-visible:ring-ring/50"
      >
        <div className="flex items-center gap-2">
          <div className="flex flex-col">
            <Button
              variant="ghost"
              size="icon-xs"
              className="h-4 text-muted-foreground"
              aria-label={`Move ${bucket.name} up`}
              disabled={index === 0}
              onClick={(event) => {
                event.stopPropagation()
                onMove(-1)
              }}
            >
              <LuChevronUp />
            </Button>
            <Button
              variant="ghost"
              size="icon-xs"
              className="h-4 text-muted-foreground"
              aria-label={`Move ${bucket.name} down`}
              disabled={isLast}
              onClick={(event) => {
                event.stopPropagation()
                onMove(1)
              }}
            >
              <LuChevronDown />
            </Button>
          </div>
          <span className="w-6 text-xs text-muted-foreground tabular-nums">
            #{index + 1}
          </span>
          <ColorDot color={color} className="size-2.5" />
          <span className="truncate font-medium">{bucket.name}</span>
          {isLast && (
            <Badge variant="secondary" className="font-normal">
              overflow
            </Badge>
          )}
          <div className="ml-auto text-right">
            <div className="font-medium tabular-nums">
              {formatUSD(current)}
              <span className="font-normal text-muted-foreground">
                {" "}
                / {formatUSD(target)}
                {isLast ? "+" : ""}
              </span>
            </div>
            <div className="text-xs text-muted-foreground">
              {percent}% · {status}
              {monthsToTarget ? ` · ${monthsToTarget} mo to target` : ""}
            </div>
          </div>
        </div>
        <Progress
          value={percent}
          aria-label={`${bucket.name} progress`}
          className="[&_[data-slot=progress-indicator]]:bg-(--bucket) [&_[data-slot=progress-track]]:h-1.5"
          style={{ "--bucket": color } as CSSProperties}
        />
      </div>
    </Card>
  )
}

function BucketFields({
  bucket,
  isLast,
  onChange,
}: {
  bucket: SavingsBucket
  isLast: boolean
  onChange: (changes: Partial<SavingsBucket>) => void
}) {
  const id = (field: string) => `bucket-${bucket.id}-${field}`
  return (
    <div className="grid gap-3 sm:grid-cols-[1.5fr_1fr_1fr_auto]">
      <EditorField label="Bucket name" htmlFor={id("name")}>
        <Input
          id={id("name")}
          value={bucket.name}
          onChange={(event) => onChange({ name: event.target.value })}
        />
      </EditorField>
      <EditorField
        label={isLast ? "Target (display only)" : "Target"}
        htmlFor={id("target")}
      >
        <MoneyInput
          id={id("target")}
          value={bucket.target}
          onValueChange={(target) => onChange({ target: target ?? 0 })}
        />
      </EditorField>
      <EditorField label="Current balance" htmlFor={id("current")}>
        <MoneyInput
          id={id("current")}
          value={bucket.current}
          onValueChange={(current) => onChange({ current: current ?? 0 })}
        />
      </EditorField>
      <EditorField label="Color" htmlFor={id("color")}>
        <input
          id={id("color")}
          type="color"
          value={bucket.color || NEUTRAL_COLOR}
          onChange={(event) => onChange({ color: event.target.value })}
          className="h-8 w-14 cursor-pointer rounded-lg border border-input bg-transparent p-1"
        />
      </EditorField>
    </div>
  )
}

function ContributionRow({
  contribution,
  allocation,
  buckets,
  onEdit,
  onToggleCalendar,
}: {
  contribution: Contribution
  allocation: Record<number, number>
  buckets: SavingsBucket[]
  onEdit: () => void
  onToggleCalendar: () => void
}) {
  const color = mainBucketColor(allocation, buckets)
  const destination = destinationLabel(allocation, buckets)
  return (
    <TableRow className="cursor-pointer" onClick={onEdit}>
      <TableCell className="pl-2">
        <CalendarToggle
          shown={contribution.showOnCal !== false}
          color={color}
          name={contribution.name}
          onToggle={onToggleCalendar}
        />
      </TableCell>
      <TableCell className="truncate font-medium">
        {contribution.name}
      </TableCell>
      <TableCell className="truncate text-muted-foreground">
        {dueLabel(contribution)}
      </TableCell>
      <TableCell
        className="truncate text-xs text-muted-foreground"
        title={destination}
      >
        <span className="flex items-center gap-1.5">
          <LuArrowRight className="size-3.5 shrink-0" />
          <span className="truncate">{destination}</span>
        </span>
      </TableCell>
      <TableCell
        className="pr-4 text-right font-medium tabular-nums"
        style={{ color }}
      >
        +{formatUSD(contribution.amount || 0)}
      </TableCell>
    </TableRow>
  )
}

function ContributionEditor({
  contribution,
  destination,
  onChange,
  onToggleWeekday,
  onDone,
  onDelete,
}: {
  contribution: Contribution
  destination: string
  onChange: (changes: Partial<Contribution>) => void
  onToggleWeekday: (weekday: number) => void
  onDone: () => void
  onDelete: () => void
}) {
  const id = (field: string) => `contribution-${contribution.id}-${field}`
  const weekly = contribution.dueType === "weekdays"

  return (
    <EditorPanel onDone={onDone} onDelete={onDelete}>
      <div className="grid gap-3 sm:grid-cols-[1.6fr_1fr]">
        <EditorField label="Name" htmlFor={id("name")}>
          <Input
            id={id("name")}
            value={contribution.name}
            onChange={(event) => onChange({ name: event.target.value })}
          />
        </EditorField>
        <EditorField
          label={weekly ? "Amount per occurrence" : "Monthly amount"}
          htmlFor={id("amount")}
        >
          <MoneyInput
            id={id("amount")}
            value={contribution.amount}
            onValueChange={(amount) => onChange({ amount: amount ?? 0 })}
          />
        </EditorField>
      </div>
      <EditorField label="Contribution day">
        <div className="flex flex-col gap-3">
          <ScheduleKindToggle
            value={contribution.dueType}
            onChange={(dueType) => onChange({ dueType })}
            datesLabel="Specific date"
            weekdaysLabel="Days of week"
          />
          {weekly ? (
            <WeekdayToggles
              label="Contribution days"
              value={contribution.dueWeekdays}
              onToggle={onToggleWeekday}
            />
          ) : (
            <DayOfMonthSelect
              id={id("due")}
              value={contribution.due}
              onChange={(due) => onChange({ due })}
            />
          )}
          <p className="text-xs text-muted-foreground">
            Contributions on a weekend show on the following Monday in the
            calendar.
          </p>
        </div>
      </EditorField>
      <p className="text-xs text-muted-foreground">
        Routes to{" "}
        <span className="font-medium text-foreground">{destination}</span> based
        on current bucket balances.
      </p>
    </EditorPanel>
  )
}
