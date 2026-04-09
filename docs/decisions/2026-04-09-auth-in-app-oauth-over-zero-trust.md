# In-App Google OAuth Over Cloudflare Zero Trust

**Date:** 2026-04-09
**Status:** Accepted

## Context

Prometheus apps used Cloudflare Zero Trust (Access) as the default auth mechanism — a reverse proxy that gates access before requests reach the app. Zero code required, email domain restriction to `@traba.work`, free for up to 50 users.

Two problems emerged:

1. **50-seat cap.** The free tier covers 50 users across all Traba apps. As more operators and users onboard, this becomes a hard ceiling. Paid tier is $7/user/month.
2. **Coarse-grained control.** Zero Trust gates the entire app — no per-route auth, no custom session durations, no role-based access. Apps that need finer control end up building application-level auth anyway.

## Decision

Use in-app Google OAuth as the standard auth method for all new Prometheus apps. Retire Cloudflare Zero Trust for auth (legacy apps may still use it). Continue using Cloudflare for DNS.

## Why

- **No user cap.** Google OAuth via the userinfo API is free with no per-user pricing.
- **No platform lock-in.** Works on Railway, GCP, anywhere — auth lives in the app, not the infrastructure.
- **Full control.** Custom session durations (7-day JWTs), per-route middleware, role-based checks if needed.
- **Minimal code.** ~80 lines of Hono middleware, scaffolded by Claude from the authentication skill's reference implementation.

## Alternatives considered

### GCP Identity-Aware Proxy (IAP)

IAP is Google's equivalent of Zero Trust — a reverse proxy in front of GCP compute that forces Google auth before requests reach the app. Free, unlimited users, zero code. Solves the pricing problem.

**Rejected because:** IAP only works on GCP compute (Cloud Run, App Engine, GKE). Prometheus deploys to Railway for operational simplicity (one-click deploys, accessible to non-engineers). Adopting IAP would require migrating all hosting to GCP, setting up load balancers, and switching Cloudflare DNS to DNS-only mode to avoid proxy conflicts. The infrastructure migration cost far exceeds maintaining ~80 lines of auth code per app.

If Prometheus hosting ever moves to GCP compute, IAP becomes worth revisiting.

### Keep Cloudflare Zero Trust (paid tier)

$7/user/month solves the seat cap. But in-app OAuth is free, gives more control, and avoids vendor lock-in to Cloudflare's auth layer. The only advantage of Zero Trust was zero code, and that advantage shrinks to near-zero when Claude scaffolds the auth.

## Consequences

- All new Prometheus apps use in-app Google OAuth (authentication skill)
- Engineers create GCP OAuth Client IDs during Tier 2 promotion (eng runbook Step 4)
- Legacy apps on Zero Trust continue working — no forced migration
- Cloudflare still used for DNS (Railway one-click integration for `appname.traba.work` records)
- Cloudflare Zero Trust Terraform automation (open-questions.md #57) is no longer needed
