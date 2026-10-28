import { useState } from "react"
import {
  LuEllipsis,
  LuFolderPlus,
  LuGripVertical,
  LuPencil,
  LuPlus,
  LuTrash2,
} from "react-icons/lu"

import { useDialogs } from "@/components/dialogs"
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
import * as actions from "@/pages/tracker/actions"
import {
  DayOfMonthSelect,
  EditorField,
  EditorPanel,
  Hint,
  MoneyInput,
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
  categoryColor,
  dueLabel,
  monthlyCost,
  UNCATEGORIZED,
  type Expense,
} from "@/pages/tracker/model"
import type { TrackerApi } from "@/pages/tracker/use-tracker"

export function ExpensesTab({ data, summary, update }: TrackerApi) {
  const [editing, setEditing] = useState<number | null>(null)
  const { prompt, confirm } = useDialogs()
  const uncategorized = data.expenses.filter((e) => e.cat === UNCATEGORIZED)

  const nameError = (name: string, current?: string) =>
    !name
      ? { field: "name" as const, message: "Enter a name." }
      : name !== current &&
          (data.categories.includes(name) || name === UNCATEGORIZED)
        ? { field: "name" as const, message: "That category already exists." }
        : null

  async function addCategory() {
    const values = await prompt({
      title: "New category",
      fields: [{ name: "name", label: "Name", placeholder: "e.g. Travel" }],
      confirmLabel: "Add category",
      validate: ({ name }) => nameError(name),
    })
    if (values) update((d) => actions.addCategory(d, values.name))
  }

  async function renameCategory(category: string) {
    const values = await prompt({
      title: "Rename category",
      fields: [{ name: "name", label: "Name", defaultValue: category }],
      validate: ({ name }) => nameError(name, category),
    })
    if (values && values.name !== category) {
      update((d) => actions.renameCategory(d, category, values.name))
    }
  }

  async function deleteCategory(category: string) {
    const count = data.expenses.filter((e) => e.cat === category).length
    if (count) {
      const ok = await confirm({
        title: `Delete "${category}"?`,
        description: `Its ${count} expense${count === 1 ? "" : "s"} will move to the review list until you pick a new category.`,
        confirmLabel: "Delete",
        destructive: true,
      })
      if (!ok) return
    }
    setEditing(null)
    update((d) => actions.deleteCategory(d, category))
  }

  function addExpense(category?: string) {
    const id = data.nextId
    update((d) => actions.addExpense(d, category))
    setEditing(id)
  }

  const table = (items: Expense[]) => (
    <ExpenseTable
      items={items}
      editing={editing}
      categories={data.categories}
      color={(e) => categoryColor(data, e.cat)}
      onEdit={setEditing}
      onChange={(id, changes) =>
        update((d) => actions.updateExpense(d, id, changes))
      }
      onToggleWeekday={(id, weekday) =>
        update((d) => actions.toggleExpenseWeekday(d, id, weekday))
      }
      onDelete={(id) => {
        setEditing(null)
        update((d) => actions.deleteExpense(d, id))
      }}
    />
  )

  return (
    <div className="flex flex-col gap-4">
      <TabToolbar
        summary={
          <>
            Total <strong>{formatUSD(summary.expenses)}</strong>/mo across{" "}
            {summary.expenseCount} expense
            {summary.expenseCount === 1 ? "" : "s"}
          </>
        }
        actions={
          <>
            <Button variant="outline" onClick={addCategory}>
              <LuFolderPlus />
              Category
            </Button>
            <Button onClick={() => addExpense()}>
              <LuPlus />
              Add expense
            </Button>
          </>
        }
      />

      <GroupedList
        moves={{
          moveItemBefore: (id, target) =>
            update((d) => actions.moveExpenseBefore(d, id, target)),
          moveItemToGroup: (id, category) =>
            update((d) => actions.moveExpenseToCategory(d, id, category)),
          moveGroup: (category, before) =>
            update((d) => actions.moveCategory(d, category, before)),
        }}
      >
        {uncategorized.length > 0 && (
          <GroupCard
            group={UNCATEGORIZED}
            label="Review: assign a category"
            color="var(--warning)"
            tone="warning"
            draggable={false}
            summary={
              <span className="text-xs text-muted-foreground">
                {uncategorized.length} item
                {uncategorized.length === 1 ? " needs" : "s need"} a category
              </span>
            }
          >
            {table(uncategorized)}
          </GroupCard>
        )}
        {data.categories.map((category) => {
          const items = data.expenses.filter((e) => e.cat === category)
          const total = summary.byCategory[category] || 0
          const share =
            summary.earn > 0 ? Math.round((total / summary.earn) * 100) : 0
          return (
            <GroupCard
              key={category}
              group={category}
              label={category}
              color={categoryColor(data, category)}
              actions={
                <>
                  <Button
                    variant="ghost"
                    size="xs"
                    className="text-muted-foreground"
                    onClick={() => addExpense(category)}
                  >
                    <LuPlus />
                    Expense
                  </Button>
                  <DropdownMenu>
                    <DropdownMenuTrigger
                      render={
                        <Button
                          variant="ghost"
                          size="icon-xs"
                          className="text-muted-foreground"
                          aria-label={`${category} options`}
                        />
                      }
                    >
                      <LuEllipsis />
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-40">
                      <DropdownMenuItem
                        onClick={() => renameCategory(category)}
                      >
                        <LuPencil />
                        Rename
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => deleteCategory(category)}
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
                    {formatUSD(total)}
                  </span>
                  <span className="ml-1.5 text-xs text-muted-foreground tabular-nums">
                    {share}% of take-home
                  </span>
                </>
              }
            >
              {table(items)}
            </GroupCard>
          )
        })}
      </GroupedList>

      <Hint>
        Click an expense to edit · drag <LuGripVertical /> to reorder or move
        between categories
      </Hint>
    </div>
  )
}

