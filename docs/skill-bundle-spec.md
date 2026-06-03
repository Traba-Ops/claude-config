# Claude Skills Spec

The Prometheus skills bundle is how the framework is delivered. It's a set of instructions that shape Claude's behavior: how to handle security, how to maintain project context, what stack to use, how to build toward a spec. This is the control surface.

## Delivery

The skills bundle lives in a **shared repo** on the `Traba-Ops` GitHub org ([`Traba-Ops/claude-config`](https://github.com/Traba-Ops/claude-config)). Operators clone it once and copy skills + rules into `~/.claude/`. A launchd job pulls updates automatically.

**What gets installed:**

| Type | What it does | Where it goes |
|------|-------------|---------------|
| **Constitution** | Role, principles, requirements gathering, security, development hygiene | `~/.claude/rules/traba-constitution.md` (always active) |
| **Project documentation** | README + SPEC.md, decision records | `~/.claude/rules/traba-spec.md` (always active) |
| **Workflows** | When to use dynamic workflows, dynamic vs saved, cost discipline | `~/.claude/rules/workflows.md` (always active) |
| **Teammate calibration** | Infer technical level (declared else inferred); dial handholding for Eng/Product/Data vs operators | `~/.claude/rules/teammate-calibration.md` (always active) |
| **Project setup** | Stack, toolchain, tier detection, scaffolding templates | `~/.claude/skills/project-setup/` (loaded when relevant) |
| **Deployment** | Railway, Google OAuth, Railway Postgres | `~/.claude/skills/deployment/` (loaded when relevant) |
| **Design system** | Traba UI tokens, components, layout patterns | `~/.claude/skills/traba-design/` (loaded when relevant) |
| **Authentication** | Google OAuth, session JWTs, domain restriction | `~/.claude/skills/authentication/` (loaded when relevant) |
| **BigQuery auth** | traba-auth proxy, OAuth flow, query patterns | `~/.claude/skills/bq-auth/` |
| **Continue from** | Pick up another background session's work in the current one | `~/.claude/skills/continue-from/` (loaded when relevant) |
| **Scheduling** | Pick + set up a Claude routine vs a macOS LaunchAgent for recurring tasks | `~/.claude/skills/scheduling/` (loaded when relevant) |
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

### Workflows (`workflows.md`)

When and how to use Claude Code's **dynamic workflows** (the script-orchestrates-many-subagents feature; [official docs](https://code.claude.com/docs/en/workflows)). Keeps the default posture conservative so operators don't burn tokens by accident.

- **Not the default:** normal conversation or a single subagent handles almost everything. Only start a workflow when the task truly needs many coordinated agents *and* the operator opted in (said "use a workflow"/"ultracode", invoked a saved workflow, or is in an `ultracode` session).
- **Dynamic vs saved ("static"):** one-off scripts Claude writes for a single task vs scripts saved as reusable `/commands` (parameterized via `args`) for processes you repeat. Save once you've run the same one-off more than a couple of times.
- **Cost discipline:** pilot on a slice first, mind the per-agent model, respect that runs count toward plan usage.
- Inherits the constitution's confirmation rules for workflows that mutate prod, post externally, or are hard to reverse.

### Teammate Calibration (`teammate-calibration.md`)

Everyone at Traba uses Prometheus scaffolding, not just non-technical operators. This rule calibrates *communication* (not judgment — the constitution's hierarchy holds for everyone).

- **Determine technical level:** use an explicit declaration (chat, `~/.claude` profile, or project CLAUDE.md) if one exists; otherwise infer from how the person works. Record a declared role so it isn't re-asked. Default to the operator posture until signals are clear.
- **Technical teammates (Eng, Product, Data):** assume git/deploy/secret fluency, show code and diffs directly, make technical calls without enumerating options, narrate less.
- **Operators (everyone else):** full plain-language posture — explain under-the-hood, suggest checkpoints, frame decisions as product choices, keep safety rails visible.

---

## Skills (Context-Dependent)

Skills load when Claude determines they're relevant. Each is a directory with a `SKILL.md` entry point and optional reference files.

### Project Setup

**Trigger:** Starting a new project, choosing technologies, initializing a repo.

Reads the repo to detect what tier the project is at:
- New project or local-only dependencies (SQLite, JSON files): default to simple, local stack.
- Railway Postgres/Railway dependencies already present: keep using them.

**Backend:** TypeScript + bun (runtime and package manager), oxlint, oxfmt, tsgo. Python + uv for scripts/data work.

**Frontend:** React + Vite. Styling via CSS custom properties from the design system (no MUI, no styled-components). TanStack React Query + React Context for state. React Router DOM for routing. Vitest for testing.

**Monorepo:** Every project uses bun workspaces with `apps/web/`, `apps/api/`, `packages/shared/`. Shared types via live `.ts` exports (no build step for internal packages).

Includes `.gitignore` and `.pre-commit-config.yaml` as reference files — Claude creates these during scaffolding.

### Deployment

**Trigger:** User wants to deploy, share, or make their app accessible to others.

Covers the full Tier 2 stack: Railway (single service: backend serves frontend as static files, auto-deploy on push), in-app Google OAuth for auth (see authentication skill), Railway Postgres for shared persistence, and Railway environment variables for secrets.

### Authentication

**Trigger:** Adding login to an app, or user asks about auth, sessions, or access control.

Covers Google OAuth with `@react-oauth/google` on the frontend and server-side verification via Google's userinfo API. The backend issues 7-day session JWTs using `jose`. Includes GCP setup gotchas (must use Console, not gcloud), Vite env var pitfalls, Hono middleware patterns, and a pre-deploy checklist.

### Design System

**Trigger:** User builds any UI mockup, prototype, or front-end code.

Applies the full Traba design system: colors (violet primary, midnight text), fonts (Poppins 400/500/600), layout patterns (154px sidebar, 52px topbar), and component styles (4px tag radius, 8px button radius, 12px card radius).

Single-file skill (~620 lines): critical rules at top, then all tokens, components, layouts, interactivity, data visualization, and content guidelines in build order.

### BigQuery Auth

**Trigger:** User needs to query BigQuery data, access Traba business data, or authenticate users for data access.

Covers the traba-auth proxy service: OAuth login flow, JWT storage, query execution via `POST /query`, Streamlit and TypeScript integration patterns, audit logging via `X-App-Name`, and parameterized query safety rules. Apps never hold GCP credentials — all BigQuery access proxies through traba-auth using the authenticated user's own Google OAuth tokens.

### Continue From

**Trigger:** User wants to pick up, resume, or take over what another background Claude session was working on — e.g. "continue from the session where I was doing X."

Bundles a small Node helper (`continue-from.mjs`) that reads local Claude Code state — `claude agents --json` for the session list, each session's `state.json` for its goal and last status, and the transcript for recent activity — and prints a clean snapshot so the current session can continue the other one's work. Matching scores a free-text hint against each session's goal/status, not just its name. One-way "read and continue"; it does not message or modify the other session. See [Running More Than One Claude](multi-session.md) for the broader multi-session story (background sessions, this skill, and agent teams).

### Scheduling

**Trigger:** User wants something to run on a schedule or repeatedly — "every morning", "each hour", "remind me daily", any recurring job.

Gives Claude the decision rule for *which* scheduling mechanism to use, then the how-to for setting it up. The rule: if each run needs Claude's judgment → a **Claude routine** (cloud, via `/schedule`, draws down subscription usage, hourly minimum); if it's deterministic code → a **macOS LaunchAgent** (local, free, down to 1-minute intervals). Frequency/cost and locality break ties toward LaunchAgent. Bundles `launchagent.template.plist` and the `launchctl` load/remove commands. (LaunchDaemons are intentionally omitted — they need root and aren't an operator self-serve tool.)

---

## What the Skills Do NOT Cover

Skills are guidance, not enforcement. Things that MUST be enforced outside of Claude:

| Risk | Hard Enforcement |
|------|------------------|
| Secret leakage | Gitleaks pre-commit + GitHub push protection |
| Exposed endpoints | In-app Google OAuth (authentication skill) |
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
