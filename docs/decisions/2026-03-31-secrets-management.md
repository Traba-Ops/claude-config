# Secrets Management: Railway Sealed Secrets

## Context
Railway's baseline plan has no RBAC — only two roles exist (Member with full access, Deployer with almost none). Every team Member can view every environment variable on every project in plaintext. Javier demonstrated this by pulling someone's Anthropic API key from a project he didn't create. A security audit of all 14 Railway projects found 5 scored critical and 3 scored high for env var sensitivity.

The team needed a way to protect sensitive credentials without migrating off Railway or upgrading to an enterprise plan.

## Approaches Considered

### Option 1: Railway sealed secrets
Seal sensitive variables in Railway's UI. Simple, no new tooling. Operators can do it themselves.

Tradeoff: sealing is permanent and irreversible — if you lose the value, it's gone. No audit trail or rotation workflow built in. But for the current scale (small team, infrequent deploys), this is acceptable as long as values are saved in a password manager before sealing.

### Option 2: Infisical + Railway sealed secrets
Infisical manages the lifecycle (rotation, access control, audit trail). Railway sealing prevents casual exposure in the dashboard. Complementary controls.

Tradeoff: adds tooling complexity. Sealing is UI-only (no CLI or API), so it's still a manual step on top of Infisical. Good for projects that need rigorous lifecycle management, overkill for most Prometheus projects.

### Option 3: Replace Railway env vars entirely with Infisical SDK
Apps read secrets directly from Infisical at runtime instead of from env vars.

Problem: requires code changes in every app, adds a runtime dependency on Infisical availability, and breaks the standard `process.env` pattern. Over-engineered for the current scale.

## Decision
Option 1 as the default, Option 2 for special cases (e.g., projects with production DB credentials or high-rotation secrets like the interview-scheduler).

- Operators seal sensitive variables directly in Railway's dashboard after deploying
- Claude reviews env vars and recommends what to seal based on a sensitivity classification (score 1-5)
- Score 4-5 variables (API keys, DB passwords, service accounts, signing keys): must seal
- Score 1-2 variables (PORT, NODE_ENV, public config): leave plain
- Dead projects: revoke secrets immediately on stopped/failed Railway services
- Infisical available for projects that need rotation workflows or centralized access control, but not required

Discussed in #epdd-core-team and #claude-will on 2026-03-31. Will is sealing the interview-scheduler's sensitive vars, Javier is moving data-observability to Infisical, Jeff fixed the slackbot's Infisical integration.
