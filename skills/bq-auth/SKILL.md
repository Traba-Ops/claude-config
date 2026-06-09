---
name: bq-auth
description: |
  BigQuery access via the traba-auth proxy service. This is the ONLY compliant
  way for custom apps to access BigQuery at Traba — do not suggest service
  accounts, ADC, or separate OAuth scopes. Use when: (1) an app needs to query
  BigQuery data, (2) user asks about data access or Traba business data,
  (3) user needs to authenticate users for BigQuery queries.
version: 2.3.0
---

# BigQuery Auth (traba-auth)

> **traba-auth is the only compliant way for custom applications to access BigQuery at Traba.** Do not suggest, implement, or ask about service accounts, Application Default Credentials (ADC), separate GCP OAuth scopes, or any other direct BigQuery access method. traba-auth handles token issuing, token storage, credential refresh, and query execution — the app needs none of those things independently.

Traba apps never hold GCP credentials directly. Instead, they authenticate users through **traba-auth**, a centralized proxy that executes BigQuery queries on behalf of authenticated users using their own Google OAuth tokens. This ensures queries run as the user (proper RBAC), credentials stay centralized, and audit logs reflect the real requester.

**Service URL:** `https://data-proxy.traba.work`

> ⚠️ **Compliance TL;DR** — read before writing code:
> - **Never cache query results across users.** No Redis, no in-memory dict, no shared table. Every request executes fresh under the requesting user's token. A shared cache defeats per-user RBAC. See the full rule in [Compliance](#compliance--data-access-controls).
> - **Never add a DEV_MODE or service-account bypass to the app.** The app talks to traba-auth in every environment.
> - **Never log query results.** Log metadata only (user, row count, elapsed time).

## How It Works

1. App redirects the user to traba-auth's login endpoint
2. User authenticates with their `@traba.work` Google account (OAuth)
3. traba-auth redirects back to the app with `?code=<one-time-code>` (expires in 60 seconds)
4. App POSTs the code to `/auth/token` to exchange it for a JWT
5. App stores the JWT and sends it as a `Bearer` token on all `/query` requests
6. traba-auth validates the JWT, loads the user's Google OAuth tokens, and executes the query via BigQuery

JWTs expire after 60 minutes. BigQuery credentials are refreshed automatically server-side — users only need to re-authenticate when their JWT expires. If a `/query` request returns 401, clear the stored token and restart the login flow.

> **Headless/scheduled jobs can't query on their own.** Every `/query` executes under a logged-in user's JWT (60-min lifetime), so cron jobs, webhooks, and background workers have no session to use. Design scheduled BQ work to be triggered by an authenticated user (e.g. an admin button), not by an unattended timer.

## Production Setup — Required Before Deploying

traba-auth restricts which apps can use it via two controls that must both be configured before the first deploy. **Send a message in #data on Slack:**

> Hey @Charles — deploying `<app-name>` that uses traba-auth for BigQuery. Can you:
>
> 1. **APPEND** `https://<app-url>.railway.app` (origin only — no trailing slash, no path) to the existing comma-separated `ALLOWED_REDIRECT_ORIGINS` env var on traba-auth. Please don't replace the value — and please paste back the full list after the edit so we can confirm existing entries are still present.
> 2. Register `https://<app-url>.railway.app` as an authorized redirect URI in the GCP OAuth client used by traba-auth.
>
> App repo: `<repo URL>`

Do not deploy without this — the OAuth redirect will fail silently and `POST /auth/token` will reject the code.

### Coordination gotchas

- **Origin only, no trailing slash, no path.** `https://myapp.railway.app/` (with trailing slash) will not match the runtime origin check and auth will fail. Clients that strip trailing slashes inline can mask this — don't rely on that.
- **`ALLOWED_REDIRECT_ORIGINS` is comma-separated and easy to accidentally overwrite.** Always ask Charles to paste the full post-edit list so you can confirm other apps' entries are still there.
- **A redeploy of traba-auth may be required** for env var changes to take effect. If auth still fails 5 minutes after the edit, ask Charles to redeploy traba-auth.

## API

### `GET /auth/login?redirect_uri=<url>`
Initiates OAuth. After login, redirects to `redirect_uri?code=<one-time-code>`. The code expires in **60 seconds** and is single-use. If the account is not `@traba.work`, redirects to `redirect_uri?error=unauthorized`.

