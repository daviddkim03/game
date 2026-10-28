import { useRef, useState, type FormEvent } from "react"
import { LuArrowUpRight, LuPencil, LuTrash2 } from "react-icons/lu"

import { useDialogs } from "@/components/dialogs"
import { Button, buttonVariants } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Field, FieldDescription, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { formatUSD } from "@/lib/format"
import { cn } from "@/lib/utils"
import { ColorDot } from "@/pages/tracker/components"
import { monthlyCost, safeHref, type Expense } from "@/pages/tracker/model"

type PaymentLinkDialogProps = {
  expense: Expense | null
  color: string
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (link: string) => void
}

/** Where to pay a bill; opened by right-clicking its pill on the calendar. */
export function PaymentLinkDialog({
  expense,
  color,
  open,
  onOpenChange,
  onSave,
}: PaymentLinkDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      {expense && (
        <LinkContent
          key={expense.id}
          expense={expense}
          color={color}
          onSave={onSave}
          onClose={() => onOpenChange(false)}
        />
      )}
    </Dialog>
  )
}

function LinkContent({
  expense,
  color,
  onSave,
  onClose,
}: {
  expense: Expense
  color: string
  onSave: (link: string) => void
  onClose: () => void
}) {
  const { confirm } = useDialogs()
  const link = expense.paymentLink?.trim() ?? ""
  const [editing, setEditing] = useState(!link)
  const [value, setValue] = useState(link)
  const input = useRef<HTMLInputElement>(null)
  const href = safeHref(link)

  function save(event: FormEvent) {
    event.preventDefault()
    onSave(value.trim())
    onClose()
  }

  function cancelEdit() {
    if (!link) {
      onClose()
      return
    }
    setValue(link)
    setEditing(false)
  }

  async function remove() {
    const ok = await confirm({
      title: `Remove the payment link for "${expense.name}"?`,
      confirmLabel: "Remove",
      destructive: true,
    })
    if (!ok) return
    onSave("")
    onClose()
  }

  return (
    <DialogContent
      initialFocus={editing ? input : undefined}
      className="sm:max-w-md"
    >
      <DialogHeader>
        <DialogTitle>{expense.name}</DialogTitle>
        <DialogDescription className="flex items-center gap-1.5">
          <ColorDot color={color} />
          {expense.cat} · {formatUSD(monthlyCost(expense))}/mo · Payment site
        </DialogDescription>
      </DialogHeader>

      {editing ? (
        // Bare domains like "pay.example.com" are allowed, so skip URL validation.
        <form onSubmit={save} noValidate className="grid gap-4">
          <Field>
            <FieldLabel htmlFor="payment-link">Payment site</FieldLabel>
            <Input
              ref={input}
              autoFocus
              id="payment-link"
              type="url"
              inputMode="url"
              autoComplete="url"
              placeholder="https://payment-site.com"
              value={value}
              onChange={(event) => setValue(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Escape" && link) {
                  event.preventDefault()
                  event.stopPropagation()
                  cancelEdit()
                }
              }}
            />
            <FieldDescription>
              The link icon on this bill's calendar pill opens it.
            </FieldDescription>
          </Field>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={cancelEdit}>
              Cancel
            </Button>
            <Button type="submit">Save</Button>
          </DialogFooter>
        </form>
      ) : (
        <div className="grid gap-4">
          <div className="grid gap-1.5">
            <a
              href={href ?? undefined}
              target="_blank"
              rel="noopener noreferrer"
              aria-disabled={!href}
              className={cn(
                buttonVariants({ variant: "outline", size: "lg" }),
                "w-full justify-between"
              )}
            >
              Open payment site
              <LuArrowUpRight />
            </a>
            <p className="truncate text-xs text-muted-foreground" title={link}>
              {link}
            </p>
          </div>
          <DialogFooter>
            <Button
              variant="ghost"
              className="text-destructive hover:bg-destructive/10 hover:text-destructive sm:mr-auto"
              onClick={remove}
            >
              <LuTrash2 />
              Remove
            </Button>
            <Button variant="outline" onClick={() => setEditing(true)}>
              <LuPencil />
              Edit
            </Button>
          </DialogFooter>
        </div>
      )}
    </DialogContent>
  )
}
