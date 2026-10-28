import { mountApp } from "@/app/mount"
import { HomePage } from "@/pages/home/home-page"
import { pickQuote } from "@/pages/home/quotes"

// A new quote on every load.
mountApp(<HomePage quote={pickQuote()} />)
