import { useState, type ReactNode } from "react"
import {
  DndContext,
  DragOverlay,
  useDndContext,
  useDraggable,
  useDroppable,
  type Data,
} from "@dnd-kit/core"

import { Card } from "@/components/ui/card"
import { TableRow } from "@/components/ui/table"
import { cn } from "@/lib/utils"
import { ColorDot } from "@/pages/tracker/components"
import {
  collisionFor,
  DragChip,
  DragHandle,
  DropLine,
  useDragSensors,
} from "@/pages/tracker/dnd"

/*
 * Cards of rows (income types with their sources, expense categories with
 * their expenses). Rows can be dropped on another row (to take its place and
 * group) or on a card (to become its last row). Cards can be reordered.
 */

type ItemData = { type: "item"; id: number; label: string; color: string }
type GroupData = {
  type: "group"
  group: string
  label: string
  color: string
  /** False for fixed cards, which accept rows but not other cards. */
  sortable: boolean
}

const collision = collisionFor(
  (active, target) => {
    if (active?.type === "item") {
      return (
        (target?.type === "item" && target.id !== active.id) ||
        target?.type === "group"
      )
    }
    if (active?.type === "group") {
      return (
        (target?.type === "group" &&
          target.sortable &&
          target.group !== active.group) ||
        target?.type === "end"
      )
    }
    return false
  },
  (target) => (target?.type === "item" ? 2 : target?.type === "group" ? 1 : 0)
)

export type GroupedListMoves = {
  moveItemBefore: (id: number, targetId: number) => void
  moveItemToGroup: (id: number, group: string) => void
  moveGroup: (group: string, before: string | null) => void
}

export function GroupedList({
  moves,
  children,
}: {
  moves: GroupedListMoves
  children: ReactNode
}) {
  const sensors = useDragSensors()
  const [dragged, setDragged] = useState<ItemData | GroupData | null>(null)

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={collision}
      onDragStart={({ active }) =>
        setDragged((active.data.current as ItemData | GroupData) ?? null)
      }
      onDragCancel={() => setDragged(null)}
      onDragEnd={({ active, over }) => {
        setDragged(null)
        const from = active.data.current as ItemData | GroupData | undefined
        const to = over?.data.current
        if (!from || !to) return
        if (from.type === "item") {
          if (to.type === "item") moves.moveItemBefore(from.id, to.id)
          else if (to.type === "group") moves.moveItemToGroup(from.id, to.group)
        } else if (to.type === "group") {
          moves.moveGroup(from.group, to.group)
        } else if (to.type === "end") {
          moves.moveGroup(from.group, null)
        }
      }}
    >
      <div className="flex flex-col gap-3">
        {children}
        <EndZone />
      </div>
      <DragOverlay dropAnimation={null}>
        {dragged && <DragChip color={dragged.color}>{dragged.label}</DragChip>}
      </DragOverlay>
    </DndContext>
  )
}

/** Drop target after the last card, for moving a card to the end. */
function EndZone() {
  const { active } = useDndContext()
  const { setNodeRef, isOver } = useDroppable({
    id: "group-end",
    data: { type: "end" },
  })
  return (
    <div ref={setNodeRef} className="relative -mt-3 h-8">
      {isOver && active?.data.current?.type === "group" && (
        <DropLine className="top-1.5" />
      )}
    </div>
  )
}

export function GroupCard({
  group,
  label,
  color,
  draggable = true,
  tone = "default",
  actions,
  summary,
  children,
}: {
  group: string
  label: ReactNode
  color: string
  /** The review list of uncategorized items stays put. */
  draggable?: boolean
  tone?: "default" | "warning"
  actions?: ReactNode
  summary?: ReactNode
  children: ReactNode
}) {
  const { active } = useDndContext()
  const data: GroupData = {
    type: "group",
    group,
    label: group,
    color,
    sortable: draggable,
  }
  const drag = useDraggable({
    id: `group:${group}`,
    data,
    disabled: !draggable,
  })
  const drop = useDroppable({ id: `group-drop:${group}`, data })
  const activeType = (active?.data.current as Data | undefined)?.type

  return (
    <section
      ref={(element) => {
        drag.setNodeRef(element)
        drop.setNodeRef(element)
      }}
      aria-label={group}
      className="relative"
    >
      {drop.isOver && activeType === "group" && <DropLine className="-top-2" />}
      <Card
        className={cn(
          "@container gap-0 py-0 transition-[box-shadow,opacity]",
          tone === "warning" && "ring-warning/50",
          drag.isDragging && "opacity-40",
          drop.isOver && activeType === "item" && "ring-2 ring-primary"
        )}
      >
        <div
          className={cn(
            "flex min-h-11 flex-wrap items-center gap-x-2 gap-y-1 border-b px-3 py-1.5",
            tone === "warning" ? "bg-warning/10" : "bg-muted/40"
          )}
        >
          {draggable && (
            <DragHandle
              label={`Reorder ${group}`}
              attributes={drag.attributes}
              listeners={drag.listeners}
              setActivatorNodeRef={drag.setActivatorNodeRef}
            />
          )}
          <ColorDot color={color} />
          <span className="font-medium">{label}</span>
          {actions}
          {summary && <div className="ml-auto text-right">{summary}</div>}
        </div>
        {children}
      </Card>
    </section>
  )
}

/** A table row inside a GroupCard that can be dragged by its handle. */
export function DraggableRow({
  id,
  label,
  color,
  className,
  onClick,
  children,
}: {
  id: number
  label: string
  color: string
  className?: string
  onClick?: () => void
  /** Receives the drag handle to place in the first cell. */
  children: (handle: ReactNode) => ReactNode
}) {
  const { active } = useDndContext()
  const data: ItemData = { type: "item", id, label, color }
  const drag = useDraggable({ id: `item:${id}`, data })
  const drop = useDroppable({ id: `item-drop:${id}`, data })

  return (
    <TableRow
      ref={(element) => {
        drag.setNodeRef(element)
        drop.setNodeRef(element)
      }}
      className={cn(
        className,
        drag.isDragging && "opacity-40",
        // A line on top of the row shows where the dragged row will land.
        drop.isOver &&
          active?.data.current?.type === "item" &&
          "[&>td]:shadow-[inset_0_2px_0_0_var(--color-primary)]"
      )}
      onClick={onClick}
    >
      {children(
        <DragHandle
          label={`Reorder ${label}`}
          attributes={drag.attributes}
          listeners={drag.listeners}
          setActivatorNodeRef={drag.setActivatorNodeRef}
        />
      )}
    </TableRow>
  )
}
