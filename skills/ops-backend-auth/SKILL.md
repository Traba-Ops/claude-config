---
name: ops-backend-auth
description: |
  Give a Prometheus/internal app durable, non-interactive access to Traba's
  node backend (`ops-prod.traba.tech` `@OpsAuth()` endpoints) via a GCP
  service account. Use when an app needs to call the backend API — read live
  ops data or take an ops action — rather than query BigQuery.
version: 1.0.0
---

# Node Backend Auth (ops-prod service accounts)

> **The gate is an allow-list, not the credential.** A service account with a valid token but no entry in the `service_account_scopes` Statsig config is denied **everything** (`enforce: true`, default-deny). Provisioning is always two things: a trusted identity, and a per-route grant.

## When this is the right tool

| Need | Use |
|---|---|
| Analytics / historical data, per-user RBAC | **bq-auth** skill (traba-auth proxy → BigQuery) |
| A one-off question or ops action, ad hoc | **Neutron** (`ask_neutron`) |
| An app calling the same backend endpoints programmatically, on a schedule or per record | **This skill** |

The third case is why these exist: Neutron per-record is slow and costs a model call each time; a service account turns it into a plain HTTP call. Don't provision a service account for something you'll do twice.

**Base URL:** `https://ops-prod.traba.tech` · **Auth:** `Authorization: Bearer <Google ID token>`

---

## Step 1 — Service account (identity)

Create a GCP service account **in the existing `traba-ops` project**. Never create a new GCP project (see [security.md](../../docs/security.md)); ask a GCP admin to provision it.

- **Zero IAM roles.** The ID token is self-signed offline — the backend checks only the email-claim domain, never GCP permissions.
- The three trusted domains are already in `GCP_SERVICE_ACCOUNT_DOMAINS` (`apps/traba-server-node/src/auth/auth.constants.ts`): `traba-ops`, `traba-app`, `traba-dev-app`. A SA in any of them needs **no code change**.
- A SA outside those projects needs its domain added to that constant **and** mirrored in `auth.constants.spec.ts` (the test fails otherwise) — a PR plus a deploy. Prefer `traba-ops` and skip it.
- **Key handoff:** Infisical share link (`accessType: "organization"`, `expiresIn: "1d"`), then straight into an env var (Railway/Porter). Never commit the key, never paste it in Slack.

Trusting a domain trusts *every* service account in that project as `EmployeeRole.Internal`. That's deliberate — the security lives in step 2, not here.

## Step 2 — Route allow-list (the actual gate)

Add the SA's email to the **`service_account_scopes` Statsig dynamic config**. Pure config: it takes effect on the next config read, no deploy.

```jsonc
{
  "enforce": true,
  "scopes": {
    "myapp@traba-ops.iam.gserviceaccount.com": [
      { "method": "POST", "pathPattern": "/v1/workers/search" },
      { "method": "GET",  "pathPattern": "/v1/workers/:workerId/worker-and-profile" }
    ]
  }
}
```

- **`pathPattern` (preferred)** — exact, end-anchored path-to-regexp against the full path including the `/v1` prefix. `:param` matches one segment. Avoid `*name` wildcards; they span segments and quietly re-create a subtree grant.
- **`pathPrefix`** — segment-boundary prefix, grants the whole subtree below it. Coarse; use only when you really mean the subtree. If both are set, `pathPattern` wins.
- **`method: "*"`** matches any method. Prefer naming the method.
- **Every additional endpoint is one more rule.** This is the recurring inbound ("my SA started 403ing on a new route") and the fix is always a new `pathPattern`, never a code change.

Edit via the Statsig MCP `Update_Dynamic_Config_Entirely` — read-modify-write the *whole* `defaultValue`, preserving `enforce` and every other SA.