function ExpenseTable({
  items,
  editing,
  categories,
  color,
  onEdit,
  onChange,
  onToggleWeekday,
  onDelete,
}: {
  items: Expense[]
  editing: number | null
  categories: string[]
  color: (expense: Expense) => string
  onEdit: (id: number | null) => void
  onChange: (id: number, changes: Partial<Expense>) => void
  onToggleWeekday: (id: number, weekday: number) => void
  onDelete: (id: number) => void
}) {
  if (items.length === 0) {
    return (
      <p className="px-4 py-5 text-center text-sm text-muted-foreground">
        No expenses yet. Drag one here or add an expense.
      </p>
    )
  }
  return (
    <Table className="min-w-[30rem] table-fixed">
      <colgroup>
        <col className="w-10" />
        <col />
        <col className="w-40" />
        <col className="w-48" />
      </colgroup>
      <TableHeader className="sr-only">
        <TableRow>
          <TableHead />
          <TableHead>Expense</TableHead>
          <TableHead>Due</TableHead>
          <TableHead>Cost</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {items.map((expense) =>
          editing === expense.id ? (
            <TableRow key={expense.id} className="hover:bg-transparent">
              <TableCell colSpan={4} className="p-0 whitespace-normal">
                <ExpenseEditor
                  expense={expense}
                  categories={categories}
                  onChange={(changes) => onChange(expense.id, changes)}
                  onToggleWeekday={(weekday) =>
                    onToggleWeekday(expense.id, weekday)
                  }
                  onDone={() => onEdit(null)}
                  onDelete={() => onDelete(expense.id)}
                />
              </TableCell>
            </TableRow>
          ) : (
            <ExpenseRow
              key={expense.id}
              expense={expense}
              color={color(expense)}
              onEdit={() => onEdit(expense.id)}
            />
          )
        )}
      </TableBody>
    </Table>
  )
}

function ExpenseRow({
  expense,
  color,
  onEdit,
}: {
  expense: Expense
  color: string
  onEdit: () => void
}) {
  const weekly = expense.dueType === "weekdays"
  return (
    <DraggableRow
      id={expense.id}
      label={expense.name}
      color={color}
      className="cursor-pointer"
      onClick={onEdit}
    >
      {(handle) => (
        <>
          <TableCell className="pl-2">{handle}</TableCell>
          <TableCell className="truncate font-medium">{expense.name}</TableCell>
          <TableCell className="truncate text-muted-foreground">
            {dueLabel(expense)}
          </TableCell>
          <TableCell className="pr-4 text-right tabular-nums">
            <span className="font-medium">{formatUSD(expense.cost)}</span>
            {weekly && (
              <span className="ml-1.5 text-xs text-muted-foreground">
                each · {formatUSD(monthlyCost(expense))}/mo
              </span>
            )}
          </TableCell>
        </>
      )}
    </DraggableRow>
  )
}

function ExpenseEditor({
  expense,
  categories,
  onChange,
  onToggleWeekday,
  onDone,
  onDelete,
}: {
  expense: Expense
  categories: string[]
  onChange: (changes: Partial<Expense>) => void
  onToggleWeekday: (weekday: number) => void
  onDone: () => void
  onDelete: () => void
}) {
  const id = (field: string) => `expense-${expense.id}-${field}`
  const weekly = expense.dueType === "weekdays"

  return (
    <EditorPanel onDone={onDone} onDelete={onDelete}>
      <div className="grid gap-3 sm:grid-cols-[1.2fr_1fr_0.8fr]">
        <EditorField label="Name" htmlFor={id("name")}>
          <Input
            id={id("name")}
            value={expense.name}
            onChange={(event) => onChange({ name: event.target.value })}
          />
        </EditorField>
        <EditorField label="Category" htmlFor={id("category")}>
          <OptionSelect
            id={id("category")}
            value={expense.cat}
            options={[...categories, UNCATEGORIZED]}
            onChange={(cat) => onChange({ cat })}
          />
        </EditorField>
        <EditorField
          label={weekly ? "Cost per occurrence" : "Monthly cost"}
          htmlFor={id("cost")}
        >
          <MoneyInput
            id={id("cost")}
            value={expense.cost}
            onValueChange={(cost) => onChange({ cost: cost ?? 0 })}
          />
        </EditorField>
      </div>
      <EditorField label="Payment day">
        <div className="flex flex-col gap-3">
          <ScheduleKindToggle
            value={expense.dueType}
            onChange={(dueType) => onChange({ dueType })}
            datesLabel="Specific date"
            weekdaysLabel="Days of week"
          />
          {weekly ? (
            <WeekdayToggles
              label="Payment days"
              value={expense.dueWeekdays}
              onToggle={onToggleWeekday}
            />
          ) : (
            <DayOfMonthSelect
              id={id("due")}
              value={expense.due}
              onChange={(due) => onChange({ due })}
            />
          )}
        </div>
      </EditorField>
    </EditorPanel>
  )
}
