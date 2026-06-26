---
name: deployment
description: |
  Deployment and sharing guidance for Traba apps and one-pagers. Use when:
  (1) user wants to deploy, share, or make their app accessible to others,
  (2) user asks about hosting or URLs, (3) user has a standalone HTML file
  (proposal, dashboard mockup, report) they want to share.
  Covers: Google Drive for static HTML, Railway for full apps, in-app Google
  OAuth, Railway env vars for secrets, Railway Postgres.
version: 1.3.0
---

# Sharing an App or Page

Before deploying anything, figure out which case applies. Most ops shares fall into one of two buckets, and they have very different answers.

| What you have | How to share |
|---------------|--------------|
| A single static HTML file (or a small folder of static files) — proposal, report, dashboard mockup, GTM doc, anything with no backend logic | **Google Drive** — see below |
| A real app with API logic, auth, persistence, or anything dynamic | **Railway** — see "Deploying a Shared App" below |

If you're unsure, ask: "does this page need to talk to a database or call an API on every load?" If no, it's a static file — use Drive.

---

## Sharing Standalone HTML Pages — Google Drive

**Do not deploy standalone HTML pages to Railway, Vercel, Netlify, GitHub Pages, or any personal hosting account.** Static HTML pages — GTM proposals, internal reports, dashboard mockups, one-off visualizations — should be shared via **Google Drive**, not hosted on the public internet.

**Why Drive instead of hosting:**

- **Access control comes for free.** Drive uses Traba's Google Workspace permissions — restrict to `@traba.work`, named individuals, or specific groups. Revocable, auditable, and lives inside the perimeter we already manage.
- **No public URLs leaking confidential info.** Internal proposals and reports routinely contain customer names, pricing, headcount, or strategy. A public Vercel URL has no access control by default — anyone who guesses or stumbles on the URL can read it. Drive links are gated.
- **No personal accounts hosting Traba content.** Files on a personal Vercel/Netlify account leave with the person when they leave. Drive files stay in the Traba Workspace.
- **No deploy step.** Drop the file in Drive, share it, done. No build, no env vars, no DNS.

**How to share a static HTML file via Drive:**

1. Upload the `.html` file to Google Drive (any folder the user has access to).
2. Set sharing to one of:
   - "Anyone at Traba with the link" (default for internal proposals)
   - Specific people or groups (for anything confidential)
3. Share the Drive link in Slack or wherever the recipients live.
4. Recipients click the link in Drive → **Open with → Browser**, or **Download** and open the file in Chrome. Either works; the file runs locally in their browser.

**What "static HTML" means here:** A file that runs entirely client-side. No server-side rendering, no API calls to a backend you control, no database writes. Inline `<script>` tags, fetches to public CDNs, and embedded data are all fine. If the page calls a Traba API or needs auth, it's not a static page — see Railway below.

**One-pagers with embedded data:** If the HTML embeds data (a chart, a table, a snapshot), make sure the data itself is okay to be inside a Drive-shared file. Drive controls who sees the file; it doesn't redact what's inside.

**Multi-file static sites:** If the share is a folder of HTML/CSS/JS (e.g., a report with assets), zip the folder and upload the zip, or upload the whole folder to Drive and share the folder link. Recipients download and open `index.html` locally.

**When this rule does not apply:** If the page is part of a real app (has a backend, uses auth, persists data), it's not a static one-pager — deploy it to Railway with the full pattern below.

---

# Deploying a Shared App

When the user wants to share a full app with others, the app needs:
1. A hosted backend and/or frontend
2. Authentication (so only Traba employees can access it)
3. Shared persistence (if the app stores data)
4. Secrets management (for API keys and credentials in production)

## Hosting

**Everything deploys to Railway under the Traba Railway team.** Deploy a single Railway service that builds the frontend and serves it as static files from the backend. One service, one URL, one deploy. Even frontend-only apps get a minimal backend to serve them. **Do not deploy to personal Railway accounts.** Before deploying, verify the project is under the Traba team — not a personal plan. If the user isn't on the team, they need to request access in #claudecodestuff or from Sumeet/Jeff before proceeding.

**The repo must be in the `Traba-Ops` GitHub org.** Railway's GitHub integration should connect to the `Traba-Ops` org repo, not a personal fork or personal GitHub repo. If the code isn't in `Traba-Ops` yet, push it there first before setting up Railway auto-deploy.

**Name the Railway project clearly.** Don't accept the default random Railway project name. Set the project name to something descriptive that identifies the app (e.g., "shift-tracker", "ops-dashboard"). This keeps the Railway dashboard navigable as more apps get deployed.

### Railway Setup for Monorepos

Railway's Nixpacks auto-detection gets confused by monorepo structures with multiple apps. Make the build explicit with **two committed files at the repo root**: a `nixpacks.toml` that pins the toolchain and owns the build phases, and a slim `railway.json` for the builder + restart policy.

**Pin the runtime — `railway.json` alone is not enough.** Before any `railway.json` command runs, Nixpacks runs a nix *setup* phase that installs a default toolchain. For a JS/TS project that default is **Node 18**, which is End-Of-Life and has been removed from current nixpkgs — so the build dies in the setup phase with `Node.js 18.x has reached End-Of-Life and has been removed`, before a single command executes. `railway.json` has no field for the runtime version; this is a Nixpacks concern. Add a `nixpacks.toml` that pins the toolchain (use **`nodejs_22`**, the current LTS — Node 20 is already past EOL) and defines the phases explicitly:

