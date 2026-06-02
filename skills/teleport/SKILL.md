---
name: teleport
description: >-
  Move an in-progress task between this laptop and Claude Code on the web (cloud) using Claude's native
  --remote / --teleport commands. Use when the user says "teleport up" (launch a cloud session from the
  laptop before closing it / commuting) or "teleport down" (pull the cloud session back into the local
  terminal, with its full conversation + branch). Adds a sensitivity safety gate and missing-MCP
  awareness on top of the native commands. Handles code AND non-code tasks.
---

# Teleport — local ⇄ cloud, via native `--remote` / `--teleport`

This skill is a **thin, opinionated wrapper** over two real Claude Code commands. It does NOT reinvent
a handoff — it adds judgment (a sensitivity gate + missing-tool awareness) around the native flow.

## The native commands (verified real in v2.1.x; flags are hidden from `--help` but work)

- **`claude --remote "<task>"`** — laptop → cloud. Creates a NEW cloud session on claude.ai for the
  current repo. Per docs: *"The session clones your current directory's GitHub remote at your current
  branch, so push first if you have local commits, since the VM clones from GitHub rather than your
  machine."* The task runs on Anthropic infra, so it **keeps running with the laptop closed**. Monitor
  via `/tasks` in any CLI session, or claude.ai/code, or the Claude mobile app.
  - **One-way for conversation:** *"from the CLI, session handoff is one-way… you can't push an
    existing terminal session to the web."* `--remote` starts a FRESH session seeded only by the task
    string. So put the context the cloud needs **into the task string** (see up step 4).
  - **No GitHub remote / want uncommitted work up:** it auto-bundles the repo (full history + tracked
    uncommitted changes) and uploads; `CCR_FORCE_BUNDLE=1` forces it. Bundled sessions can't push back
    without GitHub auth configured.
- **`claude --teleport`** — cloud → laptop. Pulls a cloud session into the local terminal. Per docs:
  *"Claude verifies you're in the correct repository, fetches and checks out the branch from the cloud
  session, and loads the full conversation history into your terminal."* So the **conversation comes
  back** — no baton needed on the way down. `claude --teleport <session-id>` targets a specific one;
  `/teleport` (or `/tp`) does it inside a running session; `/tasks` then press `t` also works.
  - Requirements: **clean git state** (it prompts to stash), same repo (not a fork), claude.ai auth
    (not API key). Distinct from `--resume` (which only reopens local history, not cloud sessions).
- **Not this:** `--remote-control` is unrelated — it exposes a *local* session for monitoring from the
  web and dies when the laptop sleeps. Don't confuse it with `--remote`.

**Prerequisites (verify these or the round trip silently half-fails):**
- **Cloud enabled** for the account/org (Pro/Max/Team, or Enterprise premium seats; Team/Ent admins
  toggle it). If disabled, `--remote`/`--teleport` are inert.
- **Signed in** via `/login` with claude.ai (not API key).
- **GitHub connected for cloud sessions — the one people miss.** Run **`/web-setup`** once (syncs your
  local `gh` token to your Claude account), OR authorize the Claude GitHub App via web onboarding.
  **Without this, `claude --remote` falls back to *bundling* your repo (uploads it directly) and a
  bundled session CANNOT push back — so no branch, no PR, and `--teleport` has nothing to fetch.** A
  cloud session that reports "no origin remote" means `/web-setup` wasn't done. (ZDR orgs can't use
  `/web-setup` or cloud sessions at all.)
- First `--remote` in a never-trusted folder shows a one-time "trust this folder?" prompt — accept it.

**Cloud-side gotchas to put in the brief:** if the cloud hits a commit-signing error
(`signing server returned 400 / missing source`), tell it to commit with `--no-gpg-sign`. (This often
travels with the bundle problem above — fixing `/web-setup` so it clones from GitHub usually clears it.)

## Sensitivity triage — DO THIS FIRST on `teleport up`

`--remote` sends the task string + repo to **Anthropic cloud infra**, and the cloud may open a PR on an
**org-visible** Traba-Ops repo. The **task string itself is sensitive content** — "analyze comp
adjustment for <engineer>" leaks even with no data attached. Classify before launching:

- **Confidential** — compensation, individual PII, HR/people, legal, security; anything you wouldn't put
  in a channel other Traba engineers can read.
  → **HARD-STOP. Do not `--remote`.** Explain why, and route the user:
  - Laptop can stay awake (lid open / always-on)? Use **Remote Control** (`/remote-control`) — stays
    local, nothing cloud-cloned.
  - Otherwise just do it **locally at the desk**. There is no secure way to cloud-teleport confidential
    work during a lid-shut commute — say so, don't work around it.
