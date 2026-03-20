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
| Styling | CSS custom properties (design system) | MUI, Tailwind | Design system tokens applied directly. No framework overhead, guaranteed Traba visual consistency. |
| State management | TanStack React Query + Context | Redux | Query handles server state, Context handles app state. No boilerplate. Matches core Traba frontend. |
| Routing | React Router DOM | TanStack Router | Mature, matches core Traba frontend. |
| Testing | Vitest | Jest | Native Vite integration, faster. Same API as Jest. |
| Monorepo | bun workspaces | pnpm + Turborepo | One tool. Operator tools are small — Turborepo/Nx add complexity for no benefit at this scale. |
| Database | Supabase | Neon | Supabase's abstraction layer is its strength here — dashboard UI, auto-generated REST APIs, built-in auth. Non-engineers can manage data without SQL. |
| ORM | Prisma | Drizzle | Schema-first, type-safe client generation. Works with SQLite (local) and Postgres (Supabase). Migration tooling built in. |
| Deploy | Railway (backend serves frontend) | Render | Single service: backend builds + serves frontend as static files. Avoids Nixpacks monorepo confusion. Use `railway.json` for explicit build/start. Even frontend-only apps use Railway with a minimal static server. |
| Auth (shared apps) | Cloudflare Zero Trust | Google OAuth | Free for up to 50 users. Email-domain restriction (`@traba.work`) with magic link OTP. No IdP setup required. |
| Secrets | Infisical | Doppler | Already in use at Traba. Dashboard UI for non-technical users, RBAC, audit logs, `infisical run` for deployment. |
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

**TypeScript for everything unless the use case requires a Python-specific library.** Both languages have excellent AI-generated code quality, but TypeScript is the default because the entire stack (bun, Hono, React, Vite, Prisma) is TypeScript. Using one language across frontend, backend, and shared types eliminates context-switching and lets `packages/shared/` work seamlessly.

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

**Why no component library (MUI, Ant Design, etc.):** The Traba design system skill defines all tokens, components, and patterns via CSS custom properties. MUI's opinionated styling fights the design system and adds ~300KB of bundle weight. Operators should use the design system tokens directly.

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
  packages/
    shared/       # Shared types, schemas, constants
  package.json    # bun workspace root
