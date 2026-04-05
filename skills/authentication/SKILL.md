---
name: authentication
description: |
  Google OAuth authentication for Traba apps. Use when: (1) adding login to a new or existing app,
  (2) user asks about auth, sessions, or access control.
  Covers: Google OAuth setup, server-side verification, session JWTs, domain restriction.
version: 1.0.0
---

# Authentication

Google OAuth restricted to `@traba.work` accounts. The frontend handles the Google login popup, the backend verifies the token and issues a session JWT. All security decisions happen server-side.

**Reference implementation:** [Traba-Ops/prometheus-observatory](https://github.com/Traba-Ops/prometheus-observatory) — see `web/serve.ts`, `web/src/LoginPage.tsx`, and `decisions/` for rationale.

## Architecture

```
User clicks "Sign in with Google"
  → Google popup (filtered to @traba.work)
  → Google returns access token to frontend
  → Frontend sends access token to POST /api/auth/verify
  → Backend calls Google userinfo API, checks hd === "traba.work"
  → Backend issues 7-day session JWT (signed with jose)
  → Frontend stores session JWT in localStorage
  → All subsequent /api/* requests use Authorization: Bearer <session JWT>
  → Backend verifies session JWT on each request (fast, no external call)
```

## Dependencies

Install in the **frontend** (`apps/web/`):
```bash
cd apps/web && bun add @react-oauth/google
```

Install in the **backend** (`apps/api/`):
```bash
cd apps/api && bun add jose
```

## GCP Setup

OAuth Client IDs for web apps **cannot be created via `gcloud` CLI** — the IAP commands create locked clients that can't have JavaScript origins added. Use the GCP Console:

1. Go to **console.cloud.google.com** → **traba-app** project → **APIs & Services → Credentials**
2. **+ Create Credentials → OAuth client ID** → type: **Web application**
3. Add **Authorized JavaScript origins**: localhost ports + the production Cloudflare domain
4. No redirect URIs needed (implicit grant uses popup, not redirects)
5. The OAuth consent screen must already exist and be set to **Internal** (restricts to `traba.work` Workspace)

**Gotcha:** If the consent screen isn't configured, GCP prompts you to create one. Choose "Internal" — "External" would allow any Google account and require a review process.

## Environment Variables

| Variable | Where | Seal? | Notes |
|----------|-------|-------|-------|
| `VITE_GOOGLE_CLIENT_ID` | Build time (Vite) | No | Public by design — baked into frontend JS bundle |
| `SESSION_SECRET` | Runtime (backend) | Yes | `openssl rand -hex 32` to generate |

**Gotcha:** `VITE_*` vars are inlined at build time, not read at runtime. If you set `VITE_GOOGLE_CLIENT_ID` on Railway after the first deploy, run `railway redeploy` — a restart won't pick it up. Missing this causes a blank page with no visible error (the throw happens client-side).

## Backend (Hono)

### Auth middleware

```typescript
// apps/api/src/auth.ts
import { createMiddleware } from "hono/factory";
import { SignJWT, jwtVerify } from "jose";

const SESSION_SECRET = new TextEncoder().encode(
  process.env.SESSION_SECRET || "dev-secret"
);

export const requireAuth = createMiddleware(async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) return c.json({ error: "Unauthorized" }, 401);
  try {
    const { payload } = await jwtVerify(header.slice(7), SESSION_SECRET);
    c.set("user", payload);
    await next();
  } catch {
    return c.json({ error: "Unauthorized" }, 401);
  }
});
```

### Auth routes

```typescript
// apps/api/src/routes/auth.ts
import { Hono } from "hono";
import { SignJWT } from "jose";

const auth = new Hono();

auth.post("/verify", async (c) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) return c.json({ error: "Missing token" }, 401);

  // Verify Google access token via userinfo API
  const res = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
    headers: { Authorization: header },
  });
  if (!res.ok) return c.json({ error: "Invalid token" }, 401);

  const info = await res.json();
  if (info.hd !== "traba.work")
    return c.json({ error: "Access restricted to @traba.work accounts" }, 401);

  // Issue session JWT
  const token = await new SignJWT({ email: info.email, name: info.name, picture: info.picture })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime("7d")
    .setIssuedAt()
    .sign(SESSION_SECRET);

  return c.json({ email: info.email, name: info.name, picture: info.picture, token });
});

export default auth;
```

### Wiring it up

```typescript
// apps/api/src/index.ts
import { Hono } from "hono";
import { requireAuth } from "./auth";
import authRoutes from "./routes/auth";

const app = new Hono();

// Auth routes (no middleware — this is how you GET a session)
app.route("/api/auth", authRoutes);

// Protected routes
app.use("/api/*", requireAuth);
app.get("/api/data", (c) => { /* ... */ });

// Static files + SPA fallback (no auth)
```

**Route order matters.** Mount `/api/auth` before the `requireAuth` middleware, otherwise the login endpoint itself requires a session.

## Frontend

### Provider setup

```typescript
// apps/web/src/main.tsx
import { GoogleOAuthProvider } from "@react-oauth/google";

const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;
if (!clientId) throw new Error("VITE_GOOGLE_CLIENT_ID environment variable is required");

// Wrap <App /> with <GoogleOAuthProvider clientId={clientId}>
```

### Login page

Use `useGoogleLogin` hook with `hosted_domain: 'traba.work'`:

```typescript
const login = useGoogleLogin({
  onSuccess: async (response) => {
    const res = await fetch("/api/auth/verify", {
      method: "POST",
      headers: { Authorization: `Bearer ${response.access_token}` },
    });
    // res.json() returns { email, name, picture, token }
    // Store token (session JWT) and user info in localStorage
  },
  hosted_domain: "traba.work",
});
```

**Gotcha:** `useGoogleLogin` returns an **access token** (opaque string), not a JWT. You cannot decode it client-side for user info — the server must call Google's userinfo API and return the info.

**Gotcha:** `hosted_domain` is a UX hint that filters the Google account picker. It is not security enforcement — Google does not guarantee it. The server must check `hd` from the userinfo response.

### Auth state

- Store the session JWT and user display info (name, picture, email) in localStorage
- On app load, check localStorage for an existing session — if present, skip the login page
- On 401 from any API call, clear localStorage and show login
- Logout: clear localStorage, call `googleLogout()` from `@react-oauth/google`

**Gotcha:** Google profile image URLs reject requests with external referrers. Add `referrerPolicy="no-referrer"` to avatar `<img>` tags.

### Vite dev proxy

The frontend dev server (Vite on :5173) needs to proxy `/api/*` to the backend (Hono on :3000):

```typescript
// apps/web/vite.config.ts
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: { "/api": "http://localhost:3000" },
  },
});
```

Both servers must be running during development.

## Security Model

| Layer | What it does |
|-------|-------------|
| `hosted_domain: 'traba.work'` | UX convenience — filters Google account picker |
| Google userinfo API `hd` check | Server enforcement — rejects non-traba.work domains |
| Session JWT (jose, HS256, 7-day) | Stateless session — no external API calls after login |
| `requireAuth` middleware | Gates all `/api/*` routes except auth endpoints |
| SPA shell served without auth | Login page must load — the shell code is not sensitive |

**The server is the sole security authority.** The client never validates domain or token authenticity. It stores tokens for UX (display user info, detect expiry) and defers to 401 responses from the server.

## Checklist

Before deploying an app with auth:

- [ ] OAuth Client ID created in GCP Console (`traba-app` project, Internal consent screen)
- [ ] Authorized JavaScript origins include production Cloudflare domain + localhost ports
- [ ] `VITE_GOOGLE_CLIENT_ID` set as Railway env var (set **before** first deploy)
- [ ] `SESSION_SECRET` set as Railway env var and **sealed**
- [ ] `/api/auth/verify` mounted before `requireAuth` middleware
- [ ] Server checks `hd === "traba.work"` from Google userinfo response
- [ ] Vite proxy configured for local development
- [ ] Tested with `@traba.work` account (login works) and non-Traba account (rejected)
