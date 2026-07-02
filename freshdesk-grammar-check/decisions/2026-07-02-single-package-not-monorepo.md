# 2026-07-02 — Single package, not the standard apps/ monorepo

## Context

The `project-setup` skill prescribes an `apps/web` + `apps/api` + `apps/shared`
bun-workspace monorepo for every project. This tool is a headless scheduled worker:
no frontend, no HTTP server, no shared types across packages.

## Decision

Ship it as a single bun/TypeScript package (`src/` + `test/`). The monorepo layout
exists to make adding a frontend/backend trivial; there is nothing here for it to
hold, and empty `apps/web`/`apps/api` shells would be noise.

## Consequences

- Still follows the rest of the stack: bun runtime, TypeScript, Vitest, the standard
  `.gitignore` and gitleaks pre-commit hook, `tsgo`/`tsc` typecheck.
- If this ever grows a UI (e.g. a dashboard of flagged replies), restructure into the
  standard monorepo at that point.
