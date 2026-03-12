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
| **Deployment** | Railway, Cloudflare, Supabase, Infisical | `~/.claude/skills/deployment/` (loaded when relevant) |
| **Design system** | Traba UI tokens, components, layout patterns | `~/.claude/skills/traba-design/` (loaded when relevant) |
| **Data access** | Traba MCP, BigQuery RBAC, ontology (coming soon) | `~/.claude/skills/data-access/` |

**How operators get it:**

```bash
git clone https://github.com/Traba-Ops/claude-config.git ~/.traba-config
cp -r ~/.traba-config/skills/* ~/.claude/skills/
cp -r ~/.traba-config/rules/* ~/.claude/rules/
```

**How updates propagate:** Engineers commit to the repo. A launchd job (twice daily, 10 AM and 7 PM) runs `git pull` and copies updated files into `~/.claude/`. No manual pulling, no external tooling.

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

Covers the full Tier 2 stack: Railway for backends (auto-deploy on push), Cloudflare Pages for frontends, Cloudflare Zero Trust for auth (@traba.work email restriction), Supabase for shared persistence, and Infisical for production secrets (`infisical run` in Railway start command).

### Design System

**Trigger:** User builds any UI mockup, prototype, or front-end code.

Applies the full Traba design system: colors (violet primary, midnight text), fonts (Poppins 400/500/600), layout patterns (154px sidebar, 52px topbar), and component styles (4px tag radius, 8px button radius, 12px card radius).

Single-file skill (~620 lines): critical rules at top, then all tokens, components, layouts, interactivity, data visualization, and content guidelines in build order.

### Data Access (Traba MCP) — Coming Soon

**Trigger:** User needs Traba business data (rates, shifts, workers, etc.).

Will cover: Traba MCP tools for all data access, BigQuery RBAC for access control, and the Traba data ontology for business definitions (rates, shift types, compliance rules). No direct production database connections.

Blocked on ontology and MCP tools from Charles, Javi, and Jeremy.

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

Skills are version-controlled in the `traba-ops/claude-skills` repo. Engineers commit changes, skillshare propagates them.

**When to update:**
- A new failure mode is discovered
- The prescriptive stack changes
- The Traba MCP data layer ontology is updated
- A promoted app reveals a gap in the guidance
