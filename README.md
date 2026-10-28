# System

Private tools that sync across your devices:

- **GAME Tracker** (`/game_tracker/`): income, expenses, savings buckets, and bill due dates on a calendar.
- **Weekly Schedule** (`/schedule/`): a week of color-coded time blocks you drag to create, move, resize, and copy.
- **Payment Report** (`/payment/`): tutoring sessions billed by the hour, printable as a spreadsheet-style PDF.

Each tool keeps its data in the browser and syncs it to Firestore. See [FIREBASE_SETUP.md](FIREBASE_SETUP.md).

## Stack

React, TypeScript, and [Vite](https://vite.dev) build one page per tool. The UI uses [shadcn/ui](https://ui.shadcn.com) components on [Base UI](https://base-ui.com) with the Neutral theme (`src/index.css`), and icons from [react-icons](https://react-icons.github.io/react-icons/) (the Lucide set, `react-icons/lu`).

## Development

```sh
npm install
npm run dev        # http://localhost:5173 (uses the real Firebase project)
npx vite --mode e2e  # same, but with an in-memory backend and no sign-in
```

| Command             | What it does                                     |
| ------------------- | ------------------------------------------------ |
| `npm run build`     | Typechecks and builds the site into `dist/`      |
| `npm run lint`      | ESLint                                           |
| `npm run format`    | Prettier (also sorts Tailwind classes)           |
| `npm run test:unit` | Vitest for the money, schedule, and report logic |
| `npm run test:e2e`  | Playwright against e2e and production builds     |

### Adding shadcn/ui components

The shadcn CLI writes components with `lucide-react` imports. After adding one, switch them to react-icons:

```sh
npx shadcn@latest add <component>
npm run ui:icons
```

## Deployment

Pushing to `main` runs the checks and tests in `.github/workflows/pages.yml`, then builds and deploys `dist/` to GitHub Pages. Pages use relative URLs, so the site works from any path.
