---
name: authentication
description: |
  Google OAuth authentication for Traba apps. Use when: (1) adding login to a new or existing app,
  (2) user asks about auth, sessions, or access control.
  Covers: Google OAuth setup, server-side verification, session JWTs, domain restriction.
version: 1.2.0
---

# Authentication

Add Google OAuth login restricted to `@traba.work` accounts. The frontend handles the Google login popup, the backend verifies the token and issues a session JWT. All security decisions happen server-side.

## Before you start

### Project structure check

Authentication is designed for the prescribed monorepo structure from the project setup skill: `apps/web/` (React + Vite frontend), `apps/api/` (Hono backend), and `packages/shared/`. For new projects, match that structure — the reference implementation is Hono-specific and the skill's guidance assumes that stack.

Before adding auth to a new project, check the structure. If it doesn't match:
1. Tell the operator the project should be restructured first to support authentication
2. Offer to restructure it using the project setup skill
3. Once restructured, return to this skill to add auth

**Exception — existing apps on a non-prescribed stack.** If a legacy app uses Express + vanilla JS, FastAPI + HTMX, or another stack, do NOT force a restructure just to add auth. The **security model** is framework-agnostic — the token flow, server-side domain check, session JWT, Bearer header, and `/webhooks/*` exemption all apply regardless of stack. Port the reference implementation to whatever framework the app already uses. The requirements that matter:

- Server is the sole authority on who gets access (never trust client-side `hosted_domain`)
- `hd === 'traba.work'` check happens server-side against Google's userinfo API
- Session JWT signed with `SESSION_SECRET` (use `jose` on Node, or equivalent in other languages)
- All `/api/*` routes gated except `/api/auth/*`
- `/webhooks/*` exempt from JWT auth (they use HMAC signatures instead)
- Login screen lives in the static shell — SPA loads before auth

An example of the Express + vanilla JS port lives in `Traba-Ops/hunterxhunter` (`auth.js` module) for reference.

### GCP credentials

The operator needs a `VITE_GOOGLE_CLIENT_ID` from their engineer buddy before you can wire up the frontend. If they don't have one yet, tell them to ask their engineer to create a Google OAuth Client ID in the GCP Console (see the eng runbook). You can build everything else in the meantime — just leave the env var placeholder.

The Client ID is not a secret — it's baked into the frontend JS and visible to anyone who views source. The engineer will send it directly (Slack, etc.). Once the operator gives you the Client ID, write it to `apps/web/.env.local`:
```
VITE_GOOGLE_CLIENT_ID=<client_id>
```

## Architecture

```
User clicks "Sign in with Google"
  → Google popup (filtered to @traba.work)
  → Google returns access token to frontend
  → Frontend sends access token to POST /api/auth/verify
  → Backend calls Google userinfo API, checks hd === "traba.work"
  → Backend issues 7-day session JWT (signed with jose)
  → Frontend stores session JWT in localStorage

Page load (returning user):
  → Frontend reads JWT from localStorage
  → Frontend calls GET /api/auth/me with Bearer token
  → Backend verifies JWT, returns user profile (or 401)
  → Frontend sets auth state from server response (not localStorage)
  → On 401: clear localStorage, show login page

Authenticated requests:
  → All /api/* requests use Authorization: Bearer <session JWT>
  → Backend verifies session JWT on each request (fast, no external call)
```

### Why this architecture

Understand these trade-offs so you can explain them to the operator and make correct implementation choices:

**Server-side verification, not client-side.** Client-side domain checks are a UI gate, not a security boundary. Anyone can bypass the React app and hit the API directly. With the app publicly accessible on Railway, the server must be the sole authority on who gets access. Never put domain validation logic in the frontend.

**Session JWTs instead of the Google token directly.** Google access tokens from the implicit OAuth flow expire after ~1 hour. For a tool used throughout the work week, hourly re-login is disruptive. The server verifies the Google token once at login, then issues its own JWT with a 7-day expiry. After login, no external API calls are needed — `jose` verifies the JWT locally.

**localStorage + Bearer header instead of cookies.** HttpOnly cookies would let the server gate the entire site (including the SPA shell), but then the login page can't be a React component — it would have to be server-rendered HTML. Storing the session JWT in localStorage and sending it as a Bearer header keeps all UI in React. The trade-off: the SPA shell (HTML/JS/CSS) is publicly served, but it contains no sensitive data — only the API endpoints are gated.