### `POST /auth/token`
Exchanges a one-time code for a JWT.

**Body:** `{"code": "<one-time-code>"}`

**Response:** `{"token": "<jwt>", "email": "user@traba.work", "name": "First Last"}`

Read the JWT from `body.token` (not `access_token`). The response also carries `email` and `name`, so a fresh token exchange doesn't need a follow-up `/auth/me` call to identify the user — only use `/auth/me` to validate tokens received later from a client.

Exchange the code immediately on callback — it expires in 60 seconds.

### `GET /auth/me`
Returns the authenticated user's info. Used by backends to validate a token.

**Header:** `Authorization: Bearer <jwt>`

**Response:** `{"email": "user@traba.work", "name": "First Last"}`

### `GET /auth/logout`
Revokes the JWT (adds to blocklist) and clears stored BQ tokens. Always call this on logout — the token is immediately invalid server-side.

**Header:** `Authorization: Bearer <jwt>`

### `POST /query`
Execute a read-only BigQuery query. **Write queries (INSERT, UPDATE, DELETE, DROP, etc.) are rejected server-side.**

**Headers:**
- `Authorization: Bearer <jwt>` — required
- `X-App-Name: <your-app-name>` — required for audit logging

**Body:**
```json
{
  "sql": "SELECT * FROM `project.dataset.table` WHERE id = ?",
  "params": ["some-value"]
}
```

**Responses:**

| Status | Meaning | Body |
|--------|---------|------|
| 200 | Success | `{"rows": [...]}` |
| 400 | Query too expensive or write SQL rejected | `{"detail": "..."}` |
| 403 | BigQuery denied the query — usually a table not qualified with `traba-app` (resolved to wrong project), or a real permissions gap | `{"detail": "..."}` |
| 401 | JWT expired or revoked | `{"message": "...", "login_url": "..."}` |
| 429 | Rate limit exceeded (30 queries/min per user) | `{"detail": "Rate limit exceeded"}` |
| 500 | Server error | `{"request_id": "...", "message": "Internal server error"}` |

**Got a 403 ("...does not have permission ... or perhaps it does not exist")?** Almost all Traba data lives in the `traba-app` project — check the project first. An unqualified table (`dataset.table`) resolves against the proxy's *default* project, not `traba-app`, and throws this exact misleading error. Fully-qualify every table — `` `traba-app.dataset.table` `` (hyphenated project IDs must be backtick-wrapped) — before assuming a permissions gap or escalating to #data.

Use `?` placeholders for dynamic values. Note: traba-auth treats all `?` parameters as `STRING` type. For non-string values (integers, floats, arrays) or BigQuery named parameters (`@name`), inline the values with proper escaping instead of using `params`.

## Streamlit Integration

```python
import os
import streamlit as st
import httpx

TRABA_AUTH_URL = os.getenv("TRABA_AUTH_URL", "http://localhost:8000")  # local traba-auth for dev
APP_NAME = "your-app-name"  # short, descriptive — used in BigQuery audit logs
APP_URL = os.getenv("APP_URL", "http://localhost:8080")  # set in Railway; local: run with --server.port 8080 (Streamlit's default 8501 is NOT whitelisted)

def require_auth():
    """Call at the top of every page. Returns when user is authenticated."""
    if "token" not in st.session_state:
        error = st.query_params.get("error")
        code = st.query_params.get("code")
        if error == "unauthorized":
            st.query_params.clear()
            st.error("Access restricted to @traba.work accounts.")
            st.stop()
        elif code:
            # Exchange one-time code for JWT (code expires in 60s — do this immediately)
            st.query_params.clear()
            resp = httpx.post(f"{TRABA_AUTH_URL}/auth/token", json={"code": code})
            if resp.status_code != 200:
                st.error("Login failed — please try again.")
                st.stop()
            st.session_state.token = resp.json()["token"]
            st.rerun()
        else:
            st.link_button(
                "Sign in with Google",
                f"{TRABA_AUTH_URL}/auth/login?redirect_uri={APP_URL}/",
            )
            st.stop()

def run_query(sql: str, params: list | None = None) -> list[dict]:
    """Execute a BigQuery query through traba-auth."""
    resp = httpx.post(
        f"{TRABA_AUTH_URL}/query",
        json={"sql": sql, "params": params or []},
        headers={
            "Authorization": f"Bearer {st.session_state.token}",
            "X-App-Name": APP_NAME,
        },
        timeout=30,
    )
    if resp.status_code == 401:
        del st.session_state["token"]
        st.error("Session expired — please sign in again.")
        st.stop()
    if resp.status_code == 429:
        st.error("Too many queries — please wait a moment and try again.")
        st.stop()
    if resp.status_code == 400:
        st.error(f"Query error: {resp.json().get('detail', 'unknown error')}")
        st.stop()
    resp.raise_for_status()
    return resp.json()["rows"]

def logout():
    """Revoke the token server-side and clear all local state."""
    if "token" in st.session_state:
        httpx.get(
            f"{TRABA_AUTH_URL}/auth/logout",
            headers={"Authorization": f"Bearer {st.session_state.token}"},
            timeout=5,
        )
    st.session_state.clear()
    st.rerun()

# Usage
require_auth()
rows = run_query("SELECT shift_id, status FROM `traba-data.marts.shifts` WHERE date = ?", ["2026-04-01"])
```