> ### ⚠️ A scope change is TWO edits, not one
> The config carries a **`Dev tier scopes` rule** (`environments: ["development"]`) whose value **replaces** `defaultValue` on dev rather than merging with it. Patch only `defaultValue` and you get a prod-works / dev-403s split that reads like an auth bug.
>
> Always mirror the change into both, then re-GET and confirm the SA's array is byte-identical in `defaultValue` and in the rule's `returnValue`. The one intentional asymmetry: a **dev-only SA** (e.g. `*-dev@traba-dev-app`) lives in the rule *only*, so it 403s on prod by design.

## Step 3 — Mint the token in the app

```ts
import { GoogleAuth } from 'google-auth-library'

const auth = new GoogleAuth({
  credentials: JSON.parse(process.env.MYAPP_SA_KEY!),
})
const client = await auth.getIdTokenClient('https://ops-prod.traba.tech')
const headers = await client.getRequestHeaders() // { Authorization: 'Bearer <id token>' }
```

The audience is **not** validated server-side (only the email domain is), but pass the real URL anyway. The library refreshes the token automatically — that auto-refresh is the whole point, and what makes this durable where a copied user token dies after an hour.

---

## Before you request a route, verify it exists

Check against **`origin/main`, not your local checkout** — a stale local `main` returns zero hits for routes that do exist, which reads as "the endpoint is fake."

```bash
git fetch origin main
git grep -n "<controller-or-handler>" origin/main -- apps/traba-server-node/src
```

Compose the exact template: the global `v1` prefix + `@Controller('<x>')` + `@Get('<y>/:param')`, param names included. Then read the response DTO — the grant exposes everything in it, so scope to the narrowest route that answers the question.

## Debugging a 403

**It is never the route decorators.** A service account classifies as `EmployeeRole.Internal`, which short-circuits `authorizeOps` (`auth/auth.service.ts`) *before* any role, external-scope, or permission check. `@OpsAuth([External])`, `@ExternalScope`, and `@RequiresPermission(...)` are all no-ops for a SA. The only gate that runs is `enforceServiceAccountScope`.

So a 403 means exactly one of:
- no entry for that SA email, or
- the `pathPattern` doesn't match the real path (usually a missing `/v1`, a wrong param position, or a trailing-slash/case mismatch), or
- you edited `defaultValue` but not the dev rule (or vice versa).

**Smoke test after granting:** call the in-scope route with a bogus id → expect **404** (auth and scope passed). Call an out-of-scope route → expect **403** with a scope-violation message.

**Monitoring:** `enforce: false` flips the whole config to monitor mode — violations log `service_account_scope_violation` in Datadog and pass through. There is **no** per-request log of *allowed* routes, so you cannot enumerate what a SA is permitted to call from logs. Source of truth is the config plus the consumer repo (grep it for `ops-prod.traba.tech` / `getIdTokenClient`).

## Attribution

Every call logs `actorId = the service account email` — not the human who triggered it. If an action needs per-human attribution (anything a COps person approves), use the impersonation path instead: a Node JWT with an `impersonatedUserEmail` claim via `NODE_SERVICE_TOKEN`.

## Tightening an existing SA without a 403 window

The matcher reads config live but the *code* deploys, so during a rollout old and new pods can disagree. Set **both** `pathPrefix` and `pathPattern` on each rule, deploy, then drop the prefix once the PR is fully rolled out.

## Prior art

| App | SA | Notes |
|---|---|---|
| Trabito flyer generator (`Traba-Ops/traba-onboarding-bot`) | `trabito@traba-ops` | First one. 4 routes: worker search, worker-and-profile, account-setup completion, ops-card read |
| onsite-timesheets | `onsite-timesheets@traba-ops` | Write-heavy: shift adjustments, start/end shift, todo, no-show, cancel |
| CONVEYOR (SMS vetting) | `conveyor@traba-ops` | Provisioned for one route to replace two Neutron calls per cycle |
| Backfill bot | `backfill-service-account@traba-ops` + `-dev@traba-dev-app` | The dev/prod pair pattern — dev SA in the dev rule only |
