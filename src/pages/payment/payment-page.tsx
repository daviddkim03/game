import { produce, type Draft } from "immer"
import {
  LuDownload,
  LuEllipsis,
  LuPencil,
  LuPlus,
  LuTrash2,
  LuUserPlus,
  LuUsers,
  LuX,
} from "react-icons/lu"

import { AppHeader } from "@/components/app-header"
import { DatePicker } from "@/components/date-picker"
import { useDialogs } from "@/components/dialogs"
import { NumberInput } from "@/components/number-input"
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
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupText,
} from "@/components/ui/input-group"
import {
  Table,
  TableBody,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { useSyncedState } from "@/hooks/use-synced-state"
import { getApp } from "@/lib/apps"
import { formatNumber, formatUSD, parseISODate } from "@/lib/format"
import {
  defaultReport,
  reportHours,
  reportTotal,
  reviveReport,
  STORAGE_KEY,
  studentHours,
  studentTotal,
  type PaymentReport,
  type Session,
  type Student,
} from "@/pages/payment/model"
import { PrintReport } from "@/pages/payment/print-report"

const money = (value: number) => formatUSD(value, { cents: true })

function validateStudent({ name, subject }: { name: string; subject: string }) {
  if (!name)
    return { field: "name" as const, message: "Enter the student's name." }
  if (!subject)
    return { field: "subject" as const, message: "Enter a subject." }
  return null
}

function periodLabel(start: string, end: string) {
  const format = (value: string) =>
    parseISODate(value)?.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    })
  const from = format(start)
  const to = format(end)
  if (!from && !to) return null
  return [from, to].filter(Boolean).join(" – ")
}

