---
name: bq-auth
description: |
  BigQuery access via the traba-auth proxy service. Use when: (1) an app needs
  to query BigQuery data, (2) user asks about data access or Traba business data,
  (3) user needs to authenticate users for BigQuery queries.
version: 1.3.0
---

# BigQuery Auth (traba-auth)

Traba apps never hold GCP credentials directly. Instead, they authenticate users through **traba-auth**, a centralized proxy that executes BigQuery queries on behalf of authenticated users using their own Google OAuth tokens. This ensures queries run as the user (proper RBAC), credentials stay centralized, and audit logs reflect the real requester.

**Service URL:** `https://traba-auth-production-caf5.up.railway.app`

## How It Works

1. App redirects the user to traba-auth's login endpoint
2. User authenticates with their `@traba.work` Google account (OAuth)
3. traba-auth issues a JWT and redirects back to the app with `?token=<jwt>`
4. App stores the JWT and sends it as a `Bearer` token on all `/query` requests
5. traba-auth validates the JWT, loads the user's Google OAuth tokens, and executes the query via BigQuery

JWTs expire after 60 minutes. BigQuery credentials are refreshed automatically server-side — users only need to re-authenticate when their JWT expires. If a `/query` request returns 401, clear the stored token and restart the login flow.

## Production Setup — Required Before Deploying

The traba-auth OAuth client must whitelist the app's production callback URL before login will work in production. **This is a one-time step per app and must be done before the first deploy.**

When the operator is ready to deploy, send a message in **#data** on Slack:

> Hey @charles — can you whitelist `https://<app-url>.railway.app/` as an allowed OAuth redirect URI in traba-auth? Deploying a new app that uses it for BigQuery auth.

Do not skip this step or deploy without it — OAuth redirects will silently fail until the URL is whitelisted.

## API

### `GET /auth/login?redirect_uri=<url>`
Redirect the user here to start OAuth. After login, traba-auth redirects to `redirect_uri?token=<jwt>`. If the user's Google account is not a `@traba.work` account, it redirects to `redirect_uri?error=unauthorized` instead — handle this in the callback.

### `POST /query`
Execute a BigQuery query.

**Headers:**
- `Authorization: Bearer <jwt>` — required
- `X-App-Name: <your-app-name>` — required for audit logging; added as a SQL comment in BigQuery logs

**Body:**
```json
{
  "sql": "SELECT * FROM `project.dataset.table` WHERE id = ?",
  "params": ["some-value"]
}
```

**Response (success):**
```json
{ "rows": [...] }
```

**Response (401 — JWT expired or invalid):**
```json
{ "message": "Not authenticated", "login_url": "https://traba-auth-production-caf5.up.railway.app/auth/login" }
```

Use `?` placeholders for dynamic values when possible. Note: traba-auth treats all `?` parameters as `STRING` type. For non-string values (integers, floats, arrays) or BigQuery named parameters (`@name`), inline the values into the SQL string with proper escaping instead of using `params`.

## Streamlit Integration

Streamlit is the most common app type. Store the JWT in `st.session_state`.

```python
import streamlit as st
import httpx

import os

TRABA_AUTH_URL = os.getenv("TRABA_AUTH_URL", "http://localhost:8000")  # defaults to local traba-auth for dev
APP_NAME = "your-app-name"  # use a short, descriptive name for audit logs
APP_URL = os.getenv("APP_URL", "http://localhost:8501")  # set APP_URL env var in Railway

def require_auth():
    """Call at the top of every page. Returns when user is authenticated."""
    if "token" not in st.session_state:
        error = st.query_params.get("error")
        token = st.query_params.get("token")
        if error == "unauthorized":
            st.query_params.clear()
            st.error("Access restricted to @traba.work accounts.")
            st.stop()
        elif token:
            st.session_state.token = token
            st.query_params.clear()
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
        timeout=60,
    )
    if resp.status_code == 401:
        del st.session_state["token"]
        st.error("Session expired — please sign in again.")
        st.stop()
    resp.raise_for_status()
    return resp.json()["rows"]

# Usage
require_auth()
rows = run_query("SELECT shift_id, status FROM `traba-data.marts.shifts` WHERE date = ?", ["2026-04-01"])
```

## TypeScript Integration

For Hono/bun backends, store the JWT in the session (cookie or client-side storage) after the OAuth callback.

```typescript
const TRABA_AUTH_URL = "https://traba-auth-production-caf5.up.railway.app";
const APP_NAME = "your-app-name";

// Redirect user to login
app.get("/auth/login", (c) => {
  const redirectUri = `${process.env.APP_URL}/auth/callback`;
  return c.redirect(`${TRABA_AUTH_URL}/auth/login?redirect_uri=${redirectUri}`);
});

// Handle callback — token arrives as ?token=<jwt>, or ?error=unauthorized for non-@traba.work accounts
app.get("/auth/callback", (c) => {
  if (c.req.query("error") === "unauthorized") {
    return c.text("Access restricted to @traba.work accounts.", 403);
  }
  const token = c.req.query("token");
  if (!token) return c.text("Auth failed", 400);
  // Store token in session cookie or return to client
  setCookie(c, "token", token, { httpOnly: true, sameSite: "Lax" });
  return c.redirect("/");
});

// Query helper
async function queryBQ(sql: string, params: string[], token: string): Promise<Record<string, unknown>[]> {
  const resp = await fetch(`${TRABA_AUTH_URL}/query`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "X-App-Name": APP_NAME,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ sql, params }),
  });
  if (!resp.ok) throw new Error(`BQ query failed: ${resp.status}`);
  const data = await resp.json() as { rows: Record<string, unknown>[] };
  return data.rows;
}
```

## Backend Token Validation (FastAPI)

When the app has a backend that receives tokens from a frontend client, validate the token by calling `/auth/me` rather than verifying the JWT locally. Store the token in a `ContextVar` so the service layer can use it without threading it through every function signature.

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
    resp.raise_for_status()
    return resp.json()["rows"]

# Usage in a route
@app.get("/data")
def get_data(current_user: dict = Depends(require_user)):
    rows = proxy_query("SELECT * FROM `traba-data.marts.shifts` LIMIT 100")
    return {"rows": rows, "user": current_user["email"]}
```

## Rules

- **Always** set `X-App-Name` on every request — it's how queries get attributed in BigQuery audit logs
- **Never** store GCP credentials in the app — all data access goes through traba-auth
- `?` params are STRING-only — inline non-string values (ints, floats, arrays) with proper escaping
- Use a 30s timeout on `/query` requests — BigQuery queries on large tables are slow
- Use a 5s timeout on `/auth/me` validation calls
- Handle 401 on `/query` by showing "Session expired — please sign in again" and stopping (don't silently rerun)
- Store `TRABA_AUTH_URL` as an env var; default to `http://localhost:8000` so local dev works without extra config
- For backends: validate tokens via `/auth/me`, not local JWT parsing — traba-auth is the authority
