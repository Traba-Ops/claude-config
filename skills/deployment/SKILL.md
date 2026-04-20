---
name: deployment
description: |
  Deployment guidance for sharing Traba apps. Use when: (1) user wants to deploy,
  share, or make their app accessible to others, (2) user asks about hosting or URLs.
  Covers: Railway, in-app Google OAuth auth, Railway env vars for secrets, Railway Postgres.
version: 1.0.0
---

# Deploying a Shared App

When the user wants to share their app with others, the app needs:
1. A hosted backend and/or frontend
2. Authentication (so only Traba employees can access it)
3. Shared persistence (if the app stores data)
4. Secrets management (for API keys and credentials in production)

## Hosting

**Everything deploys to Railway under the Traba Railway team.** Deploy a single Railway service that builds the frontend and serves it as static files from the backend. One service, one URL, one deploy. Even frontend-only apps get a minimal backend to serve them. **Do not deploy to personal Railway accounts.** Before deploying, verify the project is under the Traba team — not a personal plan. If the user isn't on the team, they need to request access in #claudecodestuff or from Sumeet/Jeff before proceeding.

**The repo must be in the `Traba-Ops` GitHub org.** Railway's GitHub integration should connect to the `Traba-Ops` org repo, not a personal fork or personal GitHub repo. If the code isn't in `Traba-Ops` yet, push it there first before setting up Railway auto-deploy.

**Name the Railway project clearly.** Don't accept the default random Railway project name. Set the project name to something descriptive that identifies the app (e.g., "shift-tracker", "ops-dashboard"). This keeps the Railway dashboard navigable as more apps get deployed.

### Railway Setup for Monorepos

Railway's Nixpacks auto-detection gets confused by monorepo structures with multiple apps. **Always add a `railway.json`** at the repo root to make the build explicit:

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "bun install && cd apps/web && bun run build"
  },
  "deploy": {
    "startCommand": "cd apps/api && bun run start",
    "restartPolicyType": "ON_FAILURE"
  }
}
```

This tells Railway exactly what to do: install dependencies, build the frontend, then start the backend.

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


## Authentication — MUST be wired into the app BEFORE deploying

**Do NOT deploy to Railway until Google OAuth is in the app.** An unprotected deploy means the app is publicly accessible on the internet with no auth. Cloudflare Access is retired as an auth option (see `docs/decisions/2026-04-09-auth-in-app-oauth-over-zero-trust.md`). **In-app Google OAuth is the only supported auth path.**

Follow the [authentication skill](../authentication/SKILL.md) to build the auth layer. You can write all the code yourself — no engineer involvement needed for the code. The only thing you cannot self-serve is the GCP OAuth Client ID.

### What you do
- Scaffold the auth layer using the authentication skill (server-side domain check, session JWTs, login screen, Bearer token on all `/api/*`, `/webhooks/*` exempt)
- Build and test locally without the real Client ID — fall back to a dummy value, the login button will fail gracefully
- Prepare the deploy: confirm the repo is in `Traba-Ops`, confirm you're on the Traba Railway team, push to the branch Railway watches

### What an engineer does (Sumeet / Jeff / Moreno)
- Creates the OAuth Client ID in GCP Console → `console.cloud.google.com` → APIs & Services → Credentials
- Sets up the Authorized JavaScript Origins to include the Railway production URL (e.g., `https://appname-production.up.railway.app`)
- Hands you the Client ID (it's public — not a secret, baked into the frontend)

### Env vars for the auth layer
Set these in Railway → Variables **before the first deploy that allows user traffic**:
1. `VITE_GOOGLE_CLIENT_ID` (or `GOOGLE_CLIENT_ID` for vanilla-JS apps) — engineer provides this
2. `SESSION_SECRET` — generate with `openssl rand -hex 32`, seal it

### Verification checklist
- [ ] Opening the Railway URL shows the login screen, not the app UI
- [ ] Clicking "Sign in with Google" opens the Google popup
- [ ] A non-`@traba.work` Google account gets rejected with an `Unauthorized domain` error
- [ ] A `@traba.work` account lands in the app and sees data
- [ ] Hitting any `/api/*` endpoint without a Bearer token returns 401
- [ ] `/webhooks/*` is reachable without auth (if applicable — secured via HMAC instead)

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
