---
name: project-setup
description: |
  Stack, toolchain, and scaffolding for Traba projects. Use when:
  (1) starting a new project, (2) choosing between technologies,
  (3) initializing a repo or adding dependencies.
version: 2.0.0
---

# Project Setup

## Tier Detection

Read the repo before choosing a stack. Use what's already there:
- If the project has Supabase, Railway, or Cloudflare dependencies, it's a deployed app. Keep using them.
- If the project has SQLite, JSON files, or no persistence, it's a local prototype. Keep it simple.
- If the project is brand new, default to local: SQLite or JSON files, no external services.

## Stack

- **Language:** TypeScript by default. Only use Python when the use case requires a Python-specific library (ML/data science with pandas/numpy/scikit-learn, or wrapping a Python-only API). If in doubt, use TypeScript.
- **Backend framework:** Hono (TypeScript) or FastAPI (Python). Do NOT use Express, NestJS, Koa, or Flask.
- **Frontend:** React + Vite
- **Styling:** CSS custom properties from the Traba design system (see design system skill). Do NOT use MUI, styled-components, or Tailwind — the design system tokens are the component library.
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
  packages/
    shared/       # Shared types, schemas, constants
  package.json    # bun workspace root
```

### Root package.json

```json
{
  "name": "my-project",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev": "bun run --parallel --filter '*' dev",
    "build": "bun run --parallel --filter '*' build",
    "lint": "bun run --parallel --filter '*' lint",
    "typecheck": "bun run --parallel --filter '*' typecheck"
  }
}
```

### Shared types between frontend and backend

Use live types — export `.ts` files directly from `packages/shared/`. No build step needed for internal packages. The consuming app's bundler handles transpilation.

In `packages/shared/package.json`:
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
2. Create the monorepo structure (`apps/web/`, `apps/api/`, `packages/shared/`)
3. Create root `package.json` with workspaces config
4. Create a `.gitignore` from the template: [gitignore.template](gitignore.template)
5. Set up gitleaks as a pre-commit hook from: [pre-commit-config.template](pre-commit-config.template)
6. Frontend: `cd apps/web && bun create vite . --template react-ts`
7. Backend: `cd apps/api && bun init`
8. Shared: create `packages/shared/` with `package.json` and `src/index.ts`
9. Add `tsconfig.json` to each package (`apps/web/`, `apps/api/`, `packages/shared/`):
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
12. Add a `railway.json` at the repo root (see deployment skill for the template). This prevents Nixpacks from guessing wrong in the monorepo.
13. Run `bun install` from root to link workspaces
