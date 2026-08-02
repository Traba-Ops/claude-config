# Prescriptive Stack

The Prometheus stack is intentionally opinionated. Claude skills enforce these choices so users don't have to make them. Every component was chosen for the same reasons: cheap, hands-off, and accessible to non-engineers.

## Decision Matrix

| Layer | Choice | Runner-up | Why |
|-------|--------|-----------|-----|
| Language | TypeScript (default) | Python (only when needed) | TypeScript for everything unless the use case requires a Python-specific library (ML, data science, wrapping Python-only APIs). |
| Backend framework (TS) | Hono | Express, NestJS | Minimal, bun-native, Express-like API. NestJS is overkill for internal tools (heavy DI, modules, decorators). |
| Backend framework (Python) | FastAPI | Flask, Django | Typed, async, auto-generated OpenAPI docs. Only relevant when Python is chosen for the project. |
| Toolchain (TS) | bun + oxlint + oxfmt + tsgo | npm/yarn + eslint + prettier + tsc | Aligns with `traba-server-node` tooling. Fast, minimal config. |
| Toolchain (Python) | uv | pip + virtualenv | Single tool replaces pip, pip-tools, virtualenv, and pyenv. |
| Frontend framework | React + Vite | Next.js | Vite is faster, simpler, and already used in Traba's core frontend. No SSR needed for internal tools. |
| Styling | Tailwind CSS v4 + shadcn/ui | MUI, raw CSS | Design tokens mapped into Tailwind's `@theme`. shadcn/ui (Radix primitives) for interactive components (tooltips, sheets, selects). Co-located utility classes, tree-shakeable, no monolithic stylesheets. |
| State management | TanStack React Query + Context | Redux | Query handles server state, Context handles app state. No boilerplate. Matches core Traba frontend. |
| Routing | React Router DOM | TanStack Router | Mature, matches core Traba frontend. |
| Testing | Vitest | Jest | Native Vite integration, faster. Same API as Jest. |
| Monorepo | bun workspaces | pnpm + Turborepo | One tool. Operator tools are small — Turborepo/Nx add complexity for no benefit at this scale. |
| Database | Railway Postgres | Supabase, Neon | Railway databases are regular services billed by actual compute — a small Postgres costs ~$1/mo. No per-project VM surcharge. Prisma handles all data access, so Supabase's REST API layer adds cost without benefit. |
| ORM | Prisma | Drizzle | Schema-first, type-safe client generation. Works with SQLite (local) and Postgres (Railway). Migration tooling built in. |
| Static HTML one-pagers | Google Drive | Vercel, Netlify, GitHub Pages | Standalone HTML files (proposals, reports, dashboard mockups) get shared via Drive, not hosted. Drive provides Workspace-gated access control for free, keeps confidential content off public URLs, and avoids ops hosting Traba content on personal accounts. |
| Deploy (full apps) | Railway (backend serves frontend) | Render | Single service: backend builds + serves frontend as static files. Avoids Nixpacks monorepo confusion. Use `railway.json` for explicit build/start. Even frontend-only apps use Railway with a minimal static server. |
| Auth (shared apps) | In-app Google OAuth | Cloudflare Zero Trust | Unlimited users, no platform lock-in, full control over sessions and routes. Zero Trust hit the 50-seat free tier cap. |
| Secrets | Railway environment variables | Infisical, Doppler | Simplest option — no extra tooling. Railway dashboard is accessible to operators. Secrets stay in the deployment platform where they're used. |
| Version control | GitHub | — | Existing Traba infrastructure. |

---

## Toolchain

Standardized tooling per language. Using the same tools as the core codebase makes promotion easier and keeps Claude's output consistent across projects.

### TypeScript

| Tool | Purpose | Why |
|------|---------|-----|
| **bun** | Package manager + runtime | Fast, zero-config, handles both package management and script execution. Avoids npm/yarn version confusion. |
| **oxlint** | Linter | Fast, zero-config by default. Aligns with `traba-server-node` which uses oxlint for type-aware linting. |
| **oxfmt** | Formatter | Pairs with oxlint. Consistent formatting without Prettier config debates. |
| **tsgo** | Type checking | Fast incremental type checking. Used in `traba-server-node` alongside tsc. |

### Python

| Tool | Purpose | Why |
|------|---------|-----|
| **uv** | Package manager + virtualenv | Replaces pip, pip-tools, virtualenv, and pyenv. Single tool, extremely fast, handles Python version management. |

