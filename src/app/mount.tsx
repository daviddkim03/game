import { StrictMode, type ReactNode } from "react"
import { createRoot } from "react-dom/client"

import "@/index.css"
import { AuthGate } from "@/components/auth-gate"
import { DialogsProvider } from "@/components/dialogs"
import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/toast"
import { TooltipProvider } from "@/components/ui/tooltip"

/** Renders a page with the providers every tool shares. */
export function mountApp(page: ReactNode) {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <ThemeProvider>
        <TooltipProvider delay={300}>
          <Toaster>
            <DialogsProvider>
              <AuthGate>{page}</AuthGate>
            </DialogsProvider>
          </Toaster>
        </TooltipProvider>
      </ThemeProvider>
    </StrictMode>
  )
}
