---
name: deployment
description: |
  Deployment guidance for sharing Traba apps. Use when: (1) user wants to deploy,
  share, or make their app accessible to others, (2) user asks about hosting or URLs.
  Covers: Railway, Cloudflare Access auth, Infisical secrets, Supabase.
version: 1.0.0
---

# Deploying a Shared App

When the user wants to share their app with others, the app needs:
1. A hosted backend and/or frontend
2. Authentication (so only Traba employees can access it)
3. Shared persistence (if the app stores data)
4. Secrets management (for API keys and credentials in production)

## Hosting

**Everything deploys to Railway.** Deploy a single Railway service that builds the frontend and serves it as static files from the backend. One service, one URL, one deploy. Even frontend-only apps get a minimal backend to serve them.

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

- All secrets go in Infisical for deployed apps
- Use `infisical run` in the Railway start command to inject secrets at runtime
- Never store secrets in Railway environment variables directly
- Never hardcode API keys, database URLs, or auth tokens