export function PaymentPage() {
  const [report, setReport] = useSyncedState({
    pageId: getApp("payment").syncId,
    storageKey: STORAGE_KEY,
    initial: defaultReport,
    revive: reviveReport,
  })
  const { confirm, prompt } = useDialogs()

  const update = (recipe: (draft: Draft<PaymentReport>) => void) =>
    setReport(produce(recipe))

  async function addStudent() {
    const values = await prompt({
      title: "Add student",
      description: "Sessions are billed at the report's hourly rate.",
      fields: [
        { name: "name", label: "Student name", placeholder: "e.g. Ian" },
        { name: "subject", label: "Subject", placeholder: "e.g. SAT Math" },
      ],
      confirmLabel: "Add student",
      validate: validateStudent,
    })
    if (!values) return
    update((draft) => {
      draft.students.push({
        id: draft.nextId++,
        name: values.name,
        subject: values.subject,
        sessions: [],
      })
    })
  }

  async function editStudent(student: Student) {
    const values = await prompt({
      title: "Edit student",
      fields: [
        { name: "name", label: "Student name", defaultValue: student.name },
        { name: "subject", label: "Subject", defaultValue: student.subject },
      ],
      validate: validateStudent,
    })
    if (!values) return
    update((draft) => {
      const target = draft.students.find((s) => s.id === student.id)
      if (target) Object.assign(target, values)
    })
  }

  async function removeStudent(student: Student) {
    const ok = await confirm({
      title: `Remove ${student.name}?`,
      description: "This deletes the student and all of their sessions.",
      confirmLabel: "Remove",
      destructive: true,
    })
    if (!ok) return
    update((draft) => {
      draft.students = draft.students.filter((s) => s.id !== student.id)
    })
  }

  async function clearAll() {
    const ok = await confirm({
      title: "Clear all students?",
      description:
        "This removes every student and session from the report. Report info is kept.",
      confirmLabel: "Clear all",
      destructive: true,
    })
    if (!ok) return
    update((draft) => {
      draft.students = []
    })
  }

  function addSession(studentId: number) {
    update((draft) => {
      draft.students
        .find((s) => s.id === studentId)
        ?.sessions.push({ id: draft.nextId++, date: "", startTime: "", hrs: 1 })
    })
  }

  function updateSession(
    studentId: number,
    sessionId: number,
    changes: Partial<Session>
  ) {
    update((draft) => {
      const session = draft.students
        .find((s) => s.id === studentId)
        ?.sessions.find((x) => x.id === sessionId)
      if (session) Object.assign(session, changes)
    })
  }

  function deleteSession(studentId: number, sessionId: number) {
    update((draft) => {
      const student = draft.students.find((s) => s.id === studentId)
      if (student) {
        student.sessions = student.sessions.filter((x) => x.id !== sessionId)
      }
    })
  }

  const rate = report.rate || 0
  const period = periodLabel(report.start, report.end)
  const hasStudents = report.students.length > 0

  return (
    <div className="flex min-h-svh flex-col">
      <AppHeader
        current="payment"
        actions={
          <>
            <Button variant="outline" onClick={addStudent}>
              <LuUserPlus />
              <span className="hidden sm:inline">Student</span>
              <span className="sr-only sm:hidden">Add student</span>
            </Button>
            <Button onClick={() => window.print()}>
              <LuDownload />
              <span className="hidden sm:inline">Download PDF</span>
              <span className="sr-only sm:hidden">Download PDF</span>
            </Button>
          </>
        }
      />

      <div className="mx-auto grid w-full max-w-6xl flex-1 gap-6 p-4 sm:p-6 lg:grid-cols-[17rem_minmax(0,1fr)] lg:items-start print:hidden">
        <aside className="order-2 flex flex-col gap-4 lg:sticky lg:top-20 lg:order-1">
          <Card size="sm">
            <CardHeader className="border-b">
              <CardTitle>Report info</CardTitle>
              <CardDescription>
                Printed at the top of the report.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <FieldGroup className="gap-3">
                <Field className="gap-1.5">
                  <FieldLabel htmlFor="report-name">Tutor name</FieldLabel>
                  <Input
                    id="report-name"
                    value={report.name}
                    onChange={(event) =>
                      update((draft) => {
                        draft.name = event.target.value
                      })
                    }
                  />
                </Field>
                <Field className="gap-1.5">
                  <FieldLabel htmlFor="report-start">Period start</FieldLabel>
                  <DatePicker
                    id="report-start"
                    value={report.start}
                    onChange={(value) =>
                      update((draft) => {
                        draft.start = value
                      })
                    }
                  />
                </Field>
                <Field className="gap-1.5">
                  <FieldLabel htmlFor="report-end">Period end</FieldLabel>
                  <DatePicker
                    id="report-end"
                    value={report.end}
                    onChange={(value) =>
                      update((draft) => {
                        draft.end = value
                      })
                    }
                  />
                </Field>
                <Field className="gap-1.5">
                  <FieldLabel htmlFor="report-rate">Hourly rate</FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>$</InputGroupText>
                    </InputGroupAddon>
                    <NumberInput
                      grouped
                      id="report-rate"
                      min={0}
                      step={0.5}
                      value={report.rate}
                      onValueChange={(value) =>
                        update((draft) => {
                          draft.rate = value ?? 0
                        })
                      }
                    />
                    <InputGroupAddon align="inline-end">
                      <InputGroupText>/ hr</InputGroupText>
                    </InputGroupAddon>
                  </InputGroup>
                </Field>
                <Field className="gap-1.5">
                  <FieldLabel htmlFor="report-every">Report every</FieldLabel>
                  <Input
                    id="report-every"
                    placeholder="10th & 25th"
                    value={report.every}
                    onChange={(event) =>
                      update((draft) => {
                        draft.every = event.target.value
                      })
                    }
                  />
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>

          <Card size="sm">
            <CardHeader className="border-b">
              <CardTitle>Students</CardTitle>
              <CardDescription>
                {report.students.length} student
                {report.students.length === 1 ? "" : "s"}
              </CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-1">
              {report.students.map((student) => (
                <div
                  key={student.id}
                  className="group/student flex items-center gap-2 rounded-lg py-1 pr-1 pl-2 hover:bg-muted"
                >
                  <a
                    href={`#student-${student.id}`}
                    className="flex min-w-0 flex-1 items-baseline gap-1.5 text-sm outline-none focus-visible:underline"
                  >
                    <span className="truncate font-medium">{student.name}</span>
                    <span className="truncate text-xs text-muted-foreground">
                      {student.subject}
                    </span>
                  </a>
                  <span className="text-xs font-medium tabular-nums">
                    {money(studentTotal(student, rate))}
                  </span>
                  <Tooltip>
                    <TooltipTrigger
                      render={
                        <Button
                          variant="ghost"
                          size="icon-xs"
                          className="text-muted-foreground hover:text-destructive"
                          aria-label={`Remove ${student.name}`}
                          onClick={() => removeStudent(student)}
                        />
                      }
                    >
                      <LuX />
                    </TooltipTrigger>
                    <TooltipContent>Remove student</TooltipContent>
                  </Tooltip>
                </div>
              ))}
              <Button
                variant="outline"
                className="mt-2 w-full"
                onClick={addStudent}
              >
                <LuPlus />
                Add student
              </Button>
            </CardContent>
          </Card>

          <Button
            variant="ghost"
            className="w-full text-destructive hover:bg-destructive/10 hover:text-destructive"
            onClick={clearAll}
            disabled={!hasStudents}
          >
            <LuTrash2 />
            Clear all students
          </Button>
        </aside>

        <main className="order-1 flex min-w-0 flex-col gap-4 lg:order-2">
          <div className="flex flex-wrap items-end justify-between gap-4 border-b pb-5">
            <div className="flex min-w-0 flex-col gap-1">
              <p className="text-sm text-muted-foreground">
                Report every {report.every || "—"}
              </p>
              <h1 className="font-heading text-2xl font-semibold tracking-tight">
                {report.name || "Tutor"}
                {period && (
                  <span className="ml-2 text-lg font-normal text-muted-foreground">
                    {period}
                  </span>
                )}
              </h1>
            </div>
            <div className="sm:text-right">
              <p className="text-sm text-muted-foreground">Rate</p>
              <p className="text-2xl font-semibold tabular-nums">
                {money(rate)}
                <span className="text-sm font-normal text-muted-foreground">
                  {" "}
                  / hr
                </span>
              </p>
            </div>
          </div>

          {hasStudents ? (
            <>
              {report.students.map((student) => (
                <StudentCard
                  key={student.id}
                  student={student}
                  rate={rate}
                  onEdit={() => editStudent(student)}
                  onRemove={() => removeStudent(student)}
                  onAddSession={() => addSession(student.id)}
                  onUpdateSession={(sessionId, changes) =>
                    updateSession(student.id, sessionId, changes)
                  }
                  onDeleteSession={(sessionId) =>
                    deleteSession(student.id, sessionId)
                  }
                />
              ))}
              <div className="flex items-center justify-between gap-4 rounded-xl bg-primary px-5 py-4 text-primary-foreground">
                <div>
                  <p className="font-medium">Total</p>
                  <p className="text-sm opacity-70">
                    {formatNumber(reportHours(report))}h × {money(rate)}/hr ·{" "}
                    {report.students.length} student
                    {report.students.length === 1 ? "" : "s"}
                  </p>
                </div>
                <p className="text-2xl font-semibold tabular-nums">
                  {money(reportTotal(report))}
                </p>
              </div>
            </>
          ) : (
            <Empty className="border border-dashed">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <LuUsers />
                </EmptyMedia>
                <EmptyTitle>No students yet</EmptyTitle>
                <EmptyDescription>
                  Add a student to start logging sessions for this report.
                </EmptyDescription>
              </EmptyHeader>
              <EmptyContent>
                <Button onClick={addStudent}>
                  <LuPlus />
                  Add student
                </Button>
              </EmptyContent>
            </Empty>
          )}
        </main>
      </div>

      <PrintReport report={report} />
    </div>
  )
}

