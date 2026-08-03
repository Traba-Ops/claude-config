# Prometheus Eng Runbook: Deploying an Operator's App

You've been assigned as a Claude buddy for an operator who built something locally and wants to deploy it. This guide walks you through the process.

The time commitment on your end should be minimal, and it's a great opportunity to build relationships and understand parts of the business you don't normally touch.

## What You Need to Know

**Prometheus** is our framework that lets non-engineers build and deploy tools with Claude Code. The operator has already installed the Prometheus skills (claude-config) and has been building a local app. Your job is to get their app from their laptop to a URL at `something.traba.work` with Traba Google login.

**The stack:** TypeScript monorepo (Hono backend + React frontend) on bun, deployed to Railway, in-app Google OAuth for auth. See the [prescriptive stack](stack.md) for full details.

**Your role:** Infrastructure and access. The operator and their Claude handle the code.

---

## Step 1: Understand What They Built

Have a quick chat, but wear your PM hat. Don't just confirm it's a real tool. Try to understand:

- **What problem are they solving?** What's painful about the current workflow?
- **Why does it matter?** Who benefits and how much time/effort does it save?
- **Who's going to use it?** Just them, their team, cross-functional?
- **Can they demo it?** Ask them to run it locally and show you. If it doesn't run, it's not ready to deploy.
- **Does it need any API keys?** If it needs an LLM, we prefer Gemini for cost effectiveness — ask Jeff or Moreno for a key.
- **Ask for the pre-flight scorecard.** The operator's Claude runs the **deploy-preflight-check skill** (part of the bundle) and produces a per-invariant scorecard. Review it before investing deploy time: open blockers mean it's not ready, and the advisories tell you where to look during your review.

---

## Step 2: Get Their Code on GitHub

### Get them into Traba-Ops

If they're not already in the Traba-Ops GitHub org, get their username and invite them via the GitHub UI.

### Push the code

Have them prompt Claude Code:

> "Push my code to GitHub"

Claude will create the repo in the right org and configure visibility. If they already pushed to a personal GitHub repo, walk them through transferring ownership to Traba-Ops via the GitHub UI (repo Settings → Transfer).

### Verify

Quick sanity check:

- [ ] Repo exists at `github.com/Traba-Ops/<repo-name>` and **has code** (not empty — this has happened)
- [ ] Repo has a **README.md**. If missing, have them prompt:
  > "Add a README that explains what this app does, who it's for, and how to run it locally"

---

## Step 3: Set Up Auth

**Auth must be working locally before anything goes to Railway.** An unprotected Railway deploy puts the app on the public internet with no login.

**In-app Google OAuth is the standard.** Cloudflare Zero Trust was retired due to the hard 50-seat limit on the free tier. Legacy apps may still use it, but all new apps should use in-app OAuth.

### Create the OAuth Client ID

