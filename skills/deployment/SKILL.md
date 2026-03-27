---
name: deployment
description: |
  Deployment guidance for sharing Traba apps. Use when: (1) user wants to deploy,
  share, or make their app accessible to others, (2) user asks about hosting or URLs.
  Covers: Railway, Cloudflare Access auth, Railway env vars for secrets, Supabase.
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

## Authentication — MUST be set up BEFORE deploying

**Do NOT deploy to Railway until Cloudflare Access auth is in place.** An unprotected deploy means the app is publicly accessible on the internet with no auth.

Auth is handled by engineers, not operators:
1. **Before deploying**, reach out to Sumeet, Jeff, or Moreno to set up Cloudflare Zero Trust Access for the app
2. They will configure OTP authentication restricted to @traba.work emails
3. Only after auth is confirmed should the app be deployed to Railway

Do NOT build your own auth for internal tools. Cloudflare Access sits in front of the app as a reverse proxy — users authenticate before any request reaches the origin.

## Persistence

When the app needs shared data across users, switch from SQLite to Supabase:
- Use the Supabase client library for data access
- Store Supabase URL and anon key in `.env` (gitignored), never hardcode
- Enable RLS on every table at creation time

## Secrets

- Store secrets as **Railway environment variables** in the project settings
- The app reads them via `process.env.SECRET_NAME` (or `Bun.env.SECRET_NAME`)
- Store secrets in `.env` locally (gitignored) for development — Railway env vars are only for production
- Never hardcode API keys, database URLs, or auth tokens in source code