### Project scaffolding

The `.gitignore` and `.pre-commit-config.yaml` are reference files in the project-setup skill. When Claude scaffolds a new project, it creates these and sets up the appropriate toolchain.

The project-setup skill handles this so new projects get the right toolchain automatically.

---

## Language: TypeScript by Default

**TypeScript for everything unless the use case requires a Python-specific library.** Both languages have excellent AI-generated code quality, but TypeScript is the default because the entire stack (bun, Hono, React, Vite, Prisma) is TypeScript. Using one language across frontend, backend, and shared types eliminates context-switching and lets `apps/shared/` work seamlessly.

**When to use Python:** Only when the project requires a library that doesn't exist in the TypeScript ecosystem — primarily ML/data science (pandas, numpy, scikit-learn, torch) or wrapping a Python-only API. If you're unsure, use TypeScript.

---

## Backend Framework: Hono (TS) / FastAPI (Python)

**Why Hono:** Minimal, bun-native, Express-like API. A Hono backend for a typical internal tool is a single file with a few routes. It has built-in `serveStatic` for bun, which is exactly what the Railway deployment pattern needs (backend serves frontend).

**Why not NestJS:** Traba's production backend (`traba-server-node`) uses NestJS, but Nest is designed for large teams and complex domains — dependency injection, modules, guards, interceptors, decorators. For a 3-5 endpoint internal tool, Nest generates 10 files of boilerplate for something that should be 1. Prometheus apps never promote by copying code (they promote by spec extraction), so matching the production framework doesn't save work.

**Why not Express:** Legacy API design, no native bun support (needs adapter), no built-in TypeScript types. Hono is the modern equivalent with a nearly identical API surface.

**Python equivalent — FastAPI:** When Python is chosen for a project, FastAPI is the framework. Typed (Pydantic models), async by default, auto-generated OpenAPI docs. Flask is simpler but untyped; Django is overkill for the same reasons as NestJS.

---

## Frontend: React + Vite

**Why React:** Matches Traba's core frontend (`~/workspace/traba`). Largest ecosystem for AI-generated code quality. Operators can reference existing Traba patterns.

**Why Vite over Next.js:** Internal tools don't need SSR, server components, or file-based routing. Vite is faster to start, simpler to configure, and already used in Traba's core frontend (business-app, ops-console, aperture-vite all use Vite).

**Styling — Tailwind CSS + shadcn/ui:** The Traba design system tokens (colors, typography, spacing) are mapped into Tailwind's `@theme` block so all values are available as utility classes (e.g., `text-midnight-100`, `bg-violet-10`, `border-gray-20`). This replaces raw CSS custom properties with co-located utility classes — styling is visible in the JSX, not split across a growing stylesheet.

For interactive components (tooltips, slide-out panels, selects, dialogs), use shadcn/ui — copy-paste Radix primitives that render unstyled DOM, styled with Tailwind. Install components as needed via `bunx shadcn@latest add <component>`. This gives accessible, tested implementations without the bundle weight or opinionated styling of MUI/Ant Design.

**Setup:** Add `@tailwindcss/vite` to the Vite config, create `app.css` with `@import "tailwindcss"` and map all design tokens in a `@theme` block. The design system skill has the full token-to-theme mapping. Initialize shadcn with `bunx shadcn@latest init -t vite -b radix -p nova -y` (requires `@/*` path alias in tsconfig).

**State management:** TanStack React Query handles data fetching and caching. React Context handles app-level state (user, auth, preferences). This matches the core Traba frontend and avoids Redux boilerplate.

**Testing:** Vitest runs natively with Vite — same config, same transforms. API-compatible with Jest (same `describe`/`it`/`expect`), so patterns transfer from the core codebase.

---

## Monorepo: bun Workspaces

**Every project is a monorepo.** Even if it starts as backend-only or frontend-only. The structure is consistent and adding the other side later is just creating a directory.

```
my-project/
  apps/
    web/          # React + Vite (built and served by api/)
    api/          # Hono backend → Railway
    shared/       # Shared types, schemas, constants
  package.json    # bun workspace root
```

**Why bun workspaces over pnpm + Turborepo:** One tool. Operator tools are small monorepos (2-3 packages). pnpm has more mature workspace support, but the gaps (no `--filter` for `bun add`, newer isolated install mode) don't affect small projects where Claude handles all commands. Turborepo/Nx add configuration overhead for no benefit at this scale.