```toml
# Explicit Nixpacks build for a bun monorepo. Without this, Nixpacks falls back to
# its default Node (18) — EOL and removed from current nixpkgs — and the build fails
# at the nix setup phase. Pin bun (runs install, build, server) + Node 22 (current
# LTS; 20 is already EOL).
[phases.setup]
nixPkgs = ["bun", "nodejs_22"]

[phases.install]
cmds = ["bun install"]

[phases.build]
cmds = ["cd apps/web && bun run build"]

[start]
cmd = "cd apps/api && bun run start"
```

With phases owned by `nixpacks.toml`, keep `railway.json` to just the builder + restart policy — single source of truth, no duplicated commands:

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": { "builder": "NIXPACKS" },
  "deploy": { "restartPolicyType": "ON_FAILURE", "restartPolicyMaxRetries": 10 }
}
```

Adapt the `cd apps/web && bun run build` / `cd apps/api && bun run start` commands to the repo's actual scripts (a workspace-script setup that maps these to a single `bun run build` / `bun run start` works equally well). Belt-and-suspenders: adding `"engines": { "node": ">=22" }` to the root `package.json` lets any Node-version-aware tooling pick 22 too.

### Backend Serves the Frontend

The backend must serve the built frontend static files. After `bun run build` in `apps/web/`, the output is in `apps/web/dist/`. The backend should:

1. Serve static files from `../../apps/web/dist` (relative to `apps/api/`)
2. Add a catch-all route that serves `index.html` for client-side routing (SPA fallback)
3. Mount static serving **after** all API routes so `/api/*` still works

Example with Hono (the prescribed backend framework):
```typescript
import { serveStatic } from "hono/bun";

// API routes first
app.route("/api", apiRoutes);

// Serve frontend static files
app.use("/*", serveStatic({ root: "../web/dist" }));

// SPA fallback — serve index.html for unmatched routes
app.get("/*", (c) => c.html(Bun.file("../web/dist/index.html").text()));
```

### Frontend-Only Apps

If the project has no API logic, still create a minimal backend in `apps/api/` that serves the frontend static files. This keeps the deployment pattern consistent across all Prometheus projects. The backend is just a static file server with the SPA fallback — a few lines of code.

## Post-Deploy Monitoring

After every deploy, **monitor the deploy logs until the service is healthy.** Don't deploy and walk away.

1. Watch the build logs for errors during install/build
2. Watch the deploy logs for runtime errors on startup
3. Confirm the service is running and responding
4. If something fails, diagnose and fix it — then redeploy and monitor again
5. Keep iterating until the deploy succeeds or the issue clearly requires human intervention (e.g., missing secrets, infra access, DNS)

If the operator is watching, give them status updates as you go. If you hit something you can't fix, explain what's wrong and what's needed.


## Authentication — MUST be set up BEFORE deploying

**Do NOT deploy to Railway until auth is in place.** An unprotected deploy means the app is publicly accessible on the internet with no auth.

The standard is **in-app Google OAuth** — see the authentication skill for the reference implementation. The app handles login via `@react-oauth/google` on the frontend and verifies tokens server-side. An engineer creates the GCP credentials and verifies the implementation. Key requirements before deploying:

1. Engineer creates an OAuth Client ID in GCP Console and provides it to the operator
2. Set `VITE_GOOGLE_CLIENT_ID` as a Railway env var **before the first deploy** (it's build-time)
3. Set `SESSION_SECRET` as a Railway env var and **seal it**
4. Verify the app rejects non-`@traba.work` accounts

## Persistence

When the app needs shared data across users, switch from SQLite to Railway Postgres:
1. Add a Postgres database to the Railway project (`Cmd+K` or `+ New` → Postgres template)
2. **Disable TCP proxy** on the database service (Settings → Networking → remove TCP proxy) — Prometheus apps connect over private networking, so the DB should not be exposed to the public internet
3. In the app service, add a reference variable: `DATABASE_URL` = `${{Postgres.DATABASE_URL}}`
4. Update the Prisma schema to use `provider = "postgresql"` instead of `sqlite`
5. Run `bunx prisma migrate dev` to apply the schema to the new database

`DATABASE_URL` does not need to be sealed as long as TCP proxy is disabled — the password is only accessible within Railway's private network.

## Secrets

- **Never hardcode** API keys, database URLs, or auth tokens in source code
- Store secrets in `.env` locally (gitignored) for development
- The app reads them via `process.env.SECRET_NAME` (or `Bun.env.SECRET_NAME`) — same interface in dev and prod
- In production, store secrets as **Railway environment variables** in the project settings

### Sealing sensitive variables

After deploying an app or adding new env vars, review every variable the app uses and tell the operator which ones need to be sealed for security. Sealing locks a variable so its value is still available to the app but nobody can view it in Railway's dashboard.

**Seal these** — any variable whose value is a credential, key, or password:
- API keys (Anthropic, Stripe, Firebase, GCP, etc.)
- Database passwords
- Service account credentials
- Signing keys, JWT secrets, private keys

**Don't seal these** — basic configuration that isn't sensitive:
- `PORT`, `NODE_ENV`, `LOG_LEVEL`
- `RAILWAY_PUBLIC_DOMAIN`
- Public URLs, project IDs
- Feature flags, non-secret config

When instructing the operator to seal variables, tell them:
1. These variables are sensitive credentials that need to be properly secured — sealing ensures nobody can view them in Railway's dashboard
2. Write down or save the value somewhere safe first (e.g., a password manager) — once sealed, the value can never be viewed again in Railway
3. In Railway's dashboard, click the **three-dot menu** next to the variable → **Seal**
4. The app will keep working as normal — sealing just hides the value from the dashboard
