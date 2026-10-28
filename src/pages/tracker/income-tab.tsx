import { useState } from "react"
import {
  LuEllipsis,
  LuEye,
  LuFolderPlus,
  LuGripVertical,
  LuPencil,
  LuPlus,
  LuTrash2,
} from "react-icons/lu"

import { useDialogs } from "@/components/dialogs"
import { NumberInput } from "@/components/number-input"
import { toast } from "@/components/ui/toast"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { formatUSD } from "@/lib/format"
import { cn } from "@/lib/utils"
import * as actions from "@/pages/tracker/actions"
import {
  CalendarToggle,
  EditorField,
  EditorPanel,
  Hint,
  MoneyInput,
  MonthDayToggles,
  OptionSelect,
  ScheduleKindToggle,
  TabToolbar,
  WeekdayToggles,
} from "@/pages/tracker/components"
import {
  GroupCard,
  GroupedList,
  DraggableRow,
} from "@/pages/tracker/grouped-list"
import {
  datesLabel,
  incomeColor,
  monthlyGross,
  monthlyNet,
  weekdaysLabel,
  type IncomeSource,
} from "@/pages/tracker/model"
import type { TrackerApi } from "@/pages/tracker/use-tracker"

const COLUMNS = 8

export function IncomeTab({ data, summary, update }: TrackerApi) {
  const [editing, setEditing] = useState<number | null>(null)
  const { prompt, confirm } = useDialogs()

  const nameError = (name: string, current?: string) =>
    !name
      ? { field: "name" as const, message: "Enter a name." }
      : name !== current && data.incomeTypes.includes(name)
        ? {
            field: "name" as const,
            message: "That income type already exists.",
          }
        : null

  async function addIncomeType() {
    const values = await prompt({
      title: "New income type",
      description: "Group sources like Work, Business, or Side.",
      fields: [{ name: "name", label: "Name", placeholder: "e.g. Freelance" }],
      confirmLabel: "Add type",
      validate: ({ name }) => nameError(name),
    })
    if (values) update((d) => actions.addIncomeType(d, values.name))
  }

  async function renameIncomeType(type: string) {
    const values = await prompt({
      title: "Rename income type",
      fields: [{ name: "name", label: "Name", defaultValue: type }],
      validate: ({ name }) => nameError(name, type),
    })
    if (values && values.name !== type) {
      update((d) => actions.renameIncomeType(d, type, values.name))
    }
  }

  async function deleteIncomeType(type: string) {
    if (data.incomeTypes.length <= 1) {
      toast.add({
        type: "warning",
        title: "Add another income type first",
        description: "There always needs to be at least one.",
      })
      return
    }
    const fallback = actions.incomeTypeFallback(data.incomeTypes, type)
    const count = data.income.filter(
      (s) => (s.incomeType || "Other") === type
    ).length
    if (count) {
      const ok = await confirm({
        title: `Delete "${type}"?`,
        description: `Its ${count} source${count === 1 ? "" : "s"} will move to ${fallback}.`,
        confirmLabel: "Delete",
        destructive: true,
      })
      if (!ok) return
    }
    setEditing(null)
    update((d) => actions.deleteIncomeType(d, type))
  }

  function addSource(incomeType?: string) {
    const id = data.nextId
    update((d) => actions.addSource(d, incomeType))
    setEditing(id)
  }

  return (
    <div className="flex flex-col gap-4">
      <TabToolbar
        summary={
          <>
            Gross <strong>{formatUSD(summary.gross)}</strong> · Take-home{" "}
            <strong>{formatUSD(summary.earn)}</strong>
          </>
        }
        actions={
          <>
            <Button variant="outline" onClick={addIncomeType}>
              <LuFolderPlus />
              Income type
            </Button>
            <Button onClick={() => addSource()}>
              <LuPlus />
              Add source
            </Button>
          </>
        }
      />

      <GroupedList
        moves={{
          moveItemBefore: (id, target) =>
            update((d) => actions.moveSourceBefore(d, id, target)),
          moveItemToGroup: (id, type) =>
            update((d) => actions.moveSourceToType(d, id, type)),
          moveGroup: (type, before) =>
            update((d) => actions.moveIncomeType(d, type, before)),
        }}
      >
        {data.incomeTypes.map((type, typeIndex) => {
          const sources = data.income.filter(
            (s) => (s.incomeType || "Other") === type
          )
          const gross = sources.reduce((sum, s) => sum + monthlyGross(s), 0)
          const net = sources.reduce(
            (sum, s) => sum + monthlyNet(s, data.taxRate),
            0
          )
          return (
            <GroupCard
              key={type}
              group={type}
              label={type}
              color={incomeColor(typeIndex)}
              actions={
                <>
                  <Button
                    variant="ghost"
                    size="xs"
                    className="text-muted-foreground"
                    onClick={() => addSource(type)}
                  >
                    <LuPlus />
                    Source
                  </Button>
                  <DropdownMenu>
                    <DropdownMenuTrigger
                      render={
                        <Button
                          variant="ghost"
                          size="icon-xs"
                          className="text-muted-foreground"
                          aria-label={`${type} options`}
                        />
                      }
                    >
                      <LuEllipsis />
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-40">
                      <DropdownMenuItem onClick={() => renameIncomeType(type)}>
                        <LuPencil />
                        Rename
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => deleteIncomeType(type)}
                      >
                        <LuTrash2 />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </>
              }
              summary={
                <>
                  <span className="font-medium tabular-nums">
                    {formatUSD(gross)}
                  </span>
                  <span className="ml-1.5 text-xs text-muted-foreground tabular-nums">
                    {formatUSD(net)} take-home
                  </span>
                </>
              }
            >
              {sources.length === 0 ? (
                <p className="px-4 py-5 text-center text-sm text-muted-foreground">
                  No sources yet. Drag one here or add a source.
                </p>
              ) : (
                <Table className="min-w-[54rem] table-fixed">
                  <colgroup>
                    <col className="w-10" />
                    <col />
                    <col className="w-24" />
                    <col className="w-24" />
                    <col className="w-40" />
                    <col className="w-36" />
                    <col className="w-28" />
                    <col className="w-12" />
                  </colgroup>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead />
                      <TableHead>Source</TableHead>
                      <TableHead>Tax</TableHead>
                      <TableHead>Pay</TableHead>
                      <TableHead>Rate / hours</TableHead>
                      <TableHead>Payday</TableHead>
                      <TableHead className="text-right">Monthly</TableHead>
                      <TableHead />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {sources.map((source) =>
                      editing === source.id ? (
                        <TableRow
                          key={source.id}
                          className="hover:bg-transparent"
                        >
                          <TableCell
                            colSpan={COLUMNS}
                            className="p-0 whitespace-normal"
                          >
                            <SourceEditor
                              source={source}
                              incomeTypes={data.incomeTypes}
                              taxRate={data.taxRate}
                              onChange={(changes) =>
                                update((d) =>
                                  actions.updateSource(d, source.id, changes)
                                )
                              }
                              onTogglePayday={(day) =>
                                update((d) =>
                                  actions.togglePaydayDate(d, source.id, day)
                                )
                              }
                              onToggleWeekday={(weekday) =>
                                update((d) =>
                                  actions.togglePaydayWeekday(
                                    d,
                                    source.id,
                                    weekday
                                  )
                                )
                              }
                              onDone={() => setEditing(null)}
                              onDelete={() => {
                                setEditing(null)
                                update((d) =>
                                  actions.deleteSource(d, source.id)
                                )
                              }}
                            />
                          </TableCell>
                        </TableRow>
                      ) : (
                        <SourceRow
                          key={source.id}
                          source={source}
                          color={incomeColor(
                            data.income.findIndex((s) => s.id === source.id)
                          )}
                          taxRate={data.taxRate}
                          onEdit={() => setEditing(source.id)}
                          onToggleCalendar={() =>
                            update((d) =>
                              actions.toggleSourceOnCalendar(d, source.id)
                            )
                          }
                        />
                      )
                    )}
                  </TableBody>
                </Table>
              )}
            </GroupCard>
          )
        })}
      </GroupedList>

      <Hint>
        Click a source to edit · drag <LuGripVertical /> to reorder or move
        between types · <LuEye /> shows or hides it on the calendar
      </Hint>
    </div>
  )
}

