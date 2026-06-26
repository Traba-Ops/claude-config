---
name: project-setup
description: |
  Stack, toolchain, and scaffolding for Traba projects. Use when:
  (1) starting a new project, (2) choosing between technologies,
  (3) initializing a repo or adding dependencies.
version: 2.1.0
---

# Project Setup

## Tier Detection

Read the repo before choosing a stack. Use what's already there:
- If the project has Railway Postgres or Railway dependencies, it's a deployed app. Keep using them.
- If the project has SQLite, JSON files, or no persistence, it's a local prototype. Keep it simple.
- If the project is brand new, default to local: SQLite or JSON files, no external services.

## Stack

- **Language:** TypeScript by default. Only use Python when the use case requires a Python-specific library (ML/data science with pandas/numpy/scikit-learn, or wrapping a Python-only API). If in doubt, use TypeScript.
- **Backend framework:** Hono (TypeScript) or FastAPI (Python). Do NOT use Express, NestJS, Koa, or Flask.
- **Frontend:** React + Vite
- **Styling:** Tailwind CSS v4 (`@tailwindcss/vite`) + shadcn/ui (Radix primitives). Design tokens mapped in `app.css` via `@theme` — see the design system skill for the token mapping and reference components. Add `@/*` path alias to tsconfig + vite config for shadcn imports. Add components as needed: `bunx shadcn@latest add tooltip sheet select`.
- **State management:** TanStack React Query for data fetching, React Context for app state. No Redux.
- **Routing:** React Router DOM
- **Local data storage:** SQLite (single file, no setup) or JSON files for simple data
- **Testing:** Vitest (for both frontend and backend — native Vite integration)
- When the app needs shared persistence across users, see the deployment skill

## Toolchain

- **TypeScript:** bun (package manager + runtime), oxlint (linter), oxfmt (formatter), tsgo (type checking)
- **Python (only when needed):** uv (package manager + virtualenv + Python version management)
- Do not use npm, yarn, pnpm, pip, or virtualenv directly

## Project Structure — Always Monorepo

Every project uses a monorepo structure with bun workspaces, even if it starts with only a frontend or only a backend. This keeps the structure consistent and makes adding the other side trivial.

```
my-project/
  apps/
    web/          # React + Vite frontend
    api/          # Hono backend (bun runtime)
    shared/       # Shared types, schemas, constants
  package.json    # bun workspace root
```

### Root package.json

```json
{
  "name": "my-project",
  "private": true,
  "workspaces": ["apps/*"],
  "scripts": {
    "dev": "bun run --parallel --filter '*' dev",
    "build": "bun run --parallel --filter '*' build",
    "lint": "bun run --parallel --filter '*' lint",
    "typecheck": "bun run --parallel --filter '*' typecheck"
  }
}
```

### Shared types between frontend and backend

Use live types — export `.ts` files directly from `apps/shared/`. No build step needed for internal packages. The consuming app's bundler handles transpilation.

In `apps/shared/package.json`:
```json
{
  "name": "@project/shared",
  "exports": {
    ".": "./src/index.ts"
  }
}
```

Consuming packages reference it via `workspace:*`:
```json
{
  "dependencies": {
    "@project/shared": "workspace:*"
  }
}
```

### Adding dependencies to a specific package

bun doesn't support `--filter` for `bun add`. Instead, `cd` into the package directory:
```bash
cd apps/web && bun add react-router-dom
```

## Scaffolding New Projects

When starting a new project:
1. Initialize a git repository
2. Create the monorepo structure (`apps/web/`, `apps/api/`, `apps/shared/`)
3. Create root `package.json` with workspaces config
4. Create a `.gitignore` from the template: [gitignore.template](gitignore.template)
5. Set up gitleaks as a pre-commit hook from: [pre-commit-config.template](pre-commit-config.template)
6. Frontend: `cd apps/web && bun create vite . --template react-ts`
7. Backend: `cd apps/api && bun init`
8. Shared: create `apps/shared/` with `package.json` and `src/index.ts`
9. Add `tsconfig.json` to each package (`apps/web/`, `apps/api/`, `apps/shared/`):
   ```json
   {
     "compilerOptions": {
       "target": "ES2022",
       "module": "ESNext",
       "moduleResolution": "bundler",
       "strict": true,
       "noUncheckedIndexedAccess": true,
       "skipLibCheck": true,
       "esModuleInterop": true
     },
     "include": ["src"]
   }
   ```
10. Add `"typecheck": "tsgo --noEmit"` to each app's `package.json` scripts
11. Set up the backend to serve the frontend in production (see deployment skill for details). The backend should serve static files from `../web/dist/` with a SPA catch-all fallback after all API routes.
12. Add a `nixpacks.toml` and a `railway.json` at the repo root (see deployment skill for the templates). `nixpacks.toml` pins the runtime (bun + Node 22) and owns the build phases — without it Nixpacks defaults to an EOL Node and the build fails before any command runs; `railway.json` sets the builder and restart policy.
13. Create the project documentation skeleton (see "The Living Documents" below for what goes in each):
    - `README.md` — what this does, who uses it, how to run it, how to use it
    - `SPEC.md` — business rules, data model, key workflows, integrations, known limitations
    - `decisions/` directory for append-only decision records
14. Run `bun install` from root to link workspaces

## The Living Documents

The constitution requires three docs maintained as a byproduct of building — README, SPEC, and decision records. Neither the README nor the SPEC requires effort from the operator; they're written as you work and updated inline when things change, not at session end. Here's what goes in each.

### README.md

For anyone who opens the repo or uses the app. Keep it short, no technical depth.

- **What this does:** one paragraph on the problem and the solution
- **Who uses it:** which team, what workflow, how often
- **How to run it:** setup steps, environment variables, prerequisites
- **How to use it:** the main things users do, briefly

### SPEC.md

Enough that an engineer could re-implement the app from it alone. Accumulates detail as the project grows.

- **Business rules:** the actual logic the app encodes. Not "manages shifts" but "shifts within 30 miles of a worker's home zip are local; beyond that, travel pay applies." When the operator corrects your understanding, capture the corrected rule here.
- **Data model:** tables/collections, fields with types, relationships, where data comes from (MCP tools, APIs, manual entry). Example values where they clarify meaning.
- **Key workflows:** step-by-step, including error and edge cases — precise enough to implement without the operator present.
- **Integrations:** external systems the app talks to (APIs, MCP tools, databases, third-party services): what goes in, what comes back, what credentials are needed.
- **Known limitations:** what it doesn't handle, known bugs, workarounds, things intentionally simple.

### Decision records (`decisions/YYYY-MM-DD-topic.md`)

When a meaningful choice is made (e.g., "polling instead of websockets because the data only changes hourly"), record the options with trade-offs, what was chosen, and why. Append-only — if a decision is later reversed, write a new record explaining why. Commit them automatically.
