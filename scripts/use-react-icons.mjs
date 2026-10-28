// shadcn/ui components are generated with lucide-react imports. This project
// uses react-icons instead, so rewrite them to the same Lucide icons from
// react-icons/lu. Run it after `npx shadcn add ...` (npm run ui:icons).
import { readdirSync, readFileSync, writeFileSync } from "node:fs"
import { createRequire } from "node:module"
import { join } from "node:path"

const uiDir = join(import.meta.dirname, "../src/components/ui")
const available = new Set(
  Object.keys(createRequire(import.meta.url)("react-icons/lu"))
)
// lucide-react keeps old names as aliases; react-icons only has the current one.
const renamed = { Loader2: "LoaderCircle" }

function toReactIcon(name) {
  const base = name.replace(/^Lucide/, "").replace(/Icon$/, "")
  const icon = `Lu${renamed[base] ?? base}`
  if (!available.has(icon)) {
    throw new Error(`react-icons/lu has no ${icon} (needed for ${name})`)
  }
  return icon
}

for (const file of readdirSync(uiDir).filter((f) => f.endsWith(".tsx"))) {
  const path = join(uiDir, file)
  let source = readFileSync(path, "utf8")
  const match = source.match(/import \{([^}]+)\} from "lucide-react"\n/)
  if (!match) continue

  const icons = new Map(
    match[1]
      .split(",")
      .map((name) => name.trim())
      .filter(Boolean)
      .map((name) => [name, toReactIcon(name)])
  )
  const imports = [...new Set(icons.values())].join(", ")
  source = source.replace(
    match[0],
    `import { ${imports} } from "react-icons/lu"\n`
  )
  for (const [from, to] of icons) {
    source = source.replace(new RegExp(`\\b${from}\\b`, "g"), to)
  }
  writeFileSync(path, source)
  console.log(
    `${file}: ${[...icons].map(([a, b]) => `${a} -> ${b}`).join(", ")}`
  )
}
