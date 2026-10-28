const wholeDollars = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
})
const dollarsAndCents = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
})

/** "$1,235" (rounded to whole dollars) or, with cents, "$1,234.50". */
export function formatUSD(value: number, { cents = false } = {}) {
  // Avoid "-$0" for tiny negative values that round to zero.
  const amount = Object.is(Math.round(value), -0) && !cents ? 0 : value
  return (cents ? dollarsAndCents : wholeDollars).format(amount)
}

/** Up to two decimals without trailing zeros: 1.5, 2, 0.25. */
export function formatNumber(value: number) {
  return Number(value.toFixed(2)).toLocaleString("en-US")
}

/** "1st", "2nd", "3rd", "11th", "22nd" ... */
export function ordinal(n: number) {
  const suffixes = ["th", "st", "nd", "rd"]
  const v = n % 100
  return n + (suffixes[(v - 20) % 10] || suffixes[v] || suffixes[0])
}

/** Parses a "YYYY-MM-DD" string as a local calendar date (not UTC midnight). */
export function parseISODate(value: string | null | undefined) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value ?? "")
  if (!match) return undefined
  return new Date(+match[1], +match[2] - 1, +match[3])
}

export function toISODate(date: Date) {
  const pad = (n: number) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}
