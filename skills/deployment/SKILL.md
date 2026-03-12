---
name: deployment
description: |
  Deployment guidance for sharing Traba apps. Use when: (1) user wants to deploy,
  share, or make their app accessible to others, (2) user asks about hosting or URLs.
  Covers: Railway, Cloudflare Pages, Cloudflare Access auth, Infisical secrets, Supabase.
version: 1.0.0
---

# Deploying a Shared App

When the user wants to share their app with others, the app needs:
1. A hosted backend and/or frontend
2. Authentication (so only Traba employees can access it)
3. Shared persistence (if the app stores data)
4. Secrets management (for API keys and credentials in production)

## Hosting

**Backends:** Deploy to Railway using GitHub integration (auto-deploy on push).

**Frontends/static sites:** Deploy to Cloudflare Pages via GitHub integration.

### Deploying from a Monorepo

Projects use a monorepo structure (`apps/web/`, `apps/api/`, `packages/shared/`). Deploy each app independently:

- **Railway (backend):** Set root directory to `apps/api`. Configure watch paths to include `apps/api/**` and `packages/shared/**` so shared code changes trigger rebuilds.
- **Cloudflare Pages (frontend):** Set build command to `cd apps/web && bun run build`. Set build output directory to `apps/web/dist`. Include `packages/shared/**` in watch paths.

Changes to `packages/shared/` rebuild both sides. Frontend-only changes don't redeploy the backend.

## Authentication

Every deployed app must be behind auth. Do NOT build your own auth for internal tools.

- Use Cloudflare Zero Trust Access with One-Time PIN
- Restrict to @traba.work email domain
- Post in #claudecodestuff or reach out to Sumeet or Jeff to get this set up

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