```

**Why bun workspaces over pnpm + Turborepo:** One tool. Operator tools are small monorepos (2-3 packages). pnpm has more mature workspace support, but the gaps (no `--filter` for `bun add`, newer isolated install mode) don't affect small projects where Claude handles all commands. Turborepo/Nx add configuration overhead for no benefit at this scale.

**Why always monorepo:** Consistent structure across all Prometheus projects. Claude scaffolds the same layout every time. If a backend-only project needs a frontend later, the structure is already there.

**Type sharing:** Export `.ts` files directly from `packages/shared/` (live types). No build step for internal packages — the consuming app's bundler handles transpilation. Use `workspace:*` protocol for internal dependencies.

**Deployment from a monorepo:** Everything deploys to Railway as a single service. The backend builds the frontend and serves it as static files. This avoids Nixpacks auto-detection confusion in monorepos (Railway can't tell which app to build when it sees multiple `package.json` files). A `railway.json` at the repo root makes the build/start commands explicit. Even frontend-only projects use Railway with a minimal static file server.

---

## Database: Supabase

**Why Supabase over Neon:**
Neon is raw Postgres — no auth, no storage, no API layer, no visual dashboard for non-engineers. Supabase provides the full stack a citizen developer needs: database + auth + file storage + auto-generated REST APIs + a table editor UI. The abstraction layer that engineers find annoying is exactly what makes it accessible.

**Pricing:**
- Free: 2 projects, 500 MB database, 50K monthly active users, auto-pauses after 7 days of inactivity
- Pro ($25/mo): 8 GB database, 100K MAUs, spend cap enabled by default
- [Supabase pricing](https://supabase.com/pricing)

**RLS is not required for Prometheus tools:**
The widely-cited RLS risk (83% of exposed Supabase databases involve RLS misconfigurations) applies to public-facing apps where anyone can hit the Supabase REST API directly. Prometheus tools are internal-only, sitting behind Cloudflare Zero Trust Access which restricts entry to `@traba.work` emails. Access control happens at the network layer before any request reaches the app or database. Server-side access control in the application is sufficient — RLS adds complexity for no meaningful security benefit in this threat model.

**References:**
- [Supabase Edge Functions limits](https://supabase.com/docs/guides/functions/limits) (2-second CPU time limit, 20 MB bundle)
- [Supabase vs Neon comparison (Bytebase)](https://www.bytebase.com/blog/neon-vs-supabase/)

---

## ORM: Prisma

When a project needs structured database access beyond simple queries, use Prisma. It generates a fully type-safe client from the schema file — queries get autocomplete and compile-time type checking with zero manual typing. Works across both tiers: SQLite for local prototypes, Postgres for Supabase-backed deployed apps. Schema is the source of truth for both the database and TypeScript types.

**Runner-up — Drizzle:** Lighter weight, closer to raw SQL. Worth considering if bundle size or query performance becomes a bottleneck. Prisma's schema-first workflow is more approachable for AI-generated code.

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
- Built-in env var management is basic — use Infisical for anything sensitive
- Scaling ceiling for sustained high load (fine for internal tools)
- Some reliability concerns — January 2026 multi-day GitHub auth failures ([Railway incident report](https://blog.railway.com/p/incident-report-january-26-2026))

**Alternative considered — Render:** More production-ready with predictable billing and built-in background workers. Better for apps that graduate to sustained production use. Consider Render if Railway's reliability becomes a problem.

**References:**
- [Railway vs Render comparison (Northflank)](https://northflank.com/blog/railway-vs-render)
- [Railway features](https://railway.com/features)
- [Railway SOC 2 compliance](https://docs.railway.com/enterprise/compliance)

---

## Auth: Cloudflare Zero Trust (Access)

**Why Cloudflare Access over roll-your-own OAuth:**
Zero setup complexity for the user. Sits in front of the app as a reverse proxy — when someone hits the URL, they authenticate before the request reaches the origin. Built-in One-Time PIN provider means no external IdP setup required.

**How it works for Traba:**
1. Deploy app to Railway
2. Create an Access Application pointing to the app's domain
3. Add policy: Include = "Emails ending in @traba.work", Login method = One-time PIN
4. Users visit the app, enter their `@traba.work` email, get a 6-digit code, and they're in

**Pricing:**
- Free: Up to 50 users (covers Traba's needs)
- Pay-as-you-go: $7/user/month for advanced features
- [Zero Trust pricing](https://www.cloudflare.com/plans/zero-trust-services/)

**Best practices:**
- Use a dedicated subdomain for internal tools (e.g., `tools.traba.work`)
- Define an "All Traba Employees" Access Group (email domain = @traba.work) and reuse across apps
- Set session duration to 7 days for dashboards, 1-4 hours for sensitive tools
- Start with OTP, add Google Workspace SSO later if needed — Access supports both simultaneously

**Automation:** Cloudflare has a Terraform provider for defining Access apps and policies as code. Worth doing once the number of protected apps exceeds 5-10 to prevent config drift.

**References:**
- [Cloudflare Access policies](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)
- [One-time PIN setup](https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/)
- [Terraform automation](https://developers.cloudflare.com/cloudflare-one/api-terraform/)

---

## Secrets: Infisical

**Why Infisical:**
Already in use at Traba. Dashboard UI that non-technical users can navigate (view secrets per their permissions), RBAC with per-project and per-environment isolation, and `infisical run` for injecting secrets at runtime without storing them in the deployment platform.

**Pricing:**
- Free: Core secrets management, limited users/projects
- Pro (~$8-9/user/mo): RBAC, audit logs, more integrations
- Enterprise: SSO/SAML, SOC 2, HIPAA
- [Infisical pricing](https://infisical.com/pricing)

**How secrets flow in Prometheus:**

```
Infisical (source of truth)
  ├── infisical run -- bun run start     (Railway: runtime injection)
  └── Secret Sync → Supabase Edge Funcs  (automatic push)
```

Non-engineers never touch secrets directly. The flow:
1. Engineer creates an Infisical project for the app
2. Engineer adds required secrets (API keys, DB URLs)
3. App's start command uses `infisical run --env=production --token=$INFISICAL_TOKEN -- <command>`
4. Secrets are injected as env vars at runtime, never stored in Railway

**Access control for citizen developers:**
- Read-only dashboard access to their project's dev/staging environments
- No access to production secrets
- No CLI or API permissions unless explicitly granted
- Approval workflow for adding/changing production secrets

**References:**
- [Infisical secrets management overview](https://infisical.com/docs/documentation/platform/secrets-mgmt/overview)
- [Infisical CLI / `infisical run`](https://infisical.com/docs/cli/usage)
- [Infisical Supabase integration](https://infisical.com/docs/integrations/cloud/supabase)

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
