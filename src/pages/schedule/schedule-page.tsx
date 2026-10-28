import {
  useEffect,
  useRef,
  useState,
  type MouseEvent as ReactMouseEvent,
  type PointerEvent as ReactPointerEvent,
} from "react"
import { LuPlus, LuTrash2, LuX } from "react-icons/lu"

import { AppHeader } from "@/components/app-header"
import { useDialogs } from "@/components/dialogs"
import { Button } from "@/components/ui/button"
import { Kbd, KbdGroup } from "@/components/ui/kbd"
import { useSyncedState } from "@/hooks/use-synced-state"
import { getApp } from "@/lib/apps"
import { cn } from "@/lib/utils"
import { BlockDialog, type BlockDraft } from "@/pages/schedule/block-dialog"
import { ColorSwatches } from "@/pages/schedule/color-swatches"
import {
  clampSlot,
  DAY_TO_WEEKDAY,
  DAYS,
  emptySchedule,
  H_START,
  placeBlock,
  reviveSchedule,
  SLOT_COUNT,
  SLOT_HEIGHT,
  slotLabel,
  STORAGE_KEY,
  type Block,
} from "@/pages/schedule/model"

const MAX_HISTORY = 50
/** Pointer travel (px) before a press counts as a drag rather than a click. */
const DRAG_THRESHOLD = 4
const GUTTER = "w-[4.25rem]"
const IS_MAC = /Mac|iPhone|iPad/.test(navigator.platform)
const MOD_KEY = IS_MAC ? "⌘" : "Ctrl"

type Slot = { day: number; slot: number }
type Ghost = {
  day: number
  start: number
  end: number
  color: string
  label?: string
}

function slotAt(column: HTMLElement, clientY: number) {
  return clampSlot(
    Math.floor((clientY - column.getBoundingClientRect().top) / SLOT_HEIGHT)
  )
}

/** Runs a pointer drag until release; `onEnd` gets whether it was cancelled. */
function trackPointer(
  onMove: (event: PointerEvent) => void,
  onEnd: (cancelled: boolean) => void
) {
  const up = () => finish(false)
  const cancel = () => finish(true)
  function finish(cancelled: boolean) {
    window.removeEventListener("pointermove", onMove)
    window.removeEventListener("pointerup", up)
    window.removeEventListener("pointercancel", cancel)
    onEnd(cancelled)
  }
  window.addEventListener("pointermove", onMove)
  window.addEventListener("pointerup", up)
  window.addEventListener("pointercancel", cancel)
}

function movedPastThreshold(
  origin: { x: number; y: number },
  event: PointerEvent
) {
  return (
    Math.abs(event.clientX - origin.x) + Math.abs(event.clientY - origin.y) >=
    DRAG_THRESHOLD
  )
}

