export type Quote = { text: string; author: string }

/** Money quotes with well-documented sources (no famous misattributions). */
export const QUOTES: Quote[] = [
  {
    text: "Beware of little expenses; a small leak will sink a great ship.",
    author: "Benjamin Franklin",
  },
  { text: "Remember that time is money.", author: "Benjamin Franklin" },
  {
    text: "If you would be wealthy, think of saving as well as getting.",
    author: "Benjamin Franklin",
  },
  {
    text: "Wealth is not his that has it, but his that enjoys it.",
    author: "Benjamin Franklin",
  },
  {
    text: "Price is what you pay. Value is what you get.",
    author: "Warren Buffett",
  },
  {
    text: "Rule No. 1: Never lose money. Rule No. 2: Never forget rule No. 1.",
    author: "Warren Buffett",
  },
  {
    text: "Someone's sitting in the shade today because someone planted a tree a long time ago.",
    author: "Warren Buffett",
  },
  {
    text: "Money is in some respects like fire; it is a very excellent servant but a terrible master.",
    author: "P. T. Barnum",
  },
  { text: "Money often costs too much.", author: "Ralph Waldo Emerson" },
  {
    text: "Never spend your money before you have it.",
    author: "Thomas Jefferson",
  },
  {
    text: "Lack of money is the root of all evil.",
    author: "George Bernard Shaw",
  },
  {
    text: "Money is only a tool. It will take you wherever you wish, but it will not replace you as the driver.",
    author: "Ayn Rand",
  },
  {
    text: "Know what you own, and know why you own it.",
    author: "Peter Lynch",
  },
  {
    text: "Formal education will make you a living; self-education will make you a fortune.",
    author: "Jim Rohn",
  },
  {
    text: "The four most dangerous words in investing are: ‘This time it’s different.’",
    author: "John Templeton",
  },
  {
    text: "Money is better than poverty, if only for financial reasons.",
    author: "Woody Allen",
  },
]

const LAST_QUOTE_KEY = "home:last-quote"

/** A random quote for this page load, never the same one twice in a row. */
export function pickQuote(random: () => number = Math.random): Quote {
  let last = -1
  try {
    last = Number(localStorage.getItem(LAST_QUOTE_KEY) ?? -1)
  } catch {
    // Storage can be blocked; any quote will do then.
  }
  const skip = Number.isInteger(last) && last >= 0 && last < QUOTES.length
  let index = Math.floor(random() * (skip ? QUOTES.length - 1 : QUOTES.length))
  if (skip && index >= last) index += 1
  try {
    localStorage.setItem(LAST_QUOTE_KEY, String(index))
  } catch {
    // Same as above.
  }
  return QUOTES[index]
}