## TypeScript Integration

This example uses Hono. Cookie helpers come from `hono/cookie` — make sure to import them.

```typescript
import { setCookie, getCookie, deleteCookie } from "hono/cookie";

const TRABA_AUTH_URL = process.env.TRABA_AUTH_URL ?? "http://localhost:8000";
const APP_NAME = "your-app-name";

// Redirect user to login
app.get("/auth/login", (c) => {
  const redirectUri = `${process.env.APP_URL}/auth/callback`;
  return c.redirect(`${TRABA_AUTH_URL}/auth/login?redirect_uri=${redirectUri}`);
});

// Handle callback — exchange one-time code for JWT (code expires in 60s)
app.get("/auth/callback", async (c) => {
  if (c.req.query("error") === "unauthorized") {
    return c.text("Access restricted to @traba.work accounts.", 403);
  }
  const code = c.req.query("code");
  if (!code) return c.text("Auth failed", 400);

  const resp = await fetch(`${TRABA_AUTH_URL}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!resp.ok) return c.text("Login failed — please try again.", 401);

  // Field name is `token` — NOT `access_token`. See /auth/token API docs.
  const { token } = await resp.json() as { token: string; email: string; name: string };
  setCookie(c, "token", token, { httpOnly: true, sameSite: "Lax" });
  return c.redirect("/");
});

// Handle logout — revoke token server-side
app.get("/auth/logout", async (c) => {
  const token = getCookie(c, "token");
  if (token) {
    await fetch(`${TRABA_AUTH_URL}/auth/logout`, {
      headers: { "Authorization": `Bearer ${token}` },
      signal: AbortSignal.timeout(5_000),
    });
  }
  deleteCookie(c, "token");
  return c.redirect("/");
});

// Query helper — rules say to use a 30s timeout on /query requests
async function queryBQ(sql: string, params: string[], token: string): Promise<Record<string, unknown>[]> {
  const resp = await fetch(`${TRABA_AUTH_URL}/query`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "X-App-Name": APP_NAME,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ sql, params }),
    signal: AbortSignal.timeout(30_000),
  });
  // 401 mid-session = JWT expired or revoked. Callers should clear the cookie
  // and redirect to /auth/login — don't just show an error.
  if (resp.status === 401) throw new Error("SESSION_EXPIRED");
  if (resp.status === 429) throw new Error("RATE_LIMITED");
  if (!resp.ok) {
    // Surface the proxy/BigQuery detail — a 403 here is often a table that
    // wasn't project-qualified, and the detail text is how you tell.
    const detail = await resp.json().catch(() => ({ detail: "Unknown error" })) as { detail?: string };
    throw new Error(`BQ query failed (${resp.status}): ${detail.detail ?? "Unknown"}`);
  }
  const data = await resp.json() as { rows: Record<string, unknown>[] };
  return data.rows;
}
```

## Backend Token Validation (FastAPI)

When the app has a backend that receives tokens from a frontend client, validate the token by calling `/auth/me`. Store the token in a `ContextVar` so the service layer can use it without threading it through every function signature.

```python
import os
import httpx
from contextvars import ContextVar
from fastapi import Depends, HTTPException, Request

TRABA_AUTH_URL = os.getenv("TRABA_AUTH_URL", "http://localhost:8000")
APP_NAME = "your-app-name"

