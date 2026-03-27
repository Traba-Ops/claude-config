# Claude Skills Spec

The Prometheus skills bundle is how the framework is delivered. It's a set of instructions that shape Claude's behavior: how to handle security, how to maintain project context, what stack to use, how to build toward a spec. This is the control surface.

## Delivery

The skills bundle lives in a **shared repo** on the `Traba-Ops` GitHub org ([`Traba-Ops/claude-config`](https://github.com/Traba-Ops/claude-config)). Operators clone it once and copy skills + rules into `~/.claude/`. A launchd job pulls updates automatically.

**What gets installed:**

| Type | What it does | Where it goes |
|------|-------------|---------------|
| **Constitution** | Role, principles, requirements gathering, security, development hygiene | `~/.claude/rules/traba-constitution.md` (always active) |
| **Project documentation** | README + SPEC.md, decision records | `~/.claude/rules/traba-spec.md` (always active) |
| **Project setup** | Stack, toolchain, tier detection, scaffolding templates | `~/.claude/skills/project-setup/` (loaded when relevant) |
| **Deployment** | Railway, Cloudflare Access, Supabase | `~/.claude/skills/deployment/` (loaded when relevant) |
| **Design system** | Traba UI tokens, components, layout patterns | `~/.claude/skills/traba-design/` (loaded when relevant) |
| **Data access** | Traba MCP, BigQuery RBAC, ontology (coming soon) | `~/.claude/skills/data-access/` |

**How operators get it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Traba-Ops/claude-config/main/install.sh | sh
```

The installer clones the repo, copies skills + rules into `~/.claude/`, and sets up git tracking. The operator then sets up auto-updates in Claude Code:

> "Set up a launchd job that runs `cd ~/.claude && git pull` every hour between 9 AM and 9 PM"

**How updates propagate:** Engineers commit to the repo. Each operator's launchd job runs `git pull` hourly during working hours, pulling updated skills and rules automatically.

---

## Rules (Always Active)

Rules load every session, every project. They're flat markdown files in `~/.claude/rules/`.

### Constitution (`traba-constitution.md`)

Defines Claude's role as a technical collaborator for non-technical operators. Principle hierarchy: security > development hygiene > simplicity > everything else.

- **Role:** Technical collaborator. Defer to operator on domain, own the technical side.
- **Simplicity:** Build the simplest thing that works. No production-grade engineering unless promoted.
- **Technical autonomy:** Make technical decisions without asking. Fix technical problems. Only escalate product decisions.
- **Defer to operational expertise:** Operator knows the domain. Believe them on business logic.
- **Protect the operator's work:** No destructive git ops, checkpoint before overwriting.
- **Before building:** Lightweight requirements gathering (problem, user, outcome, data, scope).
- **Security:** Never hardcode secrets, never commit .env, no stack traces in production.
- **Development hygiene:** Checkpoint on request, commit messages explain what and why.

### Project Documentation (`traba-spec.md`)

Maintains two living documents per project, building toward Tier 1 promotion:
- **README.md** (user-facing): what the app does, who uses it, how to run it, how to use it. Simple and accessible.
- **SPEC.md** (engineer-facing): business rules, data model with types, key workflows with edge cases, integrations and external dependencies, known limitations. Technical depth an engineer needs to re-implement.
- **Decision records** (`decisions/YYYY-MM-DD-topic.md`): what the options were, what was chosen and why, what was rejected.

Both documents update continuously as the project evolves — not at session end, not periodically, but when things change. Operator corrections to business logic go directly into the spec.

---

## Skills (Context-Dependent)

Skills load when Claude determines they're relevant. Each is a directory with a `SKILL.md` entry point and optional reference files.

### Project Setup

**Trigger:** Starting a new project, choosing technologies, initializing a repo.

Reads the repo to detect what tier the project is at:
- New project or local-only dependencies (SQLite, JSON files): default to simple, local stack.
- Supabase/Railway/Cloudflare dependencies already present: keep using them.

**Backend:** TypeScript + bun (runtime and package manager), oxlint, oxfmt, tsgo. Python + uv for scripts/data work.

**Frontend:** React + Vite. Styling via CSS custom properties from the design system (no MUI, no styled-components). TanStack React Query + React Context for state. React Router DOM for routing. Vitest for testing.

**Monorepo:** Every project uses bun workspaces with `apps/web/`, `apps/api/`, `packages/shared/`. Shared types via live `.ts` exports (no build step for internal packages).

Includes `.gitignore` and `.pre-commit-config.yaml` as reference files — Claude creates these during scaffolding.

### Deployment

**Trigger:** User wants to deploy, share, or make their app accessible to others.

Covers the full Tier 2 stack: Railway (single service: backend serves frontend as static files, auto-deploy on push), Cloudflare Zero Trust for auth (@traba.work email restriction), Supabase for shared persistence, and Railway environment variables for secrets.

### Design System

**Trigger:** User builds any UI mockup, prototype, or front-end code.

Applies the full Traba design system: colors (violet primary, midnight text), fonts (Poppins 400/500/600), layout patterns (154px sidebar, 52px topbar), and component styles (4px tag radius, 8px button radius, 12px card radius).

Single-file skill (~620 lines): critical rules at top, then all tokens, components, layouts, interactivity, data visualization, and content guidelines in build order.

### Data Access — Coming Soon

**Trigger:** User needs Traba business data (rates, shifts, workers, etc.).

Will cover: BigQuery access via a token store pattern (using authenticated user OAuth tokens), data ontology for business definitions, and access control. A standardized approach is in progress — see [open questions](open-questions.md#3-data-access-layer-for-prometheus-apps-bigquery--token-store).

Until this skill ships, operators use workarounds: nightly data pulls to local files or direct BQ queries with a service account.

---

## What the Skills Do NOT Cover

Skills are guidance, not enforcement. Things that MUST be enforced outside of Claude:

| Risk | Hard Enforcement |
|------|------------------|
| Secret leakage | Gitleaks pre-commit + GitHub push protection |
| Exposed endpoints | Cloudflare Zero Trust as reverse proxy |
| Dependency vulnerabilities | Dependabot |
| Cost overruns | Cloud billing alerts |

---

## Maintenance

Skills are version-controlled in the [`Traba-Ops/claude-config`](https://github.com/Traba-Ops/claude-config) repo. Engineers commit changes, and operator launchd jobs pull them automatically.

**When to update:**
- A new failure mode is discovered
- The prescriptive stack changes
- The Traba MCP data layer ontology is updated
- A promoted app reveals a gap in the guidance
