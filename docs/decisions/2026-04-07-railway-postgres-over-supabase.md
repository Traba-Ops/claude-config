# Replace Supabase with Railway Postgres

**Date:** 2026-04-07
**Status:** Accepted

## Context

Prometheus apps that need shared persistence were using Supabase (PostgreSQL-backed) as the database layer. As the number of Tier 2 apps grows, two problems emerged:

1. **Cost scales per-project.** Supabase charges ~$10/mo per project for a dedicated Postgres VM (Micro compute). Only one is covered by the Pro plan's $10 credit. At 5-10 apps: $65-115/mo in database costs alone.
2. **Operational overhead.** Supabase is a separate service from Railway. Every operator needs access provisioned, every offboarding needs it revoked, and engineers manage two platforms instead of one.

## Decision

Use Railway Postgres for all Prometheus database needs. Drop Supabase from the prescribed stack.

## Why

- **Cost:** Railway bills databases by actual resource consumption. A small idle Postgres costs ~$0.50-1.00/mo. Multiple databases share the same usage credit pool ($20/mo Pro). 10 small databases fit comfortably within the included credit.
- **Operational simplicity:** We already use Railway for hosting. Adding a database is one click in the same project. No separate service onboarding, no extra credentials, one fewer thing to revoke during offboarding.
- **Supabase abstraction is redundant:** Prometheus apps use Prisma for data access and Hono for the API layer. Supabase's auto-generated REST APIs, dashboard UI, and built-in auth aren't used.

## Networking detail

Railway's Postgres template enables TCP proxy by default (public internet access). Prometheus apps connect over private networking within the same project, so TCP proxy should be disabled. With it disabled, `DATABASE_URL` doesn't need to be sealed — the password is only accessible within Railway's private network.

## What was rejected

- **Keep Supabase:** Per-project cost penalty compounds and the abstraction layer isn't used.
- **Neon:** Raw Postgres without the deployment platform integration. Would still be a separate service to manage.

## Impact

Updated: `stack.md`, `security.md`, `admin.md`, `open-questions.md`, `pipeline.md`, `skill-bundle-spec.md`, `eng-runbook.md`, `deployment/SKILL.md`, `project-setup/SKILL.md`, `gitignore.template`.
