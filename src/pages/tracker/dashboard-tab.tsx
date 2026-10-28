import type { CSSProperties, ReactNode } from "react"
import {
  Bar,
  BarChart,
  CartesianGrid,
  Label,
  Pie,
  PieChart,
  XAxis,
  YAxis,
} from "recharts"

import { NumberInput } from "@/components/number-input"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
import { Field, FieldDescription, FieldLabel } from "@/components/ui/field"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupText,
} from "@/components/ui/input-group"
import { Progress } from "@/components/ui/progress"
import { formatUSD } from "@/lib/format"
import * as actions from "@/pages/tracker/actions"
import { ColorDot } from "@/pages/tracker/components"
import { categoryColor } from "@/pages/tracker/model"
import type { TrackerApi } from "@/pages/tracker/use-tracker"

const percent = (value: number) => `${Math.round(value)}%`

export function DashboardTab({ data, summary: s, update }: TrackerApi) {
  const positive = s.game >= 0
  const gameColor = positive ? "var(--positive)" : "var(--destructive)"
  const savingsRate = s.earn > 0 ? Math.round((s.game / s.earn) * 100) : 0
  const monthsToChecking =
    s.game > 0 ? Math.ceil(s.checkingGoal / s.game) : null
  const monthsToEmergency =
    s.game > 0 ? Math.ceil(s.emergencyGoal / s.game) : null

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Kpi
          label="Monthly gross"
          value={formatUSD(s.gross)}
          note={`Taxed ${formatUSD(s.taxed)} · Untaxed ${formatUSD(s.untaxed)}`}
        />
        <Kpi
          label="Take-home"
          value={formatUSD(s.earn)}
          note={`After ${percent(data.taxRate * 100)} tax on taxed income`}
        />
        <Kpi
          label="Monthly expenses"
          value={formatUSD(s.expenses)}
          note={`${s.expenseCount} item${s.expenseCount === 1 ? "" : "s"}`}
        />
        <Kpi
          label="GAME"
          value={formatUSD(s.game)}
          note={`${savingsRate}% of take-home saved`}
          valueStyle={{ color: gameColor }}
        />
      </div>

      <div className="grid gap-3 md:grid-cols-2">
        <SpendingChart data={data} summary={s} />
        <ComparisonChart summary={s} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>GAME savings breakdown</CardTitle>
          <CardDescription>
            What's left of take-home pay after monthly expenses.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <div className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
            <span
              className="text-3xl font-semibold tracking-tight tabular-nums"
              style={{ color: gameColor }}
            >
              {formatUSD(s.game)}
            </span>
            <span className="text-muted-foreground">saved each month</span>
            {s.annualBonus > 0 && (
              <span className="text-sm text-muted-foreground">
                + {formatUSD(s.annualBonus)} bonus at year end
              </span>
            )}
          </div>
          <Progress
            value={Math.max(0, Math.min(100, savingsRate))}
            aria-label="Share of take-home saved"
            className="[&_[data-slot=progress-indicator]]:bg-(--game) [&_[data-slot=progress-track]]:h-2"
            style={{ "--game": gameColor } as CSSProperties}
          />
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            <MiniStat
              label="Gross income"
              value={formatUSD(s.gross)}
              note="100% of gross"
            />
            <MiniStat
              label="Take-home"
              value={formatUSD(s.earn)}
              note={`${percent(s.gross ? (s.earn / s.gross) * 100 : 0)} of gross`}
            />
            <MiniStat
              label="Expenses"
              value={formatUSD(s.expenses)}
              note={`${percent(s.earn ? (s.expenses / s.earn) * 100 : 0)} of take-home`}
            />
            <MiniStat
              label="GAME"
              value={formatUSD(s.game)}
              note={`${savingsRate}% of take-home`}
            />
            <MiniStat
              label="Annual savings"
              value={formatUSD(Math.max(0, s.game) * 12)}
              note="projected"
            />
            <MiniStat
              label="Pure savings / yr"
              value={formatUSD(s.pureSavings)}
              note="after-tax minus expenses"
            />
          </div>
        </CardContent>
        <CardFooter className="flex-wrap gap-x-5 gap-y-1 text-sm text-muted-foreground [&_strong]:font-medium [&_strong]:text-foreground [&_strong]:tabular-nums">
          <span>
            Checking (2×) <strong>{formatUSD(s.checkingGoal)}</strong>
          </span>
          <span>
            Emergency (6×) <strong>{formatUSD(s.emergencyGoal)}</strong>
          </span>
          <span>
            Months to checking <strong>{monthsToChecking ?? "—"}</strong>
          </span>
          <span>
            Months to emergency <strong>{monthsToEmergency ?? "—"}</strong>
          </span>
        </CardFooter>
      </Card>

      <div className="grid gap-3 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Annual summary</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="divide-y text-sm">
              {[
                ["Annual gross (incl. bonus)", s.annualGross],
                ["Annual after-tax", s.afterTax],
                ["Annual bonus (net)", s.annualBonusNet],
                ["Pure savings", s.pureSavings],
                ["Tax paid", s.annualGross - s.afterTax],
              ].map(([label, value]) => (
                <div
                  key={label}
                  className="flex justify-between gap-4 py-2 first:pt-0 last:pb-0"
                >
                  <dt className="text-muted-foreground">{label}</dt>
                  <dd className="font-medium tabular-nums">
                    {formatUSD(value as number)}
                  </dd>
                </div>
              ))}
            </dl>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Settings</CardTitle>
          </CardHeader>
          <CardContent>
            <Field className="gap-2">
              <FieldLabel htmlFor="tax-rate">
                Tax rate on taxed income
              </FieldLabel>
              <InputGroup className="w-32!">
                <NumberInput
                  grouped
                  id="tax-rate"
                  min={0}
                  max={99}
                  className="tabular-nums"
                  value={Math.round(data.taxRate * 100)}
                  onValueChange={(value) =>
                    update((d) => actions.setTaxRate(d, value ?? 0))
                  }
                />
                <InputGroupAddon align="inline-end">
                  <InputGroupText>%</InputGroupText>
                </InputGroupAddon>
              </InputGroup>
              <FieldDescription>
                Take-home is{" "}
                <span className="font-medium text-foreground tabular-nums">
                  {formatUSD(s.earn)}
                </span>
                /mo. Changes save on this device and sync to the cloud.
              </FieldDescription>
            </Field>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function Kpi({
  label,
  value,
  note,
  valueStyle,
}: {
  label: string
  value: string
  note: string
  valueStyle?: CSSProperties
}) {
  return (
    <Card size="sm" className="gap-1">
      <CardHeader className="gap-0.5">
        <CardDescription className="text-xs">{label}</CardDescription>
        <CardTitle
          className="text-xl font-semibold tracking-tight tabular-nums group-data-[size=sm]/card:text-xl"
          style={valueStyle}
        >
          {value}
        </CardTitle>
      </CardHeader>
      <CardContent className="text-xs text-muted-foreground">
        {note}
      </CardContent>
    </Card>
  )
}

function MiniStat({
  label,
  value,
  note,
}: {
  label: string
  value: string
  note: ReactNode
}) {
  return (
    <div className="flex flex-col gap-0.5 rounded-lg bg-muted/60 px-3 py-2.5 text-center">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="font-medium tabular-nums">{value}</span>
      <span className="text-xs text-muted-foreground">{note}</span>
    </div>
  )
}

function SpendingChart({
  data,
  summary: s,
}: Pick<TrackerApi, "data" | "summary">) {
  const slices = [
    ...Object.entries(s.byCategory).map(([name, value]) => ({
      name,
      value,
      fill: categoryColor(data, name),
    })),
    { name: "GAME", value: Math.max(0, s.game), fill: "var(--positive)" },
  ]
  const config = Object.fromEntries(
    slices.map((slice) => [
      slice.name,
      { label: slice.name, color: slice.fill },
    ])
  ) satisfies ChartConfig

  return (
    <Card>
      <CardHeader>
        <CardTitle>Where your take-home goes</CardTitle>
        <CardDescription>
          Monthly expenses by category, plus GAME
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <ChartContainer config={config} className="mx-auto aspect-square h-52">
          <PieChart>
            <ChartTooltip
              cursor={false}
              content={
                <ChartTooltipContent
                  hideLabel
                  formatter={(value, name, item) => (
                    <TooltipRow
                      color={item.payload.fill}
                      label={String(name)}
                      value={`${formatUSD(Number(value))} (${s.earn > 0 ? Math.round((Number(value) / s.earn) * 100) : 0}%)`}
                    />
                  )}
                />
              }
            />
            <Pie
              data={slices}
              dataKey="value"
              nameKey="name"
              innerRadius="64%"
              strokeWidth={2}
              stroke="var(--card)"
            >
              <Label
                content={({ viewBox }) => {
                  if (!viewBox || !("cx" in viewBox)) return null
                  return (
                    <text
                      x={viewBox.cx}
                      y={viewBox.cy}
                      textAnchor="middle"
                      dominantBaseline="middle"
                    >
                      <tspan
                        x={viewBox.cx}
                        y={(viewBox.cy ?? 0) - 6}
                        className="fill-foreground text-lg font-semibold"
                      >
                        {formatUSD(s.earn)}
                      </tspan>
                      <tspan
                        x={viewBox.cx}
                        y={(viewBox.cy ?? 0) + 14}
                        className="fill-muted-foreground text-xs"
                      >
                        take-home
                      </tspan>
                    </text>
                  )
                }}
              />
            </Pie>
          </PieChart>
        </ChartContainer>
        <ul className="flex flex-wrap justify-center gap-x-3 gap-y-1.5">
          {slices.map((slice) => (
            <li
              key={slice.name}
              className="flex items-center gap-1.5 text-xs text-muted-foreground"
            >
              <ColorDot color={slice.fill} className="rounded-[3px]" />
              {slice.name}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  )
}

function ComparisonChart({ summary: s }: Pick<TrackerApi, "summary">) {
  const bars = [
    { name: "Gross", value: s.gross, fill: "#888780" },
    { name: "Take-home", value: s.earn, fill: "#378ADD" },
    { name: "Expenses", value: s.expenses, fill: "#E24B4A" },
    {
      name: "GAME",
      value: s.game,
      fill: s.game >= 0 ? "var(--positive)" : "var(--destructive)",
    },
  ]
  const config = { value: { label: "Monthly" } } satisfies ChartConfig

  return (
    <Card>
      <CardHeader>
        <CardTitle>Gross vs take-home vs GAME</CardTitle>
        <CardDescription>Per month</CardDescription>
      </CardHeader>
      <CardContent className="flex-1">
        <ChartContainer config={config} className="aspect-auto h-60 w-full">
          <BarChart data={bars} margin={{ top: 8, left: 4, right: 4 }}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="name"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              width={56}
              tickFormatter={(value: number) => formatUSD(value)}
            />
            <ChartTooltip
              cursor={false}
              content={
                <ChartTooltipContent
                  hideLabel
                  formatter={(value, _name, item) => (
                    <TooltipRow
                      color={item.payload.fill}
                      label={item.payload.name}
                      value={formatUSD(Number(value))}
                    />
                  )}
                />
              }
            />
            <Bar dataKey="value" radius={6} maxBarSize={56} />
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
  )
}

function TooltipRow({
  color,
  label,
  value,
}: {
  color: string
  label: string
  value: string
}) {
  return (
    <div className="flex w-full items-center gap-2">
      <ColorDot color={color} className="size-2.5 rounded-[2px]" />
      <span className="text-muted-foreground">{label}</span>
      <span className="ml-auto pl-3 font-mono font-medium text-foreground tabular-nums">
        {value}
      </span>
    </div>
  )
}