function SourceRow({
  source,
  color,
  taxRate,
  onEdit,
  onToggleCalendar,
}: {
  source: IncomeSource
  color: string
  taxRate: number
  onEdit: () => void
  onToggleCalendar: () => void
}) {
  const rateInfo =
    source.payType === "Hourly"
      ? `${formatUSD(source.rate || 0)}/hr × ${source.hrsPerWeek || 0}h/wk`
      : source.rate
        ? `Bonus ${formatUSD(source.rate)}/yr`
        : "—"
  const payday =
    source.paydayType === "weekdays"
      ? weekdaysLabel(source.paydayWeekdays)
      : datesLabel(source.paydayDates)

  return (
    <DraggableRow
      id={source.id}
      label={source.name}
      color={color}
      className="cursor-pointer"
      onClick={onEdit}
    >
      {(handle) => (
        <>
          <TableCell className="pl-2">{handle}</TableCell>
          <TableCell className="truncate font-medium">{source.name}</TableCell>
          <TableCell>
            <Badge
              variant="secondary"
              className={cn(
                source.type === "Taxed"
                  ? "bg-sky-500/10 text-sky-700 dark:text-sky-300"
                  : "bg-amber-500/10 text-amber-700 dark:text-amber-300"
              )}
            >
              {source.type}
            </Badge>
          </TableCell>
          <TableCell>
            <Badge variant="outline" className="text-muted-foreground">
              {source.payType}
            </Badge>
          </TableCell>
          <TableCell className="truncate text-muted-foreground tabular-nums">
            {rateInfo}
          </TableCell>
          <TableCell className="truncate text-muted-foreground" title={payday}>
            {payday}
          </TableCell>
          <TableCell className="text-right tabular-nums">
            <div className="font-medium text-positive">
              {formatUSD(monthlyGross(source))}
            </div>
            <div className="text-xs text-muted-foreground">
              {formatUSD(monthlyNet(source, taxRate))}
            </div>
          </TableCell>
          <TableCell className="pr-2 text-right">
            <CalendarToggle
              shown={source.showOnCal !== false}
              color={color}
              name={source.name}
              onToggle={onToggleCalendar}
            />
          </TableCell>
        </>
      )}
    </DraggableRow>
  )
}