1. Go to [GCP Console](https://console.cloud.google.com/) → **traba-app** project → **APIs & Services → Credentials**
2. Click **+ Create Credentials → OAuth client ID**
3. Application type: **Web application**
4. Name: something descriptive (e.g., `mycelium`, `onboarding-funnel`)
5. Add **Authorized JavaScript origins**:
   - `http://localhost:5173` (Vite dev server)
   - `http://localhost:3000` (backend dev server)
   - `https://appname.traba.work` (production domain — add now so it's ready for deploy)
6. Leave **Authorized redirect URIs** empty (not needed for implicit grant)
7. Copy the **Client ID** and give it to the operator

**Note:** The OAuth consent screen on `traba-app` is already configured as **Internal** (restricted to `traba.work` Workspace). If it weren't, you'd need to set that up first — External would allow any Google account.

**Important:** Do NOT use `gcloud alpha iap oauth-clients create` — those create locked IAP clients that can't have JavaScript origins added. Must use the Console UI.

### Send the Client ID to the operator

The Client ID is not a secret — it's baked into the frontend JS and visible to anyone who views source. Just send it to the operator directly (Slack, etc.). They'll give it to Claude, who writes the `.env.local`.

**Don't send them the full downloaded JSON** — it also contains a `client_secret` which isn't used in the Prometheus auth flow but is still sensitive. Only share the Client ID string (ends in `.apps.googleusercontent.com`).

### Operator builds auth locally

The operator gives the Client ID to Claude, who sets up their `apps/web/.env.local` and adds auth using the authentication skill.

### Verify before moving on

Once they've built it, verify locally:
- [ ] Google login popup appears and works with a `@traba.work` account
- [ ] The server checks `hd === "traba.work"` from Google's userinfo API (not client-side)
- [ ] `/api/auth` routes are mounted before `requireAuth` middleware
- [ ] Non-`@traba.work` accounts are rejected
- [ ] API routes return 401 without a valid session

**Don't proceed to deployment until auth is working locally.** This is the most common source of "app is publicly accessible with no login" incidents.

---

## Step 4: Deploy to Railway

### Invite them to the Railway team

Add them to the **Traba Railway team** — not a personal account. If they already deployed on a personal account (this has happened), they'll need to move to the team.

### Set env vars before the first deploy

Set these Railway env vars before the first deploy:
- `VITE_GOOGLE_CLIENT_ID` — the Client ID from Step 3 (must be set before first deploy — it's a build-time variable baked into the frontend JS)
- `SESSION_SECRET` — generate with `openssl rand -hex 32` and **seal it** after setting

### Deploy

Have them prompt:

> "Deploy my app to Railway"

### Connect the custom domain

Once the Railway project exists:

1. Go to Railway project → Settings → Networking → Custom Domains
2. Add: `appname.traba.work`
3. Railway shows a CNAME record — use the one-click button to add it to Cloudflare, or manually add the CNAME in Cloudflare DNS
4. Wait a few minutes for DNS
5. Visit `appname.traba.work` — you should see Google login
6. Log in and verify the app loads

**If the deploy fails**, have them prompt:

> "Monitor the Railway deploy logs, diagnose any failures, fix the issues, and redeploy. Keep going until the app is live and healthy."

---

## Step 5: Add Secrets (If Needed)

If the app needs API keys or credentials, have them prompt:

> "Add these environment variables to my Railway project: [KEY=value, ...]"

You may need to provide the actual key values (e.g., a Gemini API key from Jeff/Moreno).

---

## Step 6: Verify the Full Loop

Walk through this with the operator:

1. **Visit `appname.traba.work`** → Google login appears
2. **Log in with `@traba.work` email** → app loads correctly
3. **Operator makes a small change** and runs: "Deploy my changes"
4. **Change appears** on the live URL after Railway redeploys (1-2 minutes)
5. **Operator reverts the change:** "Revert my last change and redeploy"

If all five work, they're set. Push to main auto-deploys from here.

---

## Optional: Polish the App

Once it's deployed and working, if the UI could use some love, have them prompt:

> "Use the Traba design skill to restyle the app"

---

## Optional Detour: Data Access (BigQuery)

If the app needs Traba data, there are two sanctioned paths — pick by shape:

- **Analytics / warehouse queries (BigQuery):** the **bq-auth skill**. The app authenticates users through the traba-auth proxy (`data-proxy.traba.work`) and every query runs under the requesting user's own permissions. Your part as the engineer: send the #data message to add the app's origin to `ALLOWED_REDIRECT_ORIGINS` (the skill has the template).
- **Live ops data or ops actions (node backend):** the **ops-backend-auth skill**. An engineer creates a GCP service account (zero IAM roles) that mints ID tokens for `ops-prod.traba.tech`, gated by a per-route allow-list in the `service_account_scopes` Statsig config.

**Never provision a BQ service-account key for an app.** Direct service-account access bypasses per-user permissions — it's the pattern traba-auth exists to prevent.

---

## Operator Prompt Cheat Sheet

Ready-made prompts to send the operator. They run these in Claude Code.

| Task | Prompt |
|------|--------|
| Push code to GitHub | "Push my code to GitHub" |
| Add a README | "Add a README that explains what this app does, who it's for, and how to run it locally" |
| Deploy to Railway | "Deploy my app to Railway" |
| Deploy changes | "Deploy my changes" |
| Fix deploy failure | "Monitor the Railway deploy logs, diagnose any failures, fix the issues, and redeploy. Keep going until the app is live and healthy." |
| Add env vars | "Add these environment variables to my Railway project: [KEY=value]" |
| Revert a change | "Revert my last change and redeploy" |
| Restyle with Traba design | "Use the Traba design skill to restyle the app" |
| Checkpoint | "Checkpoint this" |

---

## Quick Reference

| Service | URL | Who can set up |
|---------|-----|---------------|
| GitHub (Traba-Ops) | github.com/Traba-Ops | Any eng with org admin |
| Railway (Traba team) | railway.com | Any eng on the team |
| GCP OAuth (traba-app) | console.cloud.google.com | Any eng on the project |
| Cloudflare DNS | dash.cloudflare.com | Any eng on the team |
| Railway Postgres | railway.com (add DB in project) | Any eng on the team |
