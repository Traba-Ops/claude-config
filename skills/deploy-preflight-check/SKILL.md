---
name: deploy-preflight-check
description: |
  Pre-deploy compliance checklist for Prometheus projects. Use when: (1) an app is about to be
  deployed or redeployed, (2) user asks to audit or check the project for compliance,
  (3) promoting a project to Tier 2.
version: 1.0.0
---

# Pre-Flight Check

Four invariants every deployed Prometheus tool must hold:

1. **Secrets never leave the perimeter** — not in git, not in the bundle, not in logs.
2. **Data access is always per-user** — nothing sidesteps Traba's permission model, no copies at rest.
3. **Nothing is reachable without auth** — every data endpoint gated, server-side.
4. **Infrastructure stays inside Traba's perimeter** — Traba's org, Traba's accounts, Traba's comms rails.

Run the check before the **first** deploy and again before redeploying after significant changes. Profile the app first — the profile decides which checks apply — then work through each invariant.

Findings are tagged:
- **[BLOCKER]** — do not deploy until fixed. Fixing is technical work: yours. If the operator asks to deploy anyway, explain the risk and hold the line (constitution: security outranks everything).
- **[advisory]** — report to the operator with a recommended fix; doesn't block the deploy.

Run commands from the repo root. Scope greps to source with pathspecs — `git grep <pattern> -- apps/ packages/ scripts/ prisma/` (adjust to the repo's layout) — so docs, lockfiles, and fixtures don't false-positive; when a check says "deployed code," that means `apps/` and anything the start command reaches, not developer-run `scripts/`.

## Profile the app

Determine each from the repo, not from memory:

| Question | Signals |
|---|---|
| Queries the warehouse? | `data-proxy.traba.work`, `/query` + `X-App-Name`, SQL strings against `traba-app` |
| Calls the node backend? | `ops-prod.traba.tech`, `getIdTokenClient`, a `*_SA_KEY` env var |
| Sends worker-facing messages? | `api.openphone.com`, `/v1/worker-outreach/request`, `/communication/send-direct-two-way-sms` |
| Has its own database? | Prisma schema, `DATABASE_URL` |
| Vite frontend? | `apps/web/` with `import.meta.env` |

Warehouse-shaped SQL with **no** traba-auth signals is itself a finding — the app is reaching the warehouse some other way; find the path and treat it under invariant 2.

## Invariant 1 — Secrets never leave the perimeter

**[BLOCKER] No credentials in the tree or git history.** A secret committed and later deleted still leaks to anyone who clones.

```bash
git ls-files | grep -E '(^|/)\.env' | grep -v '\.env\.example'        # committed env files
git grep -l '"type": "service_account"' -- '*.json'                    # committed SA keys
git grep -nE "(api[_-]?key|secret|token|password)['\"]?[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9_-]{16,}"
# History — gitleaks if installed, else the pattern fallback:
gitleaks git . 2>/dev/null || git log -p | grep -nE -- "-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-ant-|sk-proj-|sk_live_|pk_live_|ghp_[A-Za-z0-9]{36}|github_pat_|xox[baprs]-|AIza[0-9A-Za-z_-]{35}|postgres(ql)?://[^:]+:[^@]+@" | head -40
```

On any real hit: **rotate the credential first** (it's compromised regardless of what happens to the file), then move it to a Railway env var. Incident-response steps: `~/.claude/docs/security.md`.

**[BLOCKER] No secret behind a `VITE_` prefix.** Anything named `VITE_*` is baked into the public JS bundle and shipped to every browser. Public config is fine (`VITE_GOOGLE_CLIENT_ID`, public URLs); a key or token there is a leak even if every other check passes.

```bash
git grep -hoE "import\.meta\.env\.VITE_[A-Z_]+" | sort -u
git grep -nE "^VITE_" -- '.env.example' 'apps/web/.env.example'
```

Judge each var by its **value**, not its name — check what `.env.example` and the Railway config actually assign; a `VITE_API_URL` carrying a token in a query string is a leak with an innocent name.

**[BLOCKER] Nothing sensitive in logs.** Log metadata, never the values: `len(rows)`, `rowCount`, and elapsed time are the good pattern; the `rows`/`result` object itself, a token, or a request body in a log line is the defect.

```bash
git grep -nE "(logger\.(info|warn|debug|error)|console\.log)\([^)]*\b(rows|result|token)\s*[,)}]" -- apps/
```

Judge each hit: a metadata read like `len(rows)` or `rows.length` passes; the object as a logged value blocks.

**[advisory] `.gitignore` covers secrets** — `.env`, `.env.*` (with `!.env.example`), `*.pem`, `*.key`, `credentials.json`; full list in the project-setup skill's `gitignore.template`.

**[advisory] Sealing classification.** Enumerate every env var the app reads and classify against the deployment skill's sealing rubric; tell the operator exactly which to seal. Sealing happens **after** the deploy is verified working (sealed values can't be read back) — set values pre-deploy, seal post-deploy.

```bash
git grep -hoE "(process|Bun)\.env\.[A-Z_]+|import\.meta\.env\.[A-Z_]+|os\.getenv\(['\"][A-Z_]+" | sort -u
```

## Invariant 2 — Data access is always per-user

The first two checks run for **every** app — a direct-BigQuery import or a service-account reference in a repo with no warehouse profile signals is precisely the silent violation to catch (a hit retroactively marks the profile "queries the warehouse"). The remaining checks apply when the app touches the warehouse, the node backend, or holds a database.

**[BLOCKER] No direct BigQuery access in deployed code.** Every warehouse query routes through traba-auth `/query` under the requesting user's token (bq-auth skill). Developer-run `scripts/` using a local key are exempt — unless the start command or `apps/` code reaches them, which makes them deployed code.

```bash
git grep -nE "@google-cloud/bigquery|google[.-]cloud[.-]bigquery|GOOGLE_APPLICATION_CREDENTIALS" -- apps/ package.json
```

**[BLOCKER] Service accounts only in the sanctioned pattern.** A GCP service account is legitimate in exactly one shape — the ops-backend-auth pattern, all four parts: (1) SA email in a trusted project (`traba-ops`, `traba-app`, or `traba-dev-app`), (2) used to mint ID tokens for the `ops-prod.traba.tech` audience, (3) granted routes in the `service_account_scopes` Statsig config, (4) key read from a **sealed** env var. Anything else is a violation: a SA touching BigQuery, a committed key file, or — as a specific exclusion regardless of the four parts — any reference to Omni's BI account (`omni-63@traba-app.iam.gserviceaccount.com`), which belongs only in Omni's own connection config.

```bash
git grep -n "iam.gserviceaccount.com"   # judge each hit against the sanctioned shape
```

**[BLOCKER] No warehouse data or tokens at rest.** The app's own Postgres, files, or caches must not hold BigQuery results or auth tokens — a durable copy is served under the app's rules instead of the user's. Read the Prisma schema directly: any model with a `token`/`accessToken`/`refreshToken`/`jwt` field, or storing warehouse-derived rows, is the anti-pattern. Per-user caching is permitted for **metadata only** (lookup tables, filter options); warehouse rows are queried fresh per request, always.

```bash
git grep -niE "auth_tokens|bq_cache|refresh_token" -- apps/ prisma/
git ls-files | grep -E '\.(csv|sqlite|db|jsonl?)$'   # committed data extracts — judge each
```

**[BLOCKER] No SQL built by string interpolation of user input.** Use `?` placeholders for strings; inline non-string values only with proper escaping (bq-auth skill).

```bash
git grep -nE '`(SELECT|INSERT|WITH)[^`]*\$\{' -- apps/     # candidates — judge each
git grep -nE 'f["\x27](SELECT|INSERT|WITH)' -- apps/ scripts/
```

The template-literal hits are candidates, not verdicts: trace each interpolated value — request/user input flowing in is a blocker; a static column list, a hardcoded table constant, or a `Prisma.sql` tagged template is fine.

**[advisory] SQL conformance.** For every warehouse query: current modeled layers (`marts`, `metrics`, `features`, `scores`, `src_*`, `intermediate`) not legacy `traba_prod`/`pg_export_*` (`git grep -niE "traba_prod|pg_export_"`); tables fully qualified as `` `traba-app.dataset.table` ``; partition filters on partitioned tables (an unfiltered scan bills the whole table). Portfolio-level metrics (queries shaped like `GROUP BY company_id` / `COUNT(DISTINCT company_id)`) must exclude Traba's internal and test companies — don't invent a `name LIKE 'Traba%'` filter; ask in #data for the canonical exclusion and record the answer in the project's SPEC.md so the next run can verify it.

## Invariant 3 — Nothing is reachable without auth

**[BLOCKER] The right auth pattern is present, with its markers.** Absence of bypass strings is not auth — verify the scaffolding exists:

- **Warehouse app** → login through traba-auth (bq-auth skill). Required markers: redirect to `$TRABA_AUTH_URL/auth/login`, code exchange at `/auth/token`, Bearer token on `/query`, and — only when a backend receives tokens from a client — per-request validation via `/auth/me` (apps holding the JWT server-side, like Streamlit session state or an httpOnly cookie, validate implicitly through `/query` 401 handling). The production origin must be in `ALLOWED_REDIRECT_ORIGINS` before the app goes live, but the allowlist request is sent **after** this check comes back CLEAR — the scorecard rides it (bq-auth has the template) — so an origin not yet allowlisted is the expected state here, not a blocker.
- **Everything else** → in-app Google OAuth (authentication skill). Required markers: `@react-oauth/google` on the frontend, server-side verification with `hd === "traba.work"`, `jose`-signed session JWTs, `SESSION_SECRET` from env.

Missing markers for the profile's pattern = blocker.

**[BLOCKER] Every data route sits behind the auth middleware.** Read the Hono app: auth middleware must be mounted before the `/api` routes it protects, and every route returning data must be covered. List the routes now — the post-deploy probe reuses the list.

```bash
git grep -nE "app\.(get|post|put|patch|delete|route)\(" -- apps/api/
```

**[BLOCKER] No bypass path.** No `DEV_MODE`, `SKIP_AUTH`, mock user, or service-account fallback in the app — the code path tested locally is the one that runs in prod (bq-auth skill has the compliant local-dev setups).

```bash
git grep -niE "dev_mode|skip_auth|bypass_auth|mock_user|no_auth" -- apps/
```

**[advisory] CORS is never `*`.** Allowed origins are the app's own domain(s): `git grep -n "Access-Control-Allow-Origin" -- apps/`.

**[advisory] Rate-limit expensive endpoints.** Any route that calls a paid API (Anthropic etc.) unthrottled is a wallet drain if hammered.

## Invariant 4 — Infrastructure stays inside Traba's perimeter

**[BLOCKER] Every git remote is Traba-Ops** (`git remote -v`) — not a personal account, including forks with a personal `origin`.

**[BLOCKER] Railway project under the Traba team; Postgres TCP proxy disabled.** Not verifiable from the repo — walk the operator through confirming both in the Railway dashboard (project → team ownership; database service → Settings → Networking) and get the answer back, don't just ask "is it fine?". Details in the deployment skill.

**[BLOCKER] Worker-facing sends stamp attribution.** Prefer the comms broker via the worker-outreach API (`POST /v1/worker-outreach/request` with a registered `sourceType` topic, authenticated as the acting recruiter). Raw OpenPhone/Quo sends are acceptable only with the sender's `userId` in every payload — an omitted `userId` silently attributes to the phone-number owner. Full policy: `~/.claude/docs/worker-comms-safety.md`.

```bash
git grep -nE "api\.openphone\.com/v1/messages" -- apps/ scripts/
```

Every hit is a send and must carry `userId` in the payload. Broker sends (`/v1/worker-outreach/request`, or the older `/communication/send-direct-two-way-sms`) handle attribution themselves, and prep calls (`/v1/users` lookups, list-building) are out of scope — never block prep work.

**[advisory] CI safety net present.** `.github/workflows/` includes a gitleaks scan — operators push straight to main, so CI is the enforcement layer (`~/.claude/docs/security.md`).

## Post-deploy probe

After the deploy is live, probe unauthenticated — read-only GETs only:

1. Take the route list from invariant 3 and hit **each data endpoint** without credentials — expect 401/403 on every one. A 200 on the app root proves nothing (the SPA shell is public by design); the data endpoints are the test.
2. Vite apps: fetch the built bundles and scan them with the same pattern set as the history check. Bundle filenames are hashed and `curl` doesn't expand remote globs — enumerate the paths from the served page first:

```bash
paths=$(curl -s https://<app>/ | grep -oE '/assets/[^"]+\.js' | sort -u)
[ -n "$paths" ] || echo "NO BUNDLES FOUND — wrong URL, deploy not ready, or assets served elsewhere"
for js in $paths; do
  curl -s "https://<app>$js"
done | grep -oE "sk-ant-[A-Za-z0-9_-]+|sk-proj-|sk_live_|pk_live_|ghp_[A-Za-z0-9]{36}|github_pat_|xox[baprs]-|AIza[0-9A-Za-z_-]{35}|postgres(ql)?://[^:]+:[^@]+@[^\"']+"
```

An empty enumeration is a **failed scan, not a clean one** — resolve why no bundles were found and re-run before reporting this check as passed. Anything the grep finds traces back to a `VITE_` leak.

Anything serving data or secrets unauthenticated: treat as a blocker — fix before announcing the app.

## Verdict and scorecard

Report to the operator in plain language:

```
Pre-flight check — <project> — <date>

Blockers: <none, or each with file:line and the fix>
Advisories: <each with a recommended fix>

Verdict: CLEAR TO DEPLOY | BLOCKED (<n> blockers)
```

If blocked: fix the blockers, re-run the failed checks, report again.

For Slack (the bq-auth allowlist request, or any thread where the app's compliance is the question), condense to a scorecard — one line per invariant, advisories counted:

```
Pre-flight check — <app> — <date> — *CLEAR*
:white_check_mark: secrets: clean (tree + history + bundle)
:white_check_mark: data access: traba-auth only, nothing at rest
:white_check_mark: auth: all data routes gated (live probe runs post-deploy)
:white_check_mark: infra: Traba-Ops repo, Traba Railway
:warning: advisories: <n> (<short labels>)
```

Never send an allowlist request while blockers are open.

## Not covered

This check audits the repo and its deploy. It does not audit Railway config beyond the checks above, scheduled jobs living outside the repo, other repos, or vendor consoles. The deterministic layers — gitleaks pre-commit, CI, GitHub push protection (`~/.claude/docs/security.md`) — run alongside this check, not instead of it.
