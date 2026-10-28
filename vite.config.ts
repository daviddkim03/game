/// <reference types="vitest/config" />
import { resolve } from "node:path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig, type Plugin } from "vite"

const root = import.meta.dirname

/**
 * Applies the saved theme before the first paint so dark mode never flashes.
 * Keep the storage key in sync with THEME_STORAGE_KEY in theme-provider.tsx.
 */
function themeBootstrap(): Plugin {
  const script = `try{var t=localStorage.getItem("theme");var d=t==="dark"||(t!=="light"&&matchMedia("(prefers-color-scheme: dark)").matches);document.documentElement.classList.add(d?"dark":"light")}catch(e){}`
  return {
    name: "theme-bootstrap",
    transformIndexHtml: () => [
      { tag: "script", children: script, injectTo: "head-prepend" },
    ],
  }
}

// Each tool is its own page, so the URLs people already bookmarked keep working.
export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss(), themeBootstrap()],
  resolve: {
    alias: {
      "@": resolve(root, "src"),
    },
  },
  build: {
    // Firebase Auth + Firestore alone is ~530 kB minified (155 kB gzipped).
    chunkSizeWarningLimit: 600,
    rolldownOptions: {
      input: {
        home: resolve(root, "index.html"),
        tracker: resolve(root, "game_tracker/index.html"),
        schedule: resolve(root, "schedule/index.html"),
        payment: resolve(root, "payment/index.html"),
      },
      output: {
        // Big, rarely-changing libraries get their own long-cached chunks.
        codeSplitting: {
          groups: [
            { name: "firebase", test: /node_modules[\\/]@?firebase[\\/]/ },
            {
              name: "react",
              test: /node_modules[\\/](react|react-dom|scheduler)[\\/]/,
            },
          ],
        },
      },
    },
  },
  test: {
    include: ["src/**/*.test.ts"],
  },
})
