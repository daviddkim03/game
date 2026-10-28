import { useRef, useState, type FormEvent } from "react"
import { LuTrash2 } from "react-icons/lu"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { ColorSwatches } from "@/pages/schedule/color-swatches"
import { DAY_NAMES, SLOT_COUNT, slotLabel } from "@/pages/schedule/model"

export type BlockDraft = {
  /** null while adding a new block. */
  id: number | null
  label: string
  day: number
  start: number
  end: number
  color: string
}

const DAY_ITEMS = DAY_NAMES.map((label, value) => ({ label, value }))
const TIME_ITEMS = Array.from({ length: SLOT_COUNT + 1 }, (_, value) => ({
  label: slotLabel(value),
  value,
}))

type BlockDialogProps = {
  open: boolean
  draft: BlockDraft | null
  onOpenChange: (open: boolean) => void
  onSave: (draft: BlockDraft) => void
  onDelete: (id: number) => void
}

export function BlockDialog({
  open,
  draft,
  onOpenChange,
  onSave,
  onDelete,
}: BlockDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      {draft && (
        <BlockForm
          // A fresh form for every block that opens.
          key={`${draft.id}-${draft.day}-${draft.start}-${draft.end}`}
          initial={draft}
          onSave={onSave}
          onDelete={onDelete}
        />
      )}
    </Dialog>
  )
}

function BlockForm({
  initial,
  onSave,
  onDelete,
}: {
  initial: BlockDraft
  onSave: (draft: BlockDraft) => void
  onDelete: (id: number) => void
}) {
  const [draft, setDraft] = useState(initial)
  const [error, setError] = useState<string | null>(null)
  const labelInput = useRef<HTMLInputElement>(null)
  const editing = draft.id !== null

  const set = (changes: Partial<BlockDraft>) => {
    setError(null)
    setDraft((current) => ({ ...current, ...changes }))
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (draft.end <= draft.start) {
      setError("End time must be after the start time.")
      return
    }
    onSave({ ...draft, label: draft.label.trim() || "Block" })
  }

  return (
    <DialogContent initialFocus={labelInput} className="sm:max-w-md">
      <form onSubmit={handleSubmit} className="grid gap-4">
        <DialogHeader>
          <DialogTitle>{editing ? "Edit block" : "Add block"}</DialogTitle>
          <DialogDescription>
            Blocks that overlap this time on the same day are trimmed to make
            room.
          </DialogDescription>
        </DialogHeader>
        <FieldGroup className="gap-4">
          <Field>
            <FieldLabel htmlFor="block-label">Label</FieldLabel>
            <Input
              ref={labelInput}
              id="block-label"
              maxLength={40}
              placeholder="e.g. workout"
              autoComplete="off"
              value={draft.label}
              onChange={(event) => set({ label: event.target.value })}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="block-day">Day</FieldLabel>
            <Select
              items={DAY_ITEMS}
              value={draft.day}
              onValueChange={(day) => day !== null && set({ day })}
            >
              <SelectTrigger id="block-day" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {DAY_ITEMS.map((item) => (
                  <SelectItem key={item.value} value={item.value}>
                    {item.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field data-invalid={!!error || undefined}>
              <FieldLabel htmlFor="block-start">Start</FieldLabel>
              <TimeSelect
                id="block-start"
                value={draft.start}
                invalid={!!error}
                onValueChange={(start) => set({ start })}
              />
            </Field>
            <Field data-invalid={!!error || undefined}>
              <FieldLabel htmlFor="block-end">End</FieldLabel>
              <TimeSelect
                id="block-end"
                value={draft.end}
                invalid={!!error}
                onValueChange={(end) => set({ end })}
              />
            </Field>
            {error && <FieldError className="col-span-2">{error}</FieldError>}
          </div>
          <Field>
            <FieldLabel id="block-color-label">Color</FieldLabel>
            <ColorSwatches
              aria-labelledby="block-color-label"
              value={draft.color}
              onValueChange={(color) => set({ color })}
            />
          </Field>
        </FieldGroup>
        <DialogFooter>
          {editing && (
            <Button
              type="button"
              variant="ghost"
              className="text-destructive hover:bg-destructive/10 hover:text-destructive sm:mr-auto"
              onClick={() => onDelete(draft.id!)}
            >
              <LuTrash2 />
              Delete
            </Button>
          )}
          <DialogClose render={<Button variant="outline" />}>
            Cancel
          </DialogClose>
          <Button type="submit">Save</Button>
        </DialogFooter>
      </form>
    </DialogContent>
  )
}

function TimeSelect({
  id,
  value,
  invalid,
  onValueChange,
}: {
  id: string
  value: number
  invalid: boolean
  onValueChange: (slot: number) => void
}) {
  return (
    <Select
      items={TIME_ITEMS}
      value={value}
      onValueChange={(slot) => slot !== null && onValueChange(slot)}
    >
      <SelectTrigger
        id={id}
        className="w-full tabular-nums"
        aria-invalid={invalid || undefined}
      >
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {TIME_ITEMS.map((item) => (
          <SelectItem
            key={item.value}
            value={item.value}
            className="tabular-nums"
          >
            {item.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
