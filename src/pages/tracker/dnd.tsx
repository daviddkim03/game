import type { ReactNode } from "react"
import {
  KeyboardSensor,
  PointerSensor,
  pointerWithin,
  rectIntersection,
  useSensor,
  useSensors,
  type CollisionDetection,
  type Data,
  type DraggableAttributes,
  type DraggableSyntheticListeners,
} from "@dnd-kit/core"
import { LuGripVertical } from "react-icons/lu"

import { cn } from "@/lib/utils"
import { ColorDot } from "@/pages/tracker/components"

/** A press only becomes a drag after a few pixels, so clicks still work. */
export function useDragSensors() {
  return useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor)
  )
}

/**
 * Picks the drop target under the pointer among those that accept the dragged
 * item. When several overlap (a row inside a card), the one with the highest
 * `priority` wins.
 */
export function collisionFor(
  accepts: (active: Data | undefined, target: Data | undefined) => boolean,
  priority: (target: Data | undefined) => number = () => 0
): CollisionDetection {
  return (args) => {
    const active = args.active.data.current
    const scoped = {
      ...args,
      droppableContainers: args.droppableContainers.filter((container) =>
        accepts(active, container.data.current)
      ),
    }
    const hits = args.pointerCoordinates
      ? pointerWithin(scoped)
      : rectIntersection(scoped)
    const dataOf = (hit: (typeof hits)[number]) =>
      hit.data?.droppableContainer?.data.current as Data | undefined
    return hits
      .sort((a, b) => priority(dataOf(b)) - priority(dataOf(a)))
      .slice(0, 1)
  }
}

export function DragHandle({
  label,
  attributes,
  listeners,
  setActivatorNodeRef,
  className,
}: {
  label: string
  attributes: DraggableAttributes
  listeners: DraggableSyntheticListeners
  setActivatorNodeRef: (element: HTMLElement | null) => void
  className?: string
}) {
  return (
    <button
      type="button"
      ref={setActivatorNodeRef}
      {...attributes}
      {...listeners}
      aria-label={label}
      onClick={(event) => event.stopPropagation()}
      className={cn(
        "flex size-6 shrink-0 cursor-grab touch-none items-center justify-center rounded-md text-muted-foreground/60 outline-none hover:bg-muted hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 active:cursor-grabbing",
        className
      )}
    >
      <LuGripVertical className="size-4" />
    </button>
  )
}

/** What follows the pointer while dragging a row or a card. */
export function DragChip({
  color,
  children,
}: {
  color?: string
  children: ReactNode
}) {
  return (
    <div className="flex w-fit cursor-grabbing items-center gap-2 rounded-lg bg-popover px-3 py-1.5 text-sm font-medium text-popover-foreground shadow-lg ring-1 ring-foreground/10">
      {color && <ColorDot color={color} />}
      {children}
    </div>
  )
}

/** The line that shows where a dragged item will land. */
export function DropLine({ className }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={cn(
        "pointer-events-none absolute inset-x-0 top-0 z-10 h-0.5 rounded-full bg-primary",
        className
      )}
    />
  )
}