function SourceEditor({
  source,
  incomeTypes,
  taxRate,
  onChange,
  onTogglePayday,
  onToggleWeekday,
  onDone,
  onDelete,
}: {
  source: IncomeSource
  incomeTypes: string[]
  taxRate: number
  onChange: (changes: Partial<IncomeSource>) => void
  onTogglePayday: (day: number) => void
  onToggleWeekday: (weekday: number) => void
  onDone: () => void
  onDelete: () => void
}) {
  const id = (field: string) => `source-${source.id}-${field}`
  const hourly = source.payType === "Hourly"

  return (
    <EditorPanel onDone={onDone} onDelete={onDelete}>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <EditorField label="Name" htmlFor={id("name")}>
          <Input
            id={id("name")}
            value={source.name}
            onChange={(event) => onChange({ name: event.target.value })}
          />
        </EditorField>
        <EditorField label="Income type" htmlFor={id("type")}>
          <OptionSelect
            id={id("type")}
            value={source.incomeType}
            options={incomeTypes}
            onChange={(incomeType) => onChange({ incomeType })}
          />
        </EditorField>
        <EditorField label="Tax" htmlFor={id("tax")}>
          <OptionSelect
            id={id("tax")}
            value={source.type}
            options={["Taxed", "Untaxed"] as const}
            onChange={(type) => onChange({ type })}
          />
        </EditorField>
        <EditorField label="Pay structure" htmlFor={id("pay")}>
          <OptionSelect
            id={id("pay")}
            value={source.payType}
            options={["Salary", "Hourly"] as const}
            onChange={(payType) => onChange({ payType })}
          />
        </EditorField>
      </div>

      {hourly ? (
        <div className="grid gap-3 sm:grid-cols-3">
          <EditorField label="Rate per hour" htmlFor={id("rate")}>
            <MoneyInput
              id={id("rate")}
              value={source.rate}
              onValueChange={(rate) => onChange({ rate: rate ?? 0 })}
            />
          </EditorField>
          <EditorField label="Hours per week" htmlFor={id("hours")}>
            <NumberInput
              id={id("hours")}
              min={0}
              className="tabular-nums"
              value={source.hrsPerWeek}
              onValueChange={(hrsPerWeek) =>
                onChange({ hrsPerWeek: hrsPerWeek ?? 0 })
              }
            />
          </EditorField>
          <EditorField label="Monthly (4 weeks)" htmlFor={id("monthly")}>
            <Input
              id={id("monthly")}
              disabled
              className="tabular-nums"
              value={`${formatUSD(monthlyGross(source))} · ${formatUSD(monthlyNet(source, taxRate))} take-home`}
            />
          </EditorField>
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-3">
          <EditorField label="Monthly salary" htmlFor={id("salary")}>
            <MoneyInput
              id={id("salary")}
              value={source.monthly}
              onValueChange={(monthly) => onChange({ monthly: monthly ?? 0 })}
            />
          </EditorField>
          <EditorField label="Annual bonus (optional)" htmlFor={id("bonus")}>
            <MoneyInput
              id={id("bonus")}
              placeholder="0"
              value={source.rate}
              onValueChange={(rate) => onChange({ rate })}
            />
          </EditorField>
          <p className="self-end pb-1.5 text-xs text-muted-foreground">
            The bonus counts toward the annual summary only, not the monthly
            GAME.
          </p>
        </div>
      )}

      <EditorField label="Payday">
        <div className="flex flex-col gap-3">
          <ScheduleKindToggle
            value={source.paydayType}
            onChange={(paydayType) => onChange({ paydayType })}
            datesLabel="Specific dates"
            weekdaysLabel="Days of week"
          />
          {source.paydayType === "weekdays" ? (
            <WeekdayToggles
              label="Paydays"
              value={source.paydayWeekdays}
              onToggle={onToggleWeekday}
            />
          ) : (
            <MonthDayToggles
              label="Paydays"
              value={source.paydayDates}
              onToggle={onTogglePayday}
            />
          )}
          <p className="text-xs text-muted-foreground">
            Paydays on a weekend show on the following Monday in the calendar.
          </p>
        </div>
      </EditorField>
    </EditorPanel>
  )
}
