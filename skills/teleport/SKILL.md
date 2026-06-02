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

**Prerequisites:** Claude Code on the web enabled for the account/org (Pro/Max/Team, or Enterprise
premium seats — Team/Ent admins toggle it; if disabled, `--teleport`/`--remote` are inert). Signed in
via `/login` with claude.ai. First `--remote` in a never-trusted folder shows a one-time
"trust this folder?" prompt — just accept it.

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

1. **Sensitivity triage** (above). Hard-stop confidential.
2. **Note the tools.** List MCPs/data the task needs. The cloud has **none of your local MCP servers**
   (Slack, Coda, Linear, traba-db, BigQuery/bq-auth, etc. are interactively authed). The cloud will
   work best-effort without them — so the task string must tell it to **do what it can, skip what it
   can't, and note what it skipped** for you to finish locally on the way down.
3. **Get the work onto GitHub.** `--remote` clones from GitHub, not your disk: `git push` the current
   branch first. If you have uncommitted work you want up and pushing isn't appropriate, rely on the
   bundle fallback (or `CCR_FORCE_BUNDLE=1`).
4. **Launch:** `claude --remote "<task>"`, where `<task>` packs everything the fresh cloud session
   needs — the goal, the context it can't see (decisions, constraints), and the instruction to work
   best-effort around missing MCPs and record skips. Keep it tight and self-contained.
5. **Confirm to the user:** the cloud session is running; monitor with `/tasks`, claude.ai/code, or the
   mobile app; the laptop can now close. (It's genuinely running in the cloud — say that, not "staged.")

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
