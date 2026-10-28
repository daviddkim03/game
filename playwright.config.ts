import { defineConfig } from "@playwright/test"

const E2E_PORT = 4174
const PRODUCTION_PORT = 4175

/** Builds the site and serves it like GitHub Pages would. */
function server(mode: "e2e" | "production", port: number) {
  const outDir = mode === "e2e" ? "dist-e2e" : "dist-production"
  return {
    command: `npx vite build --mode ${mode} --outDir ${outDir} --emptyOutDir && npx vite preview --mode ${mode} --outDir ${outDir} --port ${port} --strictPort`,
    url: `http://localhost:${port}`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  }
}

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
  use: {
    viewport: { width: 1440, height: 1000 },
    trace: "retain-on-failure",
  },
  projects: [
    {
      // The e2e build swaps Firebase for an in-memory backend (src/lib/sync/e2e-backend.ts).
      name: "e2e",
      testIgnore: /production\.spec\.ts/,
      use: { baseURL: `http://localhost:${E2E_PORT}` },
    },
    {
      // The real bundle with the real Firebase config, signed out.
      name: "production",
      testMatch: /production\.spec\.ts/,
      use: { baseURL: `http://localhost:${PRODUCTION_PORT}` },
    },
  ],
  webServer: [server("e2e", E2E_PORT), server("production", PRODUCTION_PORT)],
})