- **Internal-sensitive** — fine within the org, aggregated/de-identified → OK, private Traba-Ops repo.
- **Non-sensitive** — code, public data, generic research → go.

When unsure, treat it as the more sensitive tier and ask. (Aside: a Traba-Ops repo is not a home for
HR/comp artifacts regardless of teleport.)

## `teleport up` — run on the laptop, before closing it

> **The skill prepares; the human launches.** A skill (acting through the Bash tool) **cannot** fire
> `claude --remote` itself: a non-TTY subprocess errors with `--print`, a pty hits the workspace-trust
> prompt, and `--dangerously-skip-permissions` is correctly blocked as an unsafe-agent pattern. This is
> a deliberate guardrail against agents silently spawning autonomous cloud agents — do not try to work
> around it. So `teleport up` does steps 1–4 (all the plumbing) and then **hands the user one line to
> run in their terminal** (step 5). That's as "hands-off" as it safely gets.

1. **Sensitivity triage** (above). Hard-stop confidential.
2. **Note the tools.** List MCPs/data the task needs. The cloud has **none of your local MCP servers**
   (Slack, Coda, Linear, traba-db, BigQuery/bq-auth, etc. are interactively authed). The brief must tell
   the cloud to **do what it can, skip what it can't, and note what it skipped** for you to finish
   locally on the way down.
3. **Provision the carrier repo automatically (no manual repo management).**
   - In a git repo already? Use it: `git push` the current branch (the cloud VM clones from GitHub, not
     your disk). Uncommitted work rides via the bundle fallback (`CCR_FORCE_BUNDLE=1` to force).
   - Not in a repo (ad-hoc / non-code session — e.g. cwd isn't git)? **Auto-create a scratch repo** in
     Traba-Ops (`gh repo create Traba-Ops/<name> --private`), seed `main`, snapshot any working files
     into it, push. The user never hand-manages a repo — the skill does it. (Reusing one dedicated
     scratch repo across runs is nice: trust it once and the `--remote` launch stops prompting.)
4. **Compose the brief** — a tight, self-contained task string packing the goal, the context the fresh
   cloud session can't see (what you did, decisions, constraints), and the best-effort/skip-and-note
   instruction. This is the baton going up (the conversation does NOT travel up).
5. **Hand the user the launch line** (do not try to run it yourself):
   ```
   claude --remote "<brief from step 4>"
   ```
   Tell them: run it in a terminal from the repo dir, accept the one-time trust prompt, and it creates a
   cloud session that runs on Anthropic infra (laptop can then close). Monitor via `/tasks`,
   claude.ai/code, or the mobile app.

## `teleport down` — run on the laptop, when back

1. **Ensure clean git state** (commit/stash local changes — `--teleport` will prompt to stash otherwise).
2. **`claude --teleport`** — pick the session from the list (or `claude --teleport <session-id>`; or
   `/teleport` from inside a running session). This checks out the cloud branch AND loads the full
   conversation into your terminal.
3. **Finish locally.** You're now in the resumed session with the full local MCP toolset — knock out
   whatever the cloud noted it had to skip.
4. **Wrap up the branch.** The cloud worked on its own branch (often with an open PR). Review the diff,
   then merge / PR / delete as appropriate. No HANDOFF scaffolding to strip — this flow doesn't create
   any.

## Notes

- This skill replaced an earlier git+HANDOFF.md handoff that was built on a false premise (that there
  was no CLI launcher and the conversation couldn't return). The native `--remote`/`--teleport` handle
  both. If you ever need to move work without these commands (e.g. they're disabled for the org), the
  manual fallback is: push a branch + commit a context note, launch the cloud session from claude.ai/code
  by hand, and `git pull` the cloud's `claude/*` branch back.
- The cloud session is a fresh context: the better your `--remote` task string, the better the result.

## Design notes (why)

- **Verified:** `claude --remote` is a real command in v2.1.160 (launches the cloud flow from the CLI —
  reaches the workspace-trust gate when run in a fresh checkout). `--teleport` returns conversation +
  branch per the official CLI / web docs. Flags are hidden from `--help` (gated on cloud being enabled)
  but functional — do NOT conclude they're absent from `--help` alone.
- **Sensitivity hard-stop retained** because the native commands give no data-sensitivity warning.
- **MCP loss accepted by design:** cloud is best-effort; grow cloud coverage via the repo's `.mcp.json`
  over time.
- **Remote Control is the better tool if the laptop can stay awake** (lid open / always-on): one
  continuous local session, full MCPs, no cloud round trip. Teleport is for the lid-shut commute.
