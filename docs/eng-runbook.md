# Prometheus Eng Runbook: Deploying an Operator's App

You've been assigned as a Claude buddy for an operator who built something locally and wants to deploy it. This guide walks you through the process.

The time commitment on your end should be minimal, and it's a great opportunity to build relationships and understand parts of the business you don't normally touch.

## What You Need to Know

**Prometheus** is our framework that lets non-engineers build and deploy tools with Claude Code. The operator has already installed the Prometheus skills (claude-config) and has been building a local app. Your job is to get their app from their laptop to a URL at `something.traba.work` with Traba Google login.

**The stack:** TypeScript monorepo (Hono backend + React frontend) on bun, deployed to Railway, Cloudflare Zero Trust for auth. See the [prescriptive stack](stack.md) for full details.

**Your role:** Infrastructure and access. The operator and their Claude handle the code.

---

## Step 1: Understand What They Built

Have a quick chat, but wear your PM hat. Don't just confirm it's a real tool. Try to understand:

- **What problem are they solving?** What's painful about the current workflow?
- **Why does it matter?** Who benefits and how much time/effort does it save?
- **Who's going to use it?** Just them, their team, cross-functional?
- **Can they demo it?** Ask them to run it locally and show you. If it doesn't run, it's not ready to deploy.
- **Does it need any API keys?** If it needs an LLM, we prefer Gemini for cost effectiveness — ask Jeff or Moreno for a key.

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

## Step 3: Invite Them to Railway

Add them to the **Traba Railway team** — not a personal account. If they already deployed on a personal account (this has happened), they'll need to move to the team.

**Don't let them deploy yet.** Auth needs to be set up first (next step).

---

## Step 4: Set Up Auth

**Do this BEFORE they deploy.** An unprotected Railway deploy puts the app on the public internet with no login.

There are two auth methods. **In-app Google OAuth is preferred** — Cloudflare Zero Trust has a hard 50-seat limit across all Traba apps, so it doesn't scale as we add more tools and users.

### Option A: In-App Google OAuth (preferred)

The operator builds auth into the app using the authentication skill. You create the GCP credentials and verify the implementation.

**Create the OAuth Client ID:**

1. Go to [GCP Console](https://console.cloud.google.com/) → **traba-app** project → **APIs & Services → Credentials**
2. Click **+ Create Credentials → OAuth client ID**
3. Application type: **Web application**
4. Name: something descriptive (e.g., `mycelium`, `onboarding-funnel`)
5. Add **Authorized JavaScript origins**:
   - `http://localhost:5173` (Vite dev server)
   - `http://localhost:3000` (backend dev server)
   - `https://appname.traba.work` (production Cloudflare domain)
6. Leave **Authorized redirect URIs** empty (not needed for implicit grant)
7. Copy the **Client ID** and give it to the operator

**Note:** The OAuth consent screen on `traba-app` is already configured as **Internal** (restricted to `traba.work` Workspace). If it weren't, you'd need to set that up first — External would allow any Google account.

**Important:** Do NOT use `gcloud alpha iap oauth-clients create` — those create locked IAP clients that can't have JavaScript origins added. Must use the Console UI.

Give the operator the Client ID. They'll set it as `VITE_GOOGLE_CLIENT_ID` in their `.env.local` and prompt Claude to add auth. Once they've built it, verify:
- The server checks `hd === "traba.work"` from Google's userinfo API (not client-side)
- `/api/auth` routes are mounted before `requireAuth` middleware
- Non-`@traba.work` accounts are rejected

### Option B: Cloudflare Zero Trust (legacy)

Use when in-app auth isn't feasible. No code changes needed — Cloudflare gates the entire app as a reverse proxy.

1. Go to [Cloudflare Zero Trust](https://dash.cloudflare.com/) → Access → Controls → Applications
2. Click **Add an application** → Self-hosted
3. Configure:
   - **Application name:** Descriptive (e.g., `mycelium`, `onboarding-funnel`)
   - **Subdomain:** `appname` under `traba.work`
   - **Session duration:** 7 days
4. Add an Access Policy:
   - Select **"All traba.work"**
5. Under Login Methods:
   - Select **Google SSO**
   - Unselect One-time PIN
   - Toggle on **"Apply instant authentication"**

Look at existing apps (`mycelium`, `onboarding-funnel`) as templates.

---

## Step 5: Deploy + Connect Domain

**If using in-app Google OAuth (Option A)**, set these Railway env vars before the first deploy:
- `VITE_GOOGLE_CLIENT_ID` — the Client ID from Step 4 (must be set before first deploy — it's a build-time variable)
- `SESSION_SECRET` — generate with `openssl rand -hex 32` and **seal it** after setting

Then give the operator the green light. Have them prompt:

> "Deploy my app to Railway"

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

## Step 6: Add Secrets (If Needed)

If the app needs API keys or credentials, have them prompt:

> "Add these environment variables to my Railway project: [KEY=value, ...]"

You may need to provide the actual key values (e.g., a Gemini API key from Jeff/Moreno).

---

## Step 7: Verify the Full Loop

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

> **Status: TBD.** A standardized data access layer (BigQuery token store) is a work in progress. Until it's ready, there is no official way for Prometheus apps to access Traba production data.

**Current workarounds:**
- **Nightly data pull** to a local file (what cluster-density-map does). Simple, no cost concerns, but data is stale.
- **Direct BQ queries.** Works but has cost implications. Requires a BQ service account key as a Railway env var.

**What to tell the operator:** If the app needs Traba data, connect them with the data eng team before setting up ad-hoc BQ access.

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
| Supabase | supabase.com | Any eng (creates project, shares with operator) |
