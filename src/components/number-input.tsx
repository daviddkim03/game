import { useState, type ComponentProps } from "react"

import { Input } from "@/components/ui/input"
import { InputGroupInput } from "@/components/ui/input-group"
import { cn } from "@/lib/utils"

type NumberInputProps = Omit<
  ComponentProps<typeof Input>,
  "type" | "value" | "defaultValue" | "onChange"
> & {
  value: number | null | undefined
  /** Called with null while the field is empty. */
  onValueChange: (value: number | null) => void
  /** Render as the control inside an InputGroup. */
  grouped?: boolean
}

/**
 * A number field that keeps what you type (e.g. an empty field or "1.") while
 * editing instead of snapping to the parsed value on every keystroke.
 */
export function NumberInput({
  value,
  onValueChange,
  onBlur,
  grouped,
  className,
  ...props
}: NumberInputProps) {
  const [draft, setDraft] = useState<string | null>(null)
  const Control = grouped ? InputGroupInput : Input

  return (
    <Control
      type="number"
      inputMode="decimal"
      value={draft ?? (value ?? "").toString()}
      onChange={(event) => {
        const text = event.target.value
        setDraft(text)
        const parsed = text.trim() === "" ? null : Number(text)
        onValueChange(
          parsed !== null && Number.isFinite(parsed) ? parsed : null
        )
      }}
      onBlur={(event) => {
        setDraft(null)
        onBlur?.(event)
      }}
      // Arrow keys still step the value; the spinner buttons only add clutter.
      className={cn(
        "[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none",
        className
      )}
      {...props}
    />
  )
}
