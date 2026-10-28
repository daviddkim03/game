import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react"

import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
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

type ConfirmOptions = {
  title: string
  description?: ReactNode
  confirmLabel?: string
  /** Styles the confirm button for actions that delete data. */
  destructive?: boolean
}

type PromptField = {
  name: string
  label: string
  defaultValue?: string
  placeholder?: string
}

type PromptOptions<Name extends string> = {
  title: string
  description?: ReactNode
  fields: readonly (PromptField & { name: Name })[]
  confirmLabel?: string
  /** Returns the problem (and which field has it) to keep the dialog open. */
  validate?: (
    values: Record<Name, string>
  ) => { field: Name; message: string } | null
}

type Dialogs = {
  confirm(options: ConfirmOptions): Promise<boolean>
  /** Resolves with the trimmed values, or null when cancelled. */
  prompt<Name extends string>(
    options: PromptOptions<Name>
  ): Promise<Record<Name, string> | null>
}

const DialogsContext = createContext<Dialogs | null>(null)

/** Promise-based replacements for window.confirm() and window.prompt(). */
export function useDialogs() {
  const dialogs = useContext(DialogsContext)
  if (!dialogs)
    throw new Error("useDialogs must be used within DialogsProvider")
  return dialogs
}

type PendingConfirm = ConfirmOptions & { resolve: (ok: boolean) => void }
type PendingPrompt = PromptOptions<string> & {
  resolve: (values: Record<string, string> | null) => void
}

export function DialogsProvider({ children }: { children: ReactNode }) {
  // Options stay set after closing so the closing animation keeps its content.
  const [confirmState, setConfirmState] = useState<PendingConfirm | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [promptState, setPromptState] = useState<PendingPrompt | null>(null)
  const [promptOpen, setPromptOpen] = useState(false)
  const [promptKey, setPromptKey] = useState(0)

  const confirm = useCallback(
    (options: ConfirmOptions) =>
      new Promise<boolean>((resolve) => {
        setConfirmState({ ...options, resolve })
        setConfirmOpen(true)
      }),
    []
  )

  const prompt = useCallback(
    <Name extends string>(options: PromptOptions<Name>) =>
      new Promise<Record<Name, string> | null>((resolve) => {
        setPromptState({
          ...(options as unknown as PromptOptions<string>),
          resolve: resolve as PendingPrompt["resolve"],
        })
        setPromptKey((key) => key + 1)
        setPromptOpen(true)
      }),
    []
  )

  const value = useMemo(() => ({ confirm, prompt }), [confirm, prompt])

  function closeConfirm(ok: boolean) {
    confirmState?.resolve(ok)
    setConfirmOpen(false)
  }

  function closePrompt(values: Record<string, string> | null) {
    promptState?.resolve(values)
    setPromptOpen(false)
  }

  return (
    <DialogsContext.Provider value={value}>
      {children}
      <AlertDialog
        open={confirmOpen}
        onOpenChange={(open) => !open && closeConfirm(false)}
      >
        {confirmState && (
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>{confirmState.title}</AlertDialogTitle>
              {confirmState.description && (
                <AlertDialogDescription>
                  {confirmState.description}
                </AlertDialogDescription>
              )}
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <Button
                variant={confirmState.destructive ? "destructive" : "default"}
                onClick={() => closeConfirm(true)}
              >
                {confirmState.confirmLabel ?? "Continue"}
              </Button>
            </AlertDialogFooter>
          </AlertDialogContent>
        )}
      </AlertDialog>
      <Dialog
        open={promptOpen}
        onOpenChange={(open) => !open && closePrompt(null)}
      >
        {promptState && (
          <PromptContent
            key={promptKey}
            options={promptState}
            onSubmit={closePrompt}
          />
        )}
      </Dialog>
    </DialogsContext.Provider>
  )
}

function PromptContent({
  options,
  onSubmit,
}: {
  options: PromptOptions<string>
  onSubmit: (values: Record<string, string>) => void
}) {
  const [values, setValues] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      options.fields.map((field) => [field.name, field.defaultValue ?? ""])
    )
  )
  const [error, setError] = useState<{ field: string; message: string } | null>(
    null
  )
  const firstInput = useRef<HTMLInputElement>(null)

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    const trimmed = Object.fromEntries(
      Object.entries(values).map(([name, value]) => [name, value.trim()])
    )
    const problem = options.validate?.(trimmed) ?? null
    if (problem) {
      setError(problem)
      document.getElementById(`prompt-${problem.field}`)?.focus()
      return
    }
    onSubmit(trimmed)
  }

  return (
    <DialogContent initialFocus={firstInput}>
      <form onSubmit={handleSubmit} className="grid gap-4">
        <DialogHeader>
          <DialogTitle>{options.title}</DialogTitle>
          {options.description && (
            <DialogDescription>{options.description}</DialogDescription>
          )}
        </DialogHeader>
        <FieldGroup className="gap-4">
          {options.fields.map((field, index) => {
            const invalid = error?.field === field.name
            return (
              <Field key={field.name} data-invalid={invalid || undefined}>
                <FieldLabel htmlFor={`prompt-${field.name}`}>
                  {field.label}
                </FieldLabel>
                <Input
                  ref={index === 0 ? firstInput : undefined}
                  id={`prompt-${field.name}`}
                  value={values[field.name]}
                  placeholder={field.placeholder}
                  autoComplete="off"
                  aria-invalid={invalid || undefined}
                  aria-describedby={invalid ? "prompt-error" : undefined}
                  onChange={(event) => {
                    if (invalid) setError(null)
                    setValues((current) => ({
                      ...current,
                      [field.name]: event.target.value,
                    }))
                  }}
                />
                {invalid && (
                  <FieldError id="prompt-error">{error.message}</FieldError>
                )}
              </Field>
            )
          })}
        </FieldGroup>
        <DialogFooter>
          <DialogClose render={<Button variant="outline" />}>
            Cancel
          </DialogClose>
          <Button type="submit">{options.confirmLabel ?? "Save"}</Button>
        </DialogFooter>
      </form>
    </DialogContent>
  )
}
