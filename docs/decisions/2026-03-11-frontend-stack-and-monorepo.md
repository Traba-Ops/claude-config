# Frontend Stack and Monorepo Structure

## Context
The Prometheus project-setup skill prescribed a backend stack (TypeScript + bun, Python + uv) but had no frontend framework guidance. Operators building internal tools with UIs had no prescribed frontend stack. Additionally, projects with both frontend and backend had no monorepo guidance.

## Approaches Considered

### Frontend Framework
#### Option 1: React + Vite
Matches Traba's core frontend (business-app, ops-console, aperture-vite all use React + Vite). Largest ecosystem for AI-generated code. No SSR overhead.

#### Option 2: Next.js
More batteries-included (SSR, file-based routing, API routes). But internal tools don't need SSR, and the additional complexity is wasted.

#### Option 3: No framework (vanilla HTML)
Simpler for one-off dashboards, but doesn't scale to multi-page apps with routing and state.

### Styling
#### Option 1: CSS custom properties (design system tokens)
The design system skill already defines all colors, typography, components as CSS vars and utility classes. Lightweight, consistent.

#### Option 2: MUI (matches core Traba frontend)
The core frontend uses MUI + styled-components. But MUI fights custom design tokens, adds ~300KB, and is overkill for internal tools.

### Package Manager / Monorepo
#### Option 1: bun for everything
One tool. Workspaces exist, `--filter` works for scripts, `workspace:*` protocol supported. Less mature than pnpm (no `--filter` for `bun add`, newer isolated install mode has bugs), but gaps don't matter for small projects where Claude handles all commands.

#### Option 2: pnpm workspaces + bun runtime
pnpm is more battle-tested for monorepos. But adds a second tool operators need installed.

#### Option 3: pnpm for everything (drop bun)
Simplifies to one tool but loses bun's runtime speed. Would need tsx or node --experimental-strip-types for TypeScript execution.

### Monorepo vs not
#### Option 1: Always monorepo
Consistent structure, Claude scaffolds the same thing every time. Adding a frontend to a backend-only project is trivial.

#### Option 2: Monorepo only when needed
Less overhead for simple projects, but inconsistent structure and requires restructuring when adding a second app.

## Decision
- **React + Vite** — aligns with core frontend, no SSR overhead
- **CSS custom properties** — design system tokens directly, no component library
- **TanStack React Query + React Context** — matches core frontend patterns, no Redux
- **bun for everything** — one tool, optimized for simplicity. Workspace gaps are in areas that don't affect small operator tools (publishing, complex version matrices). If a project outgrows bun workspaces, it's ready for Tier 1 promotion anyway.
- **Always monorepo** — consistent structure across all Prometheus projects
