# Claude Skills Spec

The Prometheus skills bundle is how the framework is delivered. It's a set of instructions that shape Claude's behavior: how to handle security, how to maintain project context, what stack to use, how to build toward a spec. This is the control surface.

## Delivery

The skills bundle lives in a **shared repo** on the `Traba-Ops` GitHub org ([`Traba-Ops/claude-config`](https://github.com/Traba-Ops/claude-config)). Operators clone it once and copy skills + rules into `~/.claude/`. A launchd job pulls updates automatically.

**What gets installed:**

| Type | What it does | Where it goes |
|------|-------------|---------------|
| **Constitution** | Role, priority hierarchy, security, how-to-work, before-building, documentation, recurring tasks, dev hygiene | `~/.claude/rules/traba-constitution.md` (always active) |
| **Teammate calibration** | Infer technical level (declared else inferred); dial handholding for Eng/Product/Data vs operators | `~/.claude/rules/teammate-calibration.md` (always active) |
| **Project setup** | Stack, toolchain, tier detection, scaffolding templates | `~/.claude/skills/project-setup/` (loaded when relevant) |
| **Deployment** | Railway, Google OAuth, Railway Postgres | `~/.claude/skills/deployment/` (loaded when relevant) |
| **Design system** | Traba UI tokens, components, layout patterns | `~/.claude/skills/traba-design/` (loaded when relevant) |
| **Authentication** | Google OAuth, session JWTs, domain restriction | `~/.claude/skills/authentication/` (loaded when relevant) |
| **BigQuery auth** | traba-auth proxy, OAuth flow, query patterns | `~/.claude/skills/bq-auth/` |
| **Node backend auth** | GCP service account + route allow-list for `ops-prod.traba.tech` | `~/.claude/skills/ops-backend-auth/` (loaded when relevant) |
| **Pre-flight check** | Pre-deploy checklist: credentials, warehouse routing, auth coverage, data at rest | `~/.claude/skills/deploy-preflight-check/` (loaded when relevant) |
| **Park / Unpark** | Save a session to a durable snapshot, then resume a live session or revive a parked one | `~/.claude/skills/park/`, `~/.claude/skills/unpark/` (loaded when relevant) |
| **Recall** | Search prior session transcripts for what was said, decided, or built | `~/.claude/skills/recall/` (loaded when relevant, or `/recall`) |
| **Scheduling** | Pick + set up a Claude routine vs a macOS LaunchAgent for recurring tasks | `~/.claude/skills/scheduling/` (loaded when relevant) |
| **Teammate collab** | Coordinate with another operator's Claude over a shared Slack thread | `~/.claude/skills/teammate-collab/` (loaded when relevant) |
| **Data access** | Traba MCP, BigQuery RBAC, ontology (coming soon) | `~/.claude/skills/data-access/` |
| **Caveman output mode** | Compressed answers — no filler, no hedging, technical substance intact | `~/.claude/skills/caveman/` + `~/.claude/hooks/caveman-always-on.sh`, on by default at `lite` (see below) |

**How operators get it:**

```bash
curl -fsSL https://raw.githubusercontent.com/Traba-Ops/claude-config/main/install.sh | sh
```

The installer clones the repo, copies skills + rules into `~/.claude/`, and sets up git tracking. The operator then sets up auto-updates in Claude Code:

> "Set up a launchd job that runs `cd ~/.claude && git pull` every hour between 9 AM and 9 PM"

**How updates propagate:** Engineers commit to the repo. Each operator's launchd job runs `git pull` hourly during working hours, pulling updated skills and rules automatically. `git pull` only moves files — it never runs `install.sh`, so anything that needs installer-side setup (a flag file, a `settings.json` hook registration) stays inert on existing installs until the operator re-runs the curl installer. Ship setup-dependent features with a note telling existing operators to re-run it.

**Caveman output mode (on by default, `lite`):** the installer writes `lite` to `~/.claude/.caveman-always` and registers `hooks/caveman-always-on.sh` as a `SessionStart` hook in `~/.claude/settings.json`. The hook injects the caveman ruleset at the recorded intensity every session. Both steps are idempotent — an operator who already has a flag file or a registered hook keeps their setting on re-install.

At `lite` the change is tone only: no filler, no hedging, no "Sure! I'd be happy to" — full sentences and articles stay. Code, commits, PRs, security warnings, and destructive-action confirmations are never compressed. Switches:

| Want | Say / do |
|---|---|
| Off for this session | "stop caveman" / "normal mode" |
| Off for good | delete `~/.claude/.caveman-always` |
| Shorter still | `/caveman full` (or `ultra`), or write that word into the flag file |
| Full reference | `/caveman-help` |

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
- **Before building:** Lightweight requirements gathering (problem, user, outcome, data, scope); invoke project-setup and default to the prescribed stack.
- **Documentation:** Maintain README + SPEC + decision records as a byproduct of building, updated inline. The field-by-field structure lives in the project-setup skill ("The Living Documents"), not always-on.
- **Recurring tasks:** Script vs LLM-run by frequency.
- **Security:** Never hardcode secrets, never commit .env, no stack traces in production, Traba-Ops org only, Traba Railway team only, no deploy without auth.
- **Development hygiene:** Checkpoint on request, commit messages explain what and why.

The constitution leads with the priority hierarchy and security (highest-priority rules first, where adherence is best), then the behavioral principles, then the conditional/pointer sections.

> **A former always-active rule now loads on-demand.** Project-documentation detail moved into the **project-setup skill** (it only matters when building) — it governed a situation most sessions never hit, so it doesn't earn a slot in every session's context. See [authoring-rules.md](authoring-rules.md) for the standard that decides what stays always-on.

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

**Monorepo:** Every project uses bun workspaces with `apps/web/`, `apps/api/`, `apps/shared/`. Shared types via live `.ts` exports (no build step for internal packages).

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

Covers the traba-auth proxy service: OAuth login flow, JWT storage, query execution via `POST /query`, Streamlit and TypeScript integration patterns, audit logging via `X-App-Name`, and parameterized query safety rules. All BigQuery access proxies through traba-auth using the authenticated user's own Google OAuth tokens — apps hold no BigQuery credentials.

### Node Backend Auth

**Trigger:** An app needs to call Traba's node backend (`ops-prod.traba.tech` `@OpsAuth()` endpoints) — live ops data or an ops action — rather than query BigQuery.

The counterpart to bq-auth: bq-auth is the read path for analytics under the user's own OAuth; this is the machine path for an app that calls backend endpoints programmatically. Covers the two-step provisioning (a GCP service account in `traba-ops`, which needs zero IAM roles, plus a per-route entry in the default-deny `service_account_scopes` Statsig config), minting the ID token with `google-auth-library`, verifying a route against `origin/main` before requesting it, and the failure modes — chiefly that a service account classifies as `EmployeeRole.Internal` and short-circuits every route decorator, so a 403 is always a missing allow-list entry, and that a scope change is two edits (`defaultValue` plus the dev-tier rule, which replaces rather than merges).

### Pre-Flight Check

**Trigger:** An app is about to be deployed or redeployed, the user asks for a compliance audit of the project, or a project is promoting to Tier 2.

A runnable pre-deploy checklist built around four invariants — secrets never leave the perimeter, data access is always per-user, nothing is reachable without auth, infrastructure stays inside Traba's perimeter. An app-profile preflight (warehouse? node backend? worker comms? database? Vite?) decides which checks apply; each check is tagged **[BLOCKER]** (fix before deploying) or **[advisory]** (report with a recommended fix). Ends with an unauthenticated post-deploy probe of the enumerated data endpoints, a plain-language verdict for the operator, and a compact Slack scorecard that travels with the bq-auth allowlist request. The constitution's no-deploy-without-auth gate and the eng runbook's Step 1 both point here.

### Park / Unpark

**Trigger:** User wants to save a session for later ("park this", "save this context"), or to pick up / resume / revive prior work — e.g. "continue from the session where I was doing X", "revive the parked session about Y".

Two complementary skills for context handoff across sessions:

- **Park** writes a durable, human-readable snapshot of the current (or a named background) session — goal, key decisions, where it left off, next steps — into a directory the user chooses via `CLAUDE_PARK_DIR` (an Obsidian vault folder, a synced dir, etc.; default `~/.claude-park`). This outlives the ~30-day transcript cleanup, syncs across machines, and is searchable by topic.
- **Unpark** bundles a small Node helper (`unpark.mjs`) that reads local Claude Code state — `claude agents --json` for live sessions, each session's `state.json` for goal/status, and the transcript for recent activity — **and** scans the parked snapshots. It ranks both sources against a free-text hint and prints a clean context block so the current session can **resume a live session or revive a dead one** from its parked note. One-way "read and continue"; it does not message or modify the other session.

Replaces the earlier live-only `continue-from` skill. See [Running More Than One Claude](multi-session.md) for the broader multi-session story (background sessions, these skills, and agent teams).

### Recall

**Trigger:** `/recall`, or the user asks "what did we say about X" / "we already discussed this" / another session worked on something and its reasoning isn't in the project docs or git history.

Searches Claude Code session transcripts (`~/.claude/projects/`) for prior decisions and findings, delegated to a subagent so large transcripts don't flood the main conversation. Carries the traps that make naive transcript search fail: excluding the current session (whose restated question otherwise matches itself), reading assistant messages rather than user prompts for the actual findings, and parsing the JSONL structure instead of grepping raw lines. Complements park/unpark: recall answers questions about prior sessions; unpark resumes or revives them.

### Scheduling

**Trigger:** User wants something to run on a schedule or repeatedly — "every morning", "each hour", "remind me daily", any recurring job.

Gives Claude the decision rule for *which* scheduling mechanism to use, then the how-to for setting it up. The rule: if each run needs Claude's judgment → a **Claude routine** (cloud, via `/schedule`, draws down subscription usage, hourly minimum); if it's deterministic code → a **macOS LaunchAgent** (local, free, down to 1-minute intervals). Frequency/cost and locality break ties toward LaunchAgent. Bundles `launchagent.template.plist` and the `launchctl` load/remove commands. (LaunchDaemons are intentionally omitted — they need root and aren't an operator self-serve tool.)

### Teammate Collab

**Trigger:** Two operators working the same project at once — the operator says they're co-working, names another teammate on shared work, or shares a Slack thread URL to monitor.

The SOP for two Claudes coordinating through a shared Slack thread (read+write via the Slack MCP), written so the *humans* can follow it: thread setup and first-post lineup, human-readable posting style, decisions-before-doing with hold windows, claim-before-cut to avoid races, the wait protocol (ask the operator before polling), durable handoff to Linear/PR, and what never to post (PII, secrets, raw stack traces). The constitution keeps a one-paragraph pointer always-on; this skill carries the full procedure and loads only when co-working actually starts.

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