export function SchedulePage() {
  const [schedule, setSchedule] = useSyncedState({
    pageId: getApp("schedule").syncId,
    storageKey: STORAGE_KEY,
    initial: emptySchedule,
    revive: reviveSchedule,
  })
  const { confirm } = useDialogs()

  // Live result while resizing; committed (and saved) on release.
  const [preview, setPreview] = useState<{
    blocks: Block[]
    nextId: number
  } | null>(null)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [selectedSlot, setSelectedSlot] = useState<Slot | null>(null)
  const [copied, setCopied] = useState<Block | null>(null)
  const [createGhost, setCreateGhost] = useState<Ghost | null>(null)
  const [moveGhost, setMoveGhost] = useState<(Ghost & { id: number }) | null>(
    null
  )
  const [editorOpen, setEditorOpen] = useState(false)
  const [draft, setDraft] = useState<BlockDraft | null>(null)
  const history = useRef<Block[][]>([])
  const columns = useRef<(HTMLDivElement | null)[]>([])
  const suppressClick = useRef(false)
  const now = useNow()

  const blocks = preview?.blocks ?? schedule.blocks

  function pushHistory(snapshot: Block[]) {
    history.current.push(snapshot)
    if (history.current.length > MAX_HISTORY) history.current.shift()
  }

  function commit(
    next: { blocks: Block[]; nextId: number },
    snapshot: Block[]
  ) {
    pushHistory(snapshot)
    setSchedule((current) => ({ ...current, ...next }))
  }

  function undo() {
    const previous = history.current.pop()
    if (!previous) return
    setSchedule((current) => ({ ...current, blocks: previous }))
    setSelectedId(null)
    setSelectedSlot(null)
  }

  function deleteBlock(id: number) {
    commit(
      {
        blocks: schedule.blocks.filter((b) => b.id !== id),
        nextId: schedule.nextId,
      },
      schedule.blocks
    )
    if (selectedId === id) setSelectedId(null)
  }

  async function clearAll() {
    const ok = await confirm({
      title: "Clear the whole week?",
      description:
        "Every block is removed. You can undo this with " + MOD_KEY + "+Z.",
      confirmLabel: "Clear all",
      destructive: true,
    })
    if (!ok) return
    commit({ blocks: [], nextId: schedule.nextId }, schedule.blocks)
    setSelectedId(null)
  }

  function paste() {
    if (!copied || !selectedSlot) return
    const duration = copied.end - copied.start
    const start = Math.max(
      0,
      Math.min(SLOT_COUNT - duration, selectedSlot.slot)
    )
    const block: Block = {
      id: schedule.nextId,
      label: copied.label,
      day: selectedSlot.day,
      start,
      end: start + duration,
      color: copied.color,
    }
    commit(
      placeBlock(schedule.blocks, block, schedule.nextId + 1),
      schedule.blocks
    )
    setSelectedSlot(null)
  }

  /* ── Dialog ── */

  function openAdd(range?: { day: number; start: number; end: number }) {
    setDraft({
      id: null,
      label: "",
      day: range?.day ?? 0,
      start: range?.start ?? 0,
      end: range?.end ?? 2,
      color: schedule.selColor,
    })
    setEditorOpen(true)
  }

  function openEdit(block: Block) {
    setDraft({ ...block })
    setEditorOpen(true)
  }

  function saveDraft(saved: BlockDraft) {
    const isNew = saved.id === null
    const block: Block = { ...saved, id: saved.id ?? schedule.nextId }
    const result = placeBlock(
      schedule.blocks,
      block,
      isNew ? schedule.nextId + 1 : schedule.nextId
    )
    pushHistory(schedule.blocks)
    setSchedule((current) => ({ ...current, ...result, selColor: saved.color }))
    setEditorOpen(false)
  }

  function deleteFromDialog(id: number) {
    deleteBlock(id)
    setEditorOpen(false)
  }

  /* ── Pointer interactions ── */

  function startCreate(event: ReactPointerEvent<HTMLDivElement>, day: number) {
    if (event.button !== 0 || event.pointerType === "touch") return
    if ((event.target as HTMLElement).closest("[data-slot=schedule-block]")) {
      return
    }
    event.preventDefault()
    const column = event.currentTarget
    const startSlot = slotAt(column, event.clientY)
    const origin = { x: event.clientX, y: event.clientY }
    let moved = false
    let endSlot = startSlot

    trackPointer(
      (move) => {
        if (!moved && !movedPastThreshold(origin, move)) return
        moved = true
        endSlot = Math.max(startSlot, slotAt(column, move.clientY))
        setCreateGhost({
          day,
          start: startSlot,
          end: endSlot + 1,
          color: schedule.selColor,
        })
      },
      (cancelled) => {
        setCreateGhost(null)
        if (cancelled) return
        if (!moved) {
          // A plain click picks this slot as the paste target.
          setSelectedId(null)
          setSelectedSlot({ day, slot: startSlot })
          return
        }
        openAdd({ day, start: startSlot, end: endSlot + 1 })
      }
    )
  }

  function startMove(event: ReactPointerEvent<HTMLDivElement>, block: Block) {
    if (event.button !== 0 || event.pointerType === "touch") return
    if (
      (event.target as HTMLElement).closest(
        "[data-slot=resize-handle],[data-slot=block-delete]"
      )
    ) {
      return
    }
    event.preventDefault()
    event.stopPropagation()
    const column = columns.current[block.day]!
    const grabOffset = slotAt(column, event.clientY) - block.start
    const duration = block.end - block.start
    const origin = { x: event.clientX, y: event.clientY }
    const snapshot = schedule.blocks
    let moved = false
    let target = { day: block.day, start: block.start }

    trackPointer(
      (move) => {
        if (!moved && !movedPastThreshold(origin, move)) return
        moved = true
        const column = document
          .elementFromPoint(move.clientX, move.clientY)
          ?.closest<HTMLElement>("[data-slot=day-column]")
        if (column) {
          const hovered = Math.floor(
            (move.clientY - column.getBoundingClientRect().top) / SLOT_HEIGHT
          )
          target = {
            day: Number(column.dataset.day),
            start: Math.max(
              0,
              Math.min(SLOT_COUNT - duration, hovered - grabOffset)
            ),
          }
        }
        setMoveGhost({
          id: block.id,
          day: target.day,
          start: target.start,
          end: target.start + duration,
          color: block.color,
          label: block.label,
        })
      },
      (cancelled) => {
        setMoveGhost(null)
        if (!moved) return
        suppressClick.current = true
        if (cancelled) return
        if (target.day === block.day && target.start === block.start) return
        commit(
          placeBlock(
            snapshot,
            {
              ...block,
              day: target.day,
              start: target.start,
              end: target.start + duration,
            },
            schedule.nextId
          ),
          snapshot
        )
      }
    )
  }

  function startResize(
    event: ReactPointerEvent<HTMLDivElement>,
    block: Block,
    edge: "start" | "end"
  ) {
    if (event.button !== 0 || event.pointerType === "touch") return
    event.preventDefault()
    event.stopPropagation()
    const column = columns.current[block.day]!
    // Every preview starts from this snapshot, so dragging back restores
    // anything that was temporarily covered.
    const base = { blocks: schedule.blocks, nextId: schedule.nextId }
    let result = base
    let current = block[edge]

    trackPointer(
      (move) => {
        const slot = slotAt(column, move.clientY)
        const next =
          edge === "start"
            ? Math.min(block.end - 1, slot)
            : Math.max(block.start + 1, slot + 1)
        if (next === current) return
        current = next
        result =
          next === block[edge]
            ? base
            : placeBlock(base.blocks, { ...block, [edge]: next }, base.nextId)
        setPreview(result)
      },
      (cancelled) => {
        setPreview(null)
        if (cancelled || result === base) return
        commit(result, base.blocks)
      }
    )
  }

  /* ── Keyboard ── */

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (editorOpen || event.defaultPrevented) return
      const target = event.target as HTMLElement
      // Dialogs keep focus while they animate closed, so only open ones count.
      if (
        target.closest(
          "input, select, textarea, [contenteditable=true], [role=menu][data-open], [role=dialog][data-open], [role=alertdialog][data-open]"
        )
      ) {
        return
      }
      const mod = event.ctrlKey || event.metaKey
      const key = event.key.toLowerCase()

      if (mod && key === "z" && !event.shiftKey) {
        event.preventDefault()
        undo()
      } else if (mod && key === "c") {
        const block = schedule.blocks.find((b) => b.id === selectedId)
        if (block) {
          event.preventDefault()
          setCopied(block)
        }
      } else if (mod && key === "v") {
        if (copied && selectedSlot) {
          event.preventDefault()
          paste()
        }
      } else if (event.key === "Escape") {
        setSelectedId(null)
        setSelectedSlot(null)
        setCopied(null)
      } else if (
        (event.key === "Delete" || event.key === "Backspace") &&
        selectedId !== null
      ) {
        event.preventDefault()
        deleteBlock(selectedId)
      }
    }
    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  })

  /* ── Render ── */

  const todayColumn = DAY_TO_WEEKDAY.indexOf(now.getDay())
  const nowOffset =
    (((now.getHours() - H_START) * 60 + now.getMinutes()) / 30) * SLOT_HEIGHT
  const showNow = nowOffset >= 0 && nowOffset <= SLOT_COUNT * SLOT_HEIGHT

  return (
    <div className="flex h-svh flex-col">
      <AppHeader
        current="schedule"
        actions={
          <>
            <Button
              variant="outline"
              onClick={clearAll}
              disabled={!schedule.blocks.length}
            >
              <LuTrash2 />
              <span className="hidden sm:inline">Clear all</span>
              <span className="sr-only sm:hidden">Clear all</span>
            </Button>
            <Button onClick={() => openAdd()}>
              <LuPlus />
              <span className="hidden sm:inline">Add block</span>
              <span className="sr-only sm:hidden">Add block</span>
            </Button>
          </>
        }
      />

      <div className="flex h-12 shrink-0 items-center gap-3 border-b px-3 sm:px-5">
        <span
          id="active-color-label"
          className="text-xs text-muted-foreground max-sm:sr-only"
        >
          New blocks
        </span>
        <ColorSwatches
          aria-labelledby="active-color-label"
          value={schedule.selColor}
          onValueChange={(selColor) =>
            setSchedule((current) => ({ ...current, selColor }))
          }
        />
        <div className="ml-auto hidden items-center gap-4 text-xs text-muted-foreground xl:flex">
          <span>Drag on the grid to add</span>
          <span>Double-click to edit</span>
          <span className="flex items-center gap-1.5">
            <KbdGroup>
              <Kbd>{MOD_KEY}</Kbd>
              <Kbd>C</Kbd>
            </KbdGroup>
            /
            <KbdGroup>
              <Kbd>{MOD_KEY}</Kbd>
              <Kbd>V</Kbd>
            </KbdGroup>
            copy &amp; paste
          </span>
          <span className="flex items-center gap-1.5">
            <KbdGroup>
              <Kbd>{MOD_KEY}</Kbd>
              <Kbd>Z</Kbd>
            </KbdGroup>
            undo
          </span>
        </div>
      </div>

      <div
        data-slot="schedule-scroll"
        className="relative flex-1 overflow-auto overscroll-contain"
      >
        <div className="min-w-[44rem]">
          <div className="sticky top-0 z-10 flex border-b bg-background/95 backdrop-blur-sm">
            <div className={cn(GUTTER, "shrink-0 border-r")} />
            {DAYS.map((day, index) => {
              const today = index === todayColumn
              return (
                <div
                  key={day}
                  className={cn(
                    "flex h-11 flex-1 items-center justify-center gap-1.5 border-r text-xs font-medium text-muted-foreground last:border-r-0",
                    today && "text-foreground"
                  )}
                >
                  {day}
                  {today && (
                    <span className="rounded-full bg-primary px-1.5 py-px text-[0.625rem] font-semibold text-primary-foreground">
                      Today
                    </span>
                  )}
                </div>
              )
            })}
          </div>

          <div className="isolate flex">
            <div className={cn(GUTTER, "shrink-0 border-r")} aria-hidden>
              {Array.from({ length: SLOT_COUNT }, (_, slot) => (
                <div
                  key={slot}
                  className={cn(
                    "flex items-start justify-end border-b pt-1 pr-2 text-[0.6875rem] text-muted-foreground tabular-nums",
                    slot % 2 === 0 && "border-dashed border-b-border/60"
                  )}
                  style={{ height: SLOT_HEIGHT }}
                >
                  {slot % 2 === 0 && slotLabel(slot)}
                </div>
              ))}
            </div>

            <div className="relative flex flex-1">
              {DAYS.map((day, dayIndex) => (
                <div
                  key={day}
                  ref={(element) => {
                    columns.current[dayIndex] = element
                  }}
                  data-slot="day-column"
                  data-day={dayIndex}
                  aria-label={`${day} column`}
                  className={cn(
                    "relative flex-1 cursor-crosshair border-r select-none last:border-r-0",
                    dayIndex === todayColumn && "bg-muted/40"
                  )}
                  style={{ height: SLOT_COUNT * SLOT_HEIGHT }}
                  onPointerDown={(event) => startCreate(event, dayIndex)}
                >
                  {Array.from({ length: SLOT_COUNT }, (_, slot) => (
                    <div
                      key={slot}
                      className={cn(
                        "pointer-events-none border-b",
                        slot % 2 === 0 && "border-dashed border-b-border/60"
                      )}
                      style={{ height: SLOT_HEIGHT }}
                    />
                  ))}

                  {selectedSlot?.day === dayIndex && (
                    <div
                      className="pointer-events-none absolute inset-x-0.5 z-[3] animate-pulse rounded-md border-[1.5px] border-dashed border-foreground/70 bg-foreground/5"
                      style={{
                        top: selectedSlot.slot * SLOT_HEIGHT,
                        height: SLOT_HEIGHT,
                      }}
                    />
                  )}

                  {blocks
                    .filter((block) => block.day === dayIndex)
                    .map((block) => (
                      <ScheduleBlock
                        key={block.id}
                        block={block}
                        selected={selectedId === block.id}
                        moving={moveGhost?.id === block.id}
                        onPointerDown={(event) => startMove(event, block)}
                        onResizeStart={(event, edge) =>
                          startResize(event, block, edge)
                        }
                        onDelete={() => deleteBlock(block.id)}
                        onClick={(event) => {
                          if (suppressClick.current) {
                            suppressClick.current = false
                            return
                          }
                          // Touch has no double-click, so a tap opens the editor.
                          if (
                            (event.nativeEvent as PointerEvent).pointerType ===
                            "touch"
                          ) {
                            openEdit(block)
                            return
                          }
                          setSelectedId(block.id)
                          setSelectedSlot(null)
                        }}
                        onDoubleClick={() => openEdit(block)}
                      />
                    ))}

                  {createGhost?.day === dayIndex && (
                    <div
                      className="pointer-events-none absolute inset-x-0.5 z-[4] rounded-md opacity-45"
                      style={{
                        top: createGhost.start * SLOT_HEIGHT,
                        height:
                          (createGhost.end - createGhost.start) * SLOT_HEIGHT,
                        backgroundColor: createGhost.color,
                      }}
                    />
                  )}

                  {moveGhost?.day === dayIndex && (
                    <div
                      className="pointer-events-none absolute inset-x-0.5 z-30 flex items-start rounded-md px-2 py-1 text-xs font-semibold text-white opacity-75 shadow-lg"
                      style={{
                        top: moveGhost.start * SLOT_HEIGHT,
                        height:
                          (moveGhost.end - moveGhost.start) * SLOT_HEIGHT - 2,
                        backgroundColor: moveGhost.color,
                      }}
                    >
                      {moveGhost.label}
                    </div>
                  )}

                  {showNow && dayIndex === todayColumn && (
                    <div
                      aria-hidden
                      className="pointer-events-none absolute inset-x-0 z-[6] h-0.5 bg-destructive"
                      style={{ top: nowOffset }}
                    >
                      <span className="absolute -top-[3px] -left-1 size-2 rounded-full bg-destructive" />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <PasteHint copied={copied} hasTarget={!!selectedSlot} />

      <BlockDialog
        open={editorOpen}
        draft={draft}
        onOpenChange={setEditorOpen}
        onSave={saveDraft}
        onDelete={deleteFromDialog}
      />
    </div>
  )
}

type ScheduleBlockProps = {
  block: Block
  selected: boolean
  moving: boolean
  onPointerDown: (event: ReactPointerEvent<HTMLDivElement>) => void
  onResizeStart: (
    event: ReactPointerEvent<HTMLDivElement>,
    edge: "start" | "end"
  ) => void
  onDelete: () => void
  onClick: (event: ReactMouseEvent<HTMLDivElement>) => void
  onDoubleClick: () => void
}

function ScheduleBlock({
  block,
  selected,
  moving,
  onPointerDown,
  onResizeStart,
  onDelete,
  onClick,
  onDoubleClick,
}: ScheduleBlockProps) {
  const time = `${slotLabel(block.start)} – ${slotLabel(block.end)}`

  return (
    <div
      data-slot="schedule-block"
      data-bid={block.id}
      data-selected={selected || undefined}
      role="button"
      tabIndex={-1}
      aria-label={`${block.label}, ${time}`}
      className={cn(
        "group/block absolute inset-x-0.5 z-[5] cursor-pointer overflow-hidden rounded-md px-2 py-1 text-white shadow-sm transition-[filter] hover:brightness-90",
        selected &&
          "z-[8] outline-2 outline-offset-1 outline-foreground outline-solid",
        moving && "opacity-35"
      )}
      style={{
        top: block.start * SLOT_HEIGHT,
        height: Math.max(1, block.end - block.start) * SLOT_HEIGHT - 2,
        backgroundColor: block.color,
      }}
      onPointerDown={onPointerDown}
      onClick={onClick}
      onDoubleClick={(event) => {
        event.stopPropagation()
        onDoubleClick()
      }}
    >
      <div
        data-slot="block-label"
        className="truncate pr-4 text-sm leading-[1.3] font-semibold"
      >
        {block.label}
      </div>
      <div
        data-slot="block-time"
        className="mt-0.5 truncate text-xs text-white/80 tabular-nums"
      >
        {time}
      </div>
      <button
        type="button"
        data-slot="block-delete"
        aria-label={`Delete ${block.label}`}
        className="absolute top-1 right-1 z-[2] hidden size-4 items-center justify-center rounded-sm text-white/70 group-hover/block:flex hover:bg-black/20 hover:text-white"
        onPointerDown={(event) => {
          event.stopPropagation()
          event.preventDefault()
          onDelete()
        }}
      >
        <LuX className="size-3" />
      </button>
      <div
        data-slot="resize-handle"
        data-edge="start"
        title="Drag to change the start time"
        className="absolute inset-x-0 top-0 h-[7px] cursor-ns-resize"
        onPointerDown={(event) => onResizeStart(event, "start")}
      />
      <div
        data-slot="resize-handle"
        data-edge="end"
        title="Drag to change the end time"
        className="absolute inset-x-0 bottom-0 h-[7px] cursor-ns-resize"
        onPointerDown={(event) => onResizeStart(event, "end")}
      />
    </div>
  )
}

function PasteHint({
  copied,
  hasTarget,
}: {
  copied: Block | null
  hasTarget: boolean
}) {
  if (!copied) return null
  return (
    <div
      role="status"
      className="pointer-events-none fixed bottom-5 left-1/2 z-40 flex -translate-x-1/2 items-center gap-2 rounded-full bg-foreground py-2 pr-4 pl-3 text-sm whitespace-nowrap text-background shadow-lg"
    >
      <span
        className="size-2.5 rounded-full"
        style={{ backgroundColor: copied.color }}
      />
      {hasTarget ? (
        <>
          Press
          <KbdGroup>
            <Kbd>{MOD_KEY}</Kbd>
            <Kbd>V</Kbd>
          </KbdGroup>
          to paste “{copied.label}” here
        </>
      ) : (
        <>
          “{copied.label}” copied. Click a time slot, then press
          <KbdGroup>
            <Kbd>{MOD_KEY}</Kbd>
            <Kbd>V</Kbd>
          </KbdGroup>
          <span className="text-background/60">· Esc to clear</span>
        </>
      )}
    </div>
  )
}

/** Current time, refreshed every minute for the "now" line. */
function useNow() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 60_000)
    return () => window.clearInterval(timer)
  }, [])
  return now
}