type StudentCardProps = {
  student: Student
  rate: number
  onEdit: () => void
  onRemove: () => void
  onAddSession: () => void
  onUpdateSession: (sessionId: number, changes: Partial<Session>) => void
  onDeleteSession: (sessionId: number) => void
}

function StudentCard({
  student,
  rate,
  onEdit,
  onRemove,
  onAddSession,
  onUpdateSession,
  onDeleteSession,
}: StudentCardProps) {
  const hours = studentHours(student)
  const total = studentTotal(student, rate)

  // The same controls appear in the desktop table and the stacked phone list.
  const controls = (session: Session, index: number) => ({
    date: (
      <DatePicker
        size="sm"
        aria-label={`Session ${index + 1} date`}
        className="text-sm"
        value={session.date}
        onChange={(date) => onUpdateSession(session.id, { date })}
      />
    ),
    start: (
      <Input
        type="time"
        aria-label={`Session ${index + 1} start time`}
        className="h-7 w-32 tabular-nums"
        value={session.startTime}
        onChange={(event) =>
          onUpdateSession(session.id, { startTime: event.target.value })
        }
      />
    ),
    hours: (
      <NumberInput
        aria-label={`Session ${index + 1} hours`}
        className="h-7 w-20 text-right tabular-nums"
        min={0}
        step={0.5}
        value={session.hrs}
        onValueChange={(hrs) => onUpdateSession(session.id, { hrs: hrs ?? 0 })}
      />
    ),
    remove: (
      <Button
        variant="ghost"
        size="icon-sm"
        className="text-muted-foreground hover:text-destructive"
        aria-label={`Delete session ${index + 1}`}
        onClick={() => onDeleteSession(session.id)}
      >
        <LuTrash2 />
      </Button>
    ),
  })

  const addSession = (
    <Button
      variant="ghost"
      size="sm"
      className="w-full text-muted-foreground"
      onClick={onAddSession}
    >
      <LuPlus />
      Add session
    </Button>
  )

  return (
    <Card id={`student-${student.id}`} className="scroll-mt-20 gap-0 py-0">
      <CardHeader className="border-b bg-muted/40 py-3">
        <CardTitle className="flex flex-wrap items-center gap-2">
          {student.name}
          <Badge variant="outline" className="font-normal">
            {student.subject}
          </Badge>
        </CardTitle>
        <CardAction className="flex items-center gap-3">
          <span className="text-right">
            <span className="block font-semibold tabular-nums">
              {money(total)}
            </span>
            <span className="block text-xs text-muted-foreground tabular-nums">
              {formatNumber(hours)}h × {money(rate)}
            </span>
          </span>
          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button
                  variant="ghost"
                  size="icon-sm"
                  aria-label={`${student.name} options`}
                />
              }
            >
              <LuEllipsis />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-40">
              <DropdownMenuItem onClick={onEdit}>
                <LuPencil />
                Edit student
              </DropdownMenuItem>
              <DropdownMenuItem variant="destructive" onClick={onRemove}>
                <LuTrash2 />
                Remove
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </CardAction>
      </CardHeader>

      <Table className="hidden table-fixed sm:table">
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            <TableHead className="w-12 pl-4">#</TableHead>
            <TableHead className="w-44">Date</TableHead>
            <TableHead className="w-40">Start</TableHead>
            <TableHead className="text-right">Hours</TableHead>
            <TableHead className="w-28 text-right">Amount</TableHead>
            <TableHead className="w-14 pr-4" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {student.sessions.map((session, index) => {
            const c = controls(session, index)
            return (
              <TableRow key={session.id}>
                <TableCell className="pl-4 text-muted-foreground tabular-nums">
                  {index + 1}
                </TableCell>
                <TableCell>
                  <div className="w-36 *:w-full">{c.date}</div>
                </TableCell>
                <TableCell>{c.start}</TableCell>
                <TableCell>
                  <div className="flex justify-end">{c.hours}</div>
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {money((session.hrs || 0) * rate)}
                </TableCell>
                <TableCell className="pr-4 text-right">{c.remove}</TableCell>
              </TableRow>
            )
          })}
          <TableRow className="hover:bg-transparent">
            <TableCell colSpan={6} className="px-4">
              {addSession}
            </TableCell>
          </TableRow>
        </TableBody>
        <TableFooter>
          <TableRow className="hover:bg-transparent">
            <TableCell colSpan={3} className="pl-4 text-muted-foreground">
              Total
            </TableCell>
            <TableCell className="text-right tabular-nums">
              {formatNumber(hours)}h
            </TableCell>
            <TableCell className="text-right tabular-nums">
              {money(total)}
            </TableCell>
            <TableCell className="pr-4" />
          </TableRow>
        </TableFooter>
      </Table>

      <div className="sm:hidden">
        <ol className="divide-y border-b">
          {student.sessions.map((session, index) => {
            const c = controls(session, index)
            return (
              <li key={session.id} className="flex flex-col gap-2 px-4 py-3">
                <div className="flex items-center gap-2">
                  <span className="w-4 shrink-0 text-muted-foreground tabular-nums">
                    {index + 1}
                  </span>
                  <div className="min-w-0 flex-1 *:w-full">{c.date}</div>
                  {c.start}
                </div>
                <div className="flex items-center gap-2 pl-6">
                  {c.hours}
                  <span className="text-muted-foreground">hours</span>
                  <span className="ml-auto font-medium tabular-nums">
                    {money((session.hrs || 0) * rate)}
                  </span>
                  {c.remove}
                </div>
              </li>
            )
          })}
        </ol>
        <div className="px-4 py-2">{addSession}</div>
        <div className="flex items-center gap-2 border-t bg-muted/50 px-4 py-2.5 font-medium">
          <span className="text-muted-foreground">Total</span>
          <span className="ml-auto text-muted-foreground tabular-nums">
            {formatNumber(hours)}h
          </span>
          <span className="tabular-nums">{money(total)}</span>
        </div>
      </div>
    </Card>
  )
}