**Why always monorepo:** Consistent structure across all Prometheus projects. Claude scaffolds the same layout every time. If a backend-only project needs a frontend later, the structure is already there.

**Type sharing:** Export `.ts` files directly from `apps/shared/` (live types). No build step for internal packages — the consuming app's bundler handles transpilation. Use `workspace:*` protocol for internal dependencies.

**Deployment from a monorepo:** Everything deploys to Railway as a single service. The backend builds the frontend and serves it as static files. This avoids Nixpacks auto-detection confusion in monorepos (Railway can't tell which app to build when it sees multiple `package.json` files). A `railway.json` at the repo root makes the build/start commands explicit. Even frontend-only projects use Railway with a minimal static file server.

---

## Database: Railway Postgres

**Why Railway Postgres over Supabase:**
Two reasons — cost and operational simplicity.

*Cost:* Supabase charges ~$10/mo per project for a dedicated Postgres VM (Micro compute), with only one covered by the Pro plan's $10 compute credit. At 5-10 Prometheus apps, that's $40-90/mo in database compute alone on top of the $25/mo base. Railway treats databases as regular services billed by actual resource consumption (CPU cycles, memory, volume storage) — a small idle Postgres costs ~$0.50-1.00/mo, and multiple databases share the same credit pool. The Pro plan's $20 usage credit covers 10+ small databases with room to spare.

*Operational simplicity:* We already use Railway for hosting. Adding a database is one click in the same project — no onboarding operators to a separate service, no separate account management, no extra access grants. Supabase would be another service to manage, another set of credentials to provision, and another thing to revoke during offboarding.

Supabase's value proposition — auto-generated REST APIs, dashboard UI, built-in auth — doesn't apply here. Prometheus apps already use Prisma for type-safe data access and Hono for the API layer. Supabase's abstraction is redundant, and the per-project cost penalty compounds as we scale.

**Setup:**
Add a Postgres database directly from the Railway project canvas (`Cmd+K` or `+ New` → database template). Railway exposes connection variables (`DATABASE_URL`, `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`) on the database service. Reference them from your app service using Railway's variable syntax (e.g., `${{Postgres.DATABASE_URL}}`). Many libraries (including Prisma) auto-detect `DATABASE_URL`. Services communicate over private networking — low latency, no traffic leaves Railway's network.

**Networking — disable TCP proxy:**
The Railway Postgres template enables TCP proxy by default, which exposes the database to the public internet. Since Prometheus apps connect from within the same Railway project over private networking, **disable the TCP proxy** after setup (Service → Settings → Networking → remove the TCP proxy). With TCP proxy disabled, the database is only reachable over Railway's internal network, and `DATABASE_URL` does not need to be sealed — the password is never exposed outside Railway's private network.

**Pricing:**
- Databases use the same usage-based billing as app services
- CPU: $20/vCPU/month, RAM: $10/GB/month, Volume storage: $0.15/GB/month
- A small Postgres instance typically costs $0.50-1.00/month
- All usage draws from the plan's included credit ($5 Hobby, $20 Pro)
- [Railway pricing](https://railway.com/pricing)

**Persistence:** Databases come with an attached volume — data survives deployments and restarts.

**Important — databases are unmanaged:**
Railway provides the infrastructure, but you are responsible for backups, performance tuning, security, and monitoring. For Tier 2 internal tools with disposable prototype data, this is fine. For apps that accumulate irreplaceable data, set up automated backups (e.g., `pg_dump` on a cron schedule to cloud storage).

**References:**
- [Railway database docs](https://docs.railway.com/databases)
- [Railway PostgreSQL](https://docs.railway.com/databases/postgresql)

---

## ORM: Prisma

When a project needs structured database access beyond simple queries, use Prisma. It generates a fully type-safe client from the schema file — queries get autocomplete and compile-time type checking with zero manual typing. Works across both tiers: SQLite for local prototypes, Postgres on Railway for deployed apps. Schema is the source of truth for both the database and TypeScript types.

**Runner-up — Drizzle:** Lighter weight, closer to raw SQL. Worth considering if bundle size or query performance becomes a bottleneck. Prisma's schema-first workflow is more approachable for AI-generated code.

---

## Static HTML One-Pagers: Google Drive

**The case:** Ops increasingly produces standalone HTML pages — GTM proposals, internal reports, dashboard mockups, one-off visualizations. These have no backend, no auth, no persistence — just a single `.html` file that runs entirely in the browser.

**The default has been to host them somewhere** (Vercel, Netlify, GitHub Pages, occasionally a personal account). That created two problems Sumeet flagged in #claudecodestuff:

1. **Personal hosting accounts.** Operators were hosting on personal Vercel accounts because there was no sanctioned alternative. That content leaves with the person and is invisible to Traba.
2. **No visibility or access control.** A public Vercel URL has no built-in auth. Confidential-ish material — pricing, customer names, headcount, strategy — was sitting at guessable public URLs.

**The fix: don't host one-pagers — share them via Google Drive.**

- **Access control is free.** Drive enforces Google Workspace permissions. Restrict to `@traba.work`, named individuals, or groups. Revocable, auditable, and inside the perimeter we already manage.
- **No public URLs.** Drive links are gated; there's no path from "guessed URL" to "read the file."
- **No personal-account drift.** Files live in the Traba Workspace, not on someone's individual Vercel/Netlify.
- **Zero deploy step.** Upload, share, done. No build, no env vars, no DNS.

**How it works:** Upload the `.html` to Drive → set sharing scope → share the link. Recipients click **Open with → Browser**, or **Download** the file and open it in Chrome. Either path runs the file locally.

**When this does not apply:** If the page calls a Traba API, needs auth, or persists data, it's not a static one-pager — it's a real app and belongs on Railway. See the deployment skill for the routing rule.

**Why not Vercel team plan:** Vercel team would solve the personal-account problem but not the access-control problem — Vercel deployments are public by default, and putting auth in front of every one-pager (Cloudflare Access, Vercel Password Protection) reintroduces the deploy step we're trying to avoid. Drive is the simpler answer for the static case; Railway with in-app OAuth is the answer when the app actually needs to do something.

---

## Deployment: Railway

**Why Railway:**
Railway has the best developer experience for going from zero to deployed. Template marketplace (650+ templates), GitHub integration with auto-deploy on push, and Nixpacks auto-detection that builds without a Dockerfile. For non-technical users, the template marketplace is the killer feature — no CLI or config files needed.

**Pricing:**
- No permanent free tier. 30-day trial with $5 credit.
- Hobby: $5/mo (includes $5 usage credit — covers most small projects entirely)
- Pro: $20/mo (includes $20 usage credit, adds team collaboration)
- Enterprise: $2,000/mo minimum (SSO, audit logs, HIPAA)
- [Railway pricing](https://railway.com/pricing)

**SSO consideration:** Google Workspace SSO for team access to the Railway dashboard is Enterprise-only ($2,000/mo). Not worth it at this stage. Individual Google OAuth on deployed apps works on any plan via environment variables.

**Limitations to know about:**
- No permanent free tier — apps die after trial
- Nixpacks auto-detection breaks on monorepos — always use `railway.json` with explicit build/start commands
- Built-in env var management is sufficient for current scale — consider Infisical if audit logging becomes a requirement
- Scaling ceiling for sustained high load (fine for internal tools)
- Some reliability concerns — January 2026 multi-day GitHub auth failures ([Railway incident report](https://blog.railway.com/p/incident-report-january-26-2026))

**Alternative considered — Render:** More production-ready with predictable billing and built-in background workers. Better for apps that graduate to sustained production use. Consider Render if Railway's reliability becomes a problem.

**References:**
- [Railway vs Render comparison (Northflank)](https://northflank.com/blog/railway-vs-render)
- [Railway features](https://railway.com/features)
- [Railway SOC 2 compliance](https://docs.railway.com/enterprise/compliance)

---

## Auth: In-App Google OAuth

**Why in-app Google OAuth over infrastructure-level auth gating:**
Unlimited users, no platform lock-in, full control over session duration and per-route authorization. The auth code is minimal (~80 lines of Hono middleware) and Claude scaffolds it from the reference implementation in the authentication skill.

**How it works:**
1. Frontend uses `@react-oauth/google` for the Google login popup
2. Backend verifies the Google access token via the userinfo API
3. Backend checks `hd === "traba.work"` (domain restriction, server-side only)
4. Backend issues a 7-day session JWT signed with `jose`
5. Frontend stores the JWT in localStorage, sends as `Authorization: Bearer` header
6. All `/api/*` routes require the `requireAuth` middleware

See the [authentication skill](../skills/authentication/SKILL.md) for the full implementation guide and reference code.

### Alternatives considered

| Option | Pros | Cons | Status |
|--------|------|------|--------|
| **In-app Google OAuth** | Free, unlimited users, works on any host, full control over sessions/routes | ~80 lines of auth code per app | **Active — preferred** |
| **Cloudflare Zero Trust** | Zero code, sits in front of the app as a reverse proxy | Hard 50-seat cap on free tier, then $7/user/month | **Retired** — hit the seat cap |
| **GCP Identity-Aware Proxy (IAP)** | Free, unlimited users, zero code, centralized access control in GCP console | Only works on GCP compute (Cloud Run, App Engine, GKE) — not compatible with Railway | **Not viable** — would require moving off Railway |

### Why not GCP IAP?

IAP is a reverse proxy that sits in front of GCP compute services and forces Google authentication before requests reach the app — conceptually the same pattern as Cloudflare Zero Trust but GCP-native. It's free with no per-user cap, which solves the Zero Trust pricing problem.

However, IAP only works on GCP compute. Prometheus deploys to Railway for operational simplicity (single-service deploys, Nixpacks auto-detection, one-click Postgres, accessible to non-engineers). Adopting IAP would mean migrating all Prometheus hosting to Cloud Run, setting up GCP load balancers, and switching Cloudflare DNS to DNS-only mode to avoid proxy conflicts (Cloudflare's orange-cloud proxy mode can cause redirect loops with IAP). That infrastructure migration would cost far more than maintaining the in-app OAuth pattern.

If Prometheus hosting ever moves to GCP compute, IAP becomes worth revisiting — it would eliminate all per-app auth code. Until then, in-app OAuth provides equivalent security with no platform lock-in.

### Cloudflare DNS (still active)

Cloudflare is still used for DNS — custom domains for deployed apps (`appname.traba.work`) use Railway's one-click Cloudflare integration to create DNS records. This is just DNS resolution, not Zero Trust — no authentication happens at the Cloudflare layer.

**References:**
- [Google OAuth for web apps](https://developers.google.com/identity/protocols/oauth2)
- [GCP IAP overview](https://cloud.google.com/iap/docs/concepts-overview)
- [Cloudflare Zero Trust pricing](https://www.cloudflare.com/plans/zero-trust-services/)

---

## Secrets: Railway Environment Variables

**Why Railway env vars over a dedicated secrets manager (Infisical, Doppler):**
Simplest option for the scale we're at. Railway's dashboard is accessible to operators, secrets stay in the deployment platform where they're used, and there's no extra tooling to install or manage. Railway env vars are encrypted at rest and injected at runtime.

**How secrets flow in Prometheus:**

```
.env (local development, gitignored)
Railway Variables (production, set in dashboard)
  └── injected as process.env.* at runtime
```

1. Operator stores secrets in `.env` locally for development
2. For deployed apps, add secrets in Railway project → Variables
3. App reads them via `process.env.SECRET_NAME` or `Bun.env.SECRET_NAME`

**When to consider a dedicated secrets manager:** If Prometheus apps start sharing secrets across multiple services, or if audit logging of secret access becomes a requirement, consider migrating to Infisical (already in use at Traba for the core product).

---

## Version Control: GitHub

**Org strategy: `traba-ops` under the Traba enterprise account.**

- `trabapro` = primary production codebase
- `traba-ops` = experimentation and shareable Prometheus apps
- Both orgs are under the same GitHub enterprise account, so billing is unified
- $21/month per seat (enterprise pricing applies across orgs)
- Projects can be transferred from `traba-ops` to `trabapro` when promoted to Tier 1
- 2FA required on the org

**Why a separate org:** Clean boundary between production code and experimental repos. Operators get broad write access to `traba-ops` without any risk to production repos. Discoverability across orgs is solved through an automated commit feed from `traba-ops` repos.

**Monorepo vs many repos:** Many repos. Internal tools have independent lifecycles, owners, and deployment pipelines. A monorepo adds tooling complexity (Nx/Turborepo) that citizen developers don't need.

**References:**
- [GitHub pricing](https://github.com/pricing)
- [GitHub best practices for orgs (GitHub Blog)](https://github.blog/enterprise-software/devops/best-practices-for-organizations-and-teams-using-github-enterprise-cloud/)