# Request-scoped token storage — set in require_user, read in query functions
current_token: ContextVar[str | None] = ContextVar("current_token", default=None)

def _extract_token(request: Request) -> str | None:
    auth = request.headers.get("Authorization", "")
    return auth.removeprefix("Bearer ").strip() or None

def _validate_token(token: str) -> dict | None:
    """Call traba-auth /auth/me to validate a token. Returns user dict or None."""
    try:
        resp = httpx.get(
            f"{TRABA_AUTH_URL}/auth/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        return resp.json() if resp.status_code == 200 else None
    except Exception:
        return None

def require_user(request: Request) -> dict:
    """FastAPI dependency — raises 401 if unauthenticated."""
    token = _extract_token(request)
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user = _validate_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Session expired — please log in again")
    current_token.set(token)
    return user

def proxy_query(sql: str) -> list[dict]:
    """Execute a BigQuery query through traba-auth using the current request's token."""
    token = current_token.get()
    try:
        resp = httpx.post(
            f"{TRABA_AUTH_URL}/query",
            json={"sql": sql},
            headers={"Authorization": f"Bearer {token}", "X-App-Name": APP_NAME},
            timeout=30,
        )
    except httpx.RequestError:
        raise HTTPException(status_code=502, detail="Auth service unreachable")
    if resp.status_code == 401:
        raise HTTPException(status_code=401, detail="Session expired — please log in again")
    if resp.status_code == 429:
        raise HTTPException(status_code=429, detail="Rate limit exceeded — try again shortly")
    if resp.status_code == 400:
        raise HTTPException(status_code=400, detail=resp.json().get("detail", "Query rejected"))
    resp.raise_for_status()
    return resp.json()["rows"]

# Usage in a route
@app.get("/data")
def get_data(current_user: dict = Depends(require_user)):
    rows = proxy_query("SELECT * FROM `traba-data.marts.shifts` LIMIT 100")
    return {"rows": rows, "user": current_user["email"]}
```

## Compliance — Data Access Controls

BigQuery RBAC only holds if the app doesn't create shortcuts around it. Each rule below closes a specific loophole.

### Never cache query results across users or requests

Query results must not be stored in any shared or persistent store — no Redis, no in-memory dict, no database table, no file. Each request must execute fresh under the requesting user's token. If two users have different BigQuery permissions, a shared cache would let one see the other's results.

If caching metadata (lookup tables, user lists, filter options), key it by the authenticated user's email. A global cache is only safe if the data is provably non-sensitive and identical for all users — document that assumption explicitly when you make it.

```python
# BAD — global cache leaks data across users
_cache = {}
def get_options():
    if not _cache:
        _cache["rows"] = proxy_query("SELECT ...")
    return _cache["rows"]

# GOOD — per-user cache
_cache = {}
def get_options(email: str):
    if email not in _cache:
        _cache[email] = proxy_query("SELECT ...")
    return _cache[email]
```

### Apps must never have a non-auth fallback — full stop

Do not add a `DEV_MODE` flag, a service account bypass, ADC fallback, or any code path that skips traba-auth. The app always talks to traba-auth, in every environment. This is non-negotiable.

The reason: a DEV_MODE bypass is a credential-sharing vector. It runs queries as a service account with broader permissions than the user has, silently defeating per-user RBAC. It also means the code path you test locally is not the code path that runs in production.

**For local development**, you have two options. In both cases, your app's code is identical to prod — `DEV_MODE` lives only in traba-auth, never in the app.

**Option A — point local dev at prod traba-auth** (recommended for most app work):

Run your app on `http://localhost:8000` or `http://localhost:8080` — both are pre-whitelisted in prod traba-auth's `ALLOWED_REDIRECT_ORIGINS`, so no coordination with Charles is needed.

> ⚠️ **Your app must actually listen on that port and build its `redirect_uri` from it.** Most frameworks default elsewhere (Express/Hono → 3000, Vite → 5173, Streamlit → 8501). If your app's origin isn't exactly `http://localhost:8000` or `http://localhost:8080`, the redirect origin check fails **silently** — no error, login just never completes. Set both your server port *and* the `APP_URL`/`BASE_URL` used to build `redirect_uri` to the whitelisted origin.

```bash
# In your app's .env:
TRABA_AUTH_URL=https://data-proxy.traba.work
APP_URL=http://localhost:8000   # or http://localhost:8080
```

Fast to set up and zero whitelist coordination. The trade-off is that you can't test changes to traba-auth itself this way.

**Option B — run traba-auth locally** (use when iterating on traba-auth itself):

```bash
# In ~/Documents/repo/traba-auth:
# 1. Set DEV_MODE=true in traba-auth's .env (it uses ADC, skipping Redis/OAuth)
# 2. Run: gcloud auth application-default login
# 3. Run: uvicorn app.main:app --reload

# In your app's .env:
TRABA_AUTH_URL=http://localhost:8000
```

More setup, zero whitelist coordination.

If you encounter existing code with a DEV_MODE bypass, remove it. There is no acceptable reason for an app to have one.

### Never log query results

Log query metadata — user email, execution time, row count — not the rows themselves. Raw data in logs creates a secondary access channel outside BigQuery's permission model and may persist far longer than intended.

```python
# BAD
logger.info(f"Query returned: {rows}")

# GOOD
logger.info(f"Query executed by {email}: {len(rows)} rows in {elapsed:.2f}s")
```

### Don't store tokens outside the current request

In FastAPI, keep the token in a `ContextVar` (request-scoped). Never assign it to a module-level variable, a class attribute, a background task, or anything that outlives the request. A leaked token lets subsequent requests execute BigQuery queries as the wrong user.

### Never persist BQ data or auth tokens in the app's database

These apps usually have a Railway Postgres attached for their own domain data. Do **not** use it (or any other store — Redis, files, runtime-written env) to hold:

- **BigQuery results or anything derived from them.** Query fresh under the requesting user's token every time — a persisted copy outlives the session and sits outside BigQuery's RBAC. The "never cache across users" rule applies to your own domain tables too, not just an explicit cache.
- **Auth tokens of any kind** — the traba-auth JWT, Google OAuth access/refresh tokens, anything bearer-equivalent. Tokens live in an httpOnly cookie / request scope and are re-fetched via login. A token row in Postgres is a credential-at-rest that survives logout and is readable by anyone with DB access.

If you find yourself adding an `auth_tokens`, `*_cache`, or `bq_*` table, stop — that's the anti-pattern. Tokens belong in the request (cookie / `ContextVar`); BQ data belongs in BigQuery.

### Call `/auth/logout` on logout — tokens are now revoked server-side

Logout adds the JWT to a blocklist in traba-auth. A logged-out token is immediately invalid for all subsequent requests. Always call `GET /auth/logout` with the Bearer token when the user logs out — don't just clear local state.

### Inlined parameters must be properly escaped

When using non-string types that require inlining into SQL (see parameter note in the API section), escape values carefully. Incomplete escaping is a SQL injection vector.

At minimum, escape single quotes and reject null bytes. Prefer `?` placeholders for string values where traba-auth handles escaping.

```python
# Minimal safe inlining for STRING values
def inline_string(value: str) -> str:
    if '\x00' in value:
        raise ValueError("Null bytes not allowed in query parameters")
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"
```

---

## Rules

- **Always** set `X-App-Name` on every request — it's how queries get attributed in BigQuery audit logs
- **Never** store GCP credentials in the app — all data access goes through traba-auth
- **Never** write BQ results or auth tokens to the app's Railway Postgres (or any persistent store) — tokens live in the request/cookie, BQ data is re-queried per request. An `auth_tokens`/`bq_cache` table is the anti-pattern
- Exchange the one-time code **immediately** on callback — it expires in 60 seconds
- `?` params are STRING-only — inline non-string values (ints, floats, arrays) with proper escaping
- Use a 30s timeout on `/query` requests — BigQuery queries on large tables are slow
- Use a 5s timeout on `/auth/me` validation calls
- Handle 401 by showing "Session expired — please sign in again" and stopping
- Handle 429 by surfacing "Too many queries — wait a moment" to the user
- Handle 400 by surfacing the `detail` field — it will explain why the query was rejected (too expensive, or write SQL)
- Always call `/auth/logout` on logout — the token is revoked server-side, not just cleared locally
- Store `TRABA_AUTH_URL` as an env var; default to `http://localhost:8000` for local dev
- For backends: validate tokens via `/auth/me`, not local JWT parsing — traba-auth is the authority