**`@react-oauth/google` for the frontend.** Lightweight React wrapper over Google Identity Services. Minimal footprint, no extra backend framework needed.

**`jose` for JWTs.** Zero dependencies, TypeScript-first, works across Bun/Node/edge runtimes.

## Dependencies

Install in the correct workspace package:

- **Frontend** (`apps/web/`): `bun add @react-oauth/google`
- **Backend** (`apps/api/`): `bun add jose`

## Environment Variables

| Variable | Where | Seal? | Notes |
|----------|-------|-------|-------|
| `VITE_GOOGLE_CLIENT_ID` | Build time (Vite) | No | Provided by engineer. Public by design — baked into frontend JS |
| `SESSION_SECRET` | Runtime (backend) | Yes | Generate with `openssl rand -hex 32` |

## Backend

A complete, copy-paste-ready Hono auth module is at [hono-auth.reference.ts](hono-auth.reference.ts). Copy it to `apps/api/src/auth.ts` and adapt. It exports `requireAuth` middleware and `authRoutes` (the `/verify` endpoint).

Wire up in `apps/api/src/index.ts` — route order is critical:
```typescript
app.route("/api/auth", authRoutes);   // no middleware — this is how you GET a session
app.use("/api/*", requireAuth);       // everything else requires auth
```

## Frontend

Wrap the app in `<GoogleOAuthProvider clientId={clientId}>` in `main.tsx`. Throw if `VITE_GOOGLE_CLIENT_ID` is missing — this surfaces the error immediately instead of failing silently.

Use the `useGoogleLogin` hook from `@react-oauth/google` with `hosted_domain: 'traba.work'` for the login page.

Auth state lives in localStorage: session JWT + user display info (name, picture, email). On app load, verify the session server-side by calling `GET /api/auth/me` with the stored JWT — don't initialize auth state from localStorage alone. Set auth state only after the server confirms the session is valid. On 401 from `/auth/me` or any API call, clear localStorage and show the login page. Logout clears localStorage and calls `googleLogout()`.

## Gotchas

These are the things that cause failures on first attempt. Pay close attention:

**Vite env vars are build-time, not runtime.** `VITE_*` vars are inlined during the Vite build. If `VITE_GOOGLE_CLIENT_ID` is set on Railway after the initial deploy, `railway redeploy` is required — a restart won't pick it up. Missing this causes a blank page with no visible error.

**`useGoogleLogin` returns an access token, not a JWT.** The Google access token is an opaque string. You cannot decode it client-side for user info. The server must call Google's userinfo API and return the profile.

**`hosted_domain` is not security enforcement.** It filters the Google account picker UI but Google does not guarantee it. The server must check `hd` from the userinfo API response. Never rely on client-side domain filtering as a security measure.

**Route order matters in Hono.** Mount `/api/auth` routes before the `requireAuth` middleware, otherwise the login endpoint itself requires a session token and nobody can log in.

**Google profile images reject external referrers.** Add `referrerPolicy="no-referrer"` to avatar `<img>` tags.

**Don't initialize auth state synchronously from localStorage.** Always verify server-side first via `/api/auth/me`, then set state. Otherwise a page refresh with an expired JWT flashes the authenticated UI before bouncing to login.

**SPA shell must be public.** The React login page needs to load before the user can authenticate. Serve static files without auth. Only gate `/api/*` routes.

**Vite dev proxy required.** Frontend (Vite on :5173) and backend (Hono on :3000) run on different ports in dev. Add `server.proxy` in `vite.config.ts` to forward `/api/*` to the backend. Both servers must be running.

## Security Model

| Layer | What it does |
|-------|-------------|
| `hosted_domain: 'traba.work'` | UX convenience — filters Google account picker |
| Google userinfo API `hd` check | Server enforcement — rejects non-traba.work domains |
| Session JWT (jose, HS256, 7-day) | Stateless session — no external API calls after login |
| `/api/auth/me` endpoint | Session verification on page load — catches expired tokens before first API call |
| `requireAuth` middleware | Gates all `/api/*` routes except auth endpoints |
| SPA shell served without auth | Login page must load — the shell code is not sensitive |

**The server is the sole security authority.** The client never validates domain or token authenticity. It stores tokens for UX and defers to 401 responses from the server.
