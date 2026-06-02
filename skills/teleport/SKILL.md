---
name: teleport
description: >-
  Move a background task between this local machine and Claude Code on the web (cloud) so work can
  continue while the laptop is closed. Use when the user says "teleport up" (push the current task to
  the cloud before closing the laptop / commuting) or "teleport down" (pull cloud work back to the
  laptop). Handles code AND non-code tasks (e.g. data analysis). The conversation does NOT cross the
  jump — a committed HANDOFF.md is the baton that carries intent/state/next-steps both directions.
---

# Teleport — local ⇄ cloud task handoff

The user wants to start a task at their desk, keep it moving from their phone during a lid-shut
commute, then pick it back up at the laptop. This skill bridges that.

## The hard constraints (why this works the way it does)

Internalize these — they are the entire reason for the design. Do not propose alternatives that
violate them:

- **Remote Control is NOT the tool for a lid-shut commute.** `claude --remote-control` runs the
  session as a *local process*. The moment the lid shuts and the laptop sleeps in a bag, that process
  can't do work. So if the user's laptop is closed/in a bag, Remote Control is ruled out. (If the
  laptop can stay awake — lid open / always-on — Remote Control is the better tool and this skill is
  unnecessary; see Design notes.)
- **Claude Code on the web (cloud) is the only thing that runs with the laptop closed.** It executes
  on Anthropic infra against a cloned **GitHub repo**. Every cloud session is anchored to a repo.
- **The cloud does NOT have the user's local MCP servers.** Slack, Coda, Linear, traba-db, BigQuery
  (bq-auth), etc. are interactively authed and unavailable in the cloud. This is accepted: the cloud
  runs **best-effort**, skips what it can't reach, and records what it skipped. We widen cloud MCP
  coverage over time by declaring headless-auth-able servers in the carrier repo's `.mcp.json`.
- **The conversation history does NOT teleport.** There is no API to inject a local session's
  messages into a cloud session. The cloud session starts fresh. So context crosses as a committed
  **`HANDOFF.md`** artifact that the cloud reads on launch and updates before it stops. That file is
  the baton, both up and down.
- **The cloud session is launched from the PHONE, not the laptop CLI.** There is no `claude --remote`
  launcher in this version. The user opens claude.ai/code (or the Claude mobile app), picks the repo
  + branch, and types a one-line kickoff. So `teleport up`'s job is to get everything *staged and
  pushed* so the phone launch is one tap + one line.

## Sensitivity triage — DO THIS FIRST on every `teleport up`

The cloud carrier is a **Traba-Ops repo** (org owners can see it) **cloned onto Anthropic infra**,
with whatever you commit living in **git history**. So sensitivity must pick the *mechanism*, not just
what gets committed. Critically: **the HANDOFF.md task line itself is sensitive content** — "analyze
comp adjustment for <engineer>" leaks the secret even with no data file attached. Classify the task
before anything else:

- **Confidential** — compensation, individual PII, HR/people, legal, security, anything you would not
  put in a channel other Traba engineers can read.
  → **HARD-STOP. Do not cloud-teleport.** Tell the user plainly why (org-visible repo + git history +
  cloud clone is the wrong home for this), and route them:
  - If the laptop can stay awake (lid open / always-on): recommend **Remote Control**
    (`/remote-control`) — files never leave the machine, nothing is committed to GitHub, nothing is
    cloud-cloned. This is the one case Remote Control beats teleport.
  - Otherwise: recommend just doing it **locally at the desk**. There is no secure way to cloud-teleport
    confidential work during a lid-shut commute — say so, don't work around it.
  - Do NOT proceed to the staging steps below for this tier.
- **Internal-sensitive** — business data fine within the org, aggregated/de-identified.
  → Cloud OK, but **private** Traba-Ops repo, **ephemeral branch**, and offer to **hard-delete the
  branch** after `teleport down`.
- **Non-sensitive** — code, public data, generic research.
  → Cloud freely (still a private repo by default; Traba-Ops repos are never public without explicit
  reason).

When unsure which tier, treat it as the more sensitive one and ask the user.

(Aside: a Traba-Ops repo is not an appropriate home for HR/comp artifacts even outside teleport —
those belong wherever People/comp data lives with proper access controls.)

## `teleport up` — run on the laptop, before closing it

Goal: stage the work + a HANDOFF.md baton on a pushed branch, and hand the user a one-line phone
kickoff. Steps:

1. **Pick the carrier repo (decide now, don't hardcode).**
   - If the current work is tied to a git repo (cwd is inside one and the task is about it), use that
     repo.
   - Otherwise (ad-hoc / non-code task), ask the user which repo to use, or offer to create a
     dedicated workspace repo in the **Traba-Ops** org (`gh repo create Traba-Ops/<name> --private`).
     All Traba code lives in Traba-Ops — never a personal account.
   - **Do NOT tell the user to "connect the repo at claude.ai/code" as a required step.** Traba-Ops
     repos generally appear in the claude.ai/code picker automatically because the Claude GitHub App
     has org-wide access (verified in testing — a freshly-created repo showed up without any manual
     connect). Only if the repo is genuinely missing from the picker does the user connect it once.
   - **Fresh repo → seed `main` first.** A brand-new repo's first commit becomes the default branch;
     if that's the teleport branch, the cloud's PR bases oddly. So on a newly-created repo, make an
     initial commit on `main` (e.g. a stub README), push it, confirm `main` is default, THEN branch.

2. **Branch.** Create/switch to `teleport/<short-task-slug>` **off `main`** so nothing lands on `main`
   or a real PR branch, and the cloud's eventual PR has a sane base.

3. **Write `HANDOFF.md`** at the repo root. Use this structure:
   ```markdown
   # Teleport handoff — <task title>
   _Up: <absolute timestamp> · from <hostname> · staged on branch teleport/<slug> (the cloud will work on its own claude/* branch)_

   ## Task
   <what we're trying to accomplish, in plain terms>

   ## Why / context
   <the background the cloud needs but can't see — decisions, constraints, the user's intent>

   ## Current state
   <what's done, what files/data already exist in this branch, where things stand>

   ## Next steps (ordered)
   1. ...
   2. ...

   ## Tools this may need
   <list MCPs/data sources>. The cloud likely won't have some of these. **Do your best without them,
   complete what you can, and under "## Cloud progress" record exactly what you skipped and why so the
   local session can finish it with full tools.**

   ## Cloud progress
   _(cloud-Claude: fill this in before you stop — what you did, what you skipped, any decisions, the
   new next-steps for the laptop side.)_
   ```

4. **Best-effort pre-fetch — gated by the triage.** If this local session already pulled data the
   cloud will need (a CSV, query results, fetched docs), you MAY commit it — but only after the
   sensitivity triage above clears it. Never commit raw PII, individual records, secrets, or
   confidential payloads; if data is needed and sensitive, it must be aggregated/de-identified first,
   and if it can't be, leave it out and let the cloud work without it (finish that part locally on the
   way down). Don't go fetch new data unless the user asks — cloud is allowed to proceed without it.

5. **Commit + push.** `git add -A && git commit -m "teleport up: <slug>" && git push -u origin
   teleport/<slug>`.

6. **Record state** for the down trip: write `~/.claude/teleport/last.json` with
   `{repo, branch, slug, upAt}` (mkdir -p first).

7. **Deliver the phone kickoff.** The kickoff payload is: repo + branch name + the exact one-liner to
   paste on the phone: **"Read HANDOFF.md and continue. Update the Cloud progress section before you
   stop."**
   - **Default delivery: print it in the terminal AND write it to `kickoff.txt`** in the repo root (or
     cwd). When the user is live at "teleport up" time this is enough.
   - A Slack/phone notification is a *bonus*, not the default. **Do NOT scan/scrape `.env` files,
     Railway, or any secret store for a bot token** — that trips the auto-mode classifier and gets
     denied (observed in testing). Only push a notification if a token is already present as a plain
     env var you can read without scanning; otherwise skip it silently and rely on the terminal +
     `kickoff.txt`.

8. **Confirm** to the user: repo, branch, that it's pushed, and where the kickoff is (terminal +
   `kickoff.txt`, plus Slack if it went).

## `teleport down` — run on the laptop, when back

Goal: bring the cloud's work back and resume with full local tools.

1. **Find where the cloud actually put its work — NOT your teleport branch.** Read
   `~/.claude/teleport/last.json` for the repo. Then locate the cloud's output, which lands on its
   **own auto-named branch + PR**, not the `teleport/<slug>` branch you pushed:
   - `gh pr list --repo <repo> --state all --json number,headRefName,title,updatedAt` — the cloud
     session opens a PR; the newest one is almost always it.
   - Its head branch is typically `claude/<random-name>` (e.g. `claude/quirky-noether-LTUbK`), based
     off your teleport branch or `main`.
   - If no PR, `git fetch origin && git branch -r | grep -E 'claude/|teleport/'` and take the
     most-recently-updated `claude/*` branch.
   (This is observed cloud behavior — do not assume the cloud pushed back to `teleport/<slug>`.)
2. **Pull that branch.** `git fetch origin && git checkout <cloud-branch> && git pull --ff-only` (or
   `gh pr checkout <number> --repo <repo>`).
3. **Read the baton.** Open the updated `HANDOFF.md` — focus on the **Cloud progress** section — and
   `git log`/`git diff` against your up commit (or `main`) to see what the cloud actually changed.
4. **Summarize for the user:** what the cloud completed, what it **skipped due to missing tools**, any
   decisions it made, and the remaining next steps.
5. **Offer to finish locally.** The laptop has the full MCP toolset — proactively offer to run the
   exact steps the cloud had to skip.
6. **Clean up the baton.** The cloud has already opened a PR from its `claude/*` branch, and that PR
   diff currently contains the teleport scaffolding (`HANDOFF.md`, `kickoff.txt`). Before this work
   merges anywhere real, strip it: on the cloud branch, `git rm HANDOFF.md kickoff.txt`, commit, and
   offer to squash the `teleport up` + cloud commits so the handoff machinery never lands in review.
   If the task was throwaway, offer instead to just close the PR and delete both branches.

## Notes

- Keep the HANDOFF.md tight — it's a decisions-and-next-steps brief, not a transcript. A fresh cloud
  model reconstructs intent better from a sharp brief than from re-reading everything.
- This skill stages and instructs; it does not (cannot) launch the cloud session itself — that happens
  from the phone. Don't claim the cloud session is "running" after `teleport up`; claim it's *staged
  and ready to launch from the phone*.
- For a task genuinely tied to an existing project repo, the same flow works — just carry on that
  repo's own branch and remember to strip HANDOFF.md on the way down.
- **The cloud session works on its OWN `claude/*` branch and opens a PR** — it does not push back to
  the `teleport/<slug>` branch you created. `teleport up` should tell the user to expect a new PR;
  `teleport down` finds the cloud's branch via that PR (see down step 1). This is verified behavior.
- **Verified end-to-end** (poem-persistence smoke test, Traba-Ops/teleport-sandbox): repo create →
  branch push → HANDOFF baton → cloud read + appended + updated HANDOFF + opened PR → `teleport down`
  pulled it back. The round trip works; the fixes above are friction polish, not a broken mechanism.

## Design notes (why, for future-me)

- **Remote Control rejected** for the lid-shut/in-bag commute → the local process can't run while the
  laptop sleeps. For a lid-open / awake-laptop / always-on-box setup, Remote Control is the strictly
  better path (one continuous session, full local MCPs, zero handoff) and this skill is unnecessary.
- **Cloud chosen, MCP loss accepted by design:** cloud pushes forward best-effort without missing
  tools, and teams grow cloud MCP coverage by declaring headless-auth-able servers in `.mcp.json`
  over time.
- **The conversation seam is irreducible** — no product mechanism carries a local session's message
  history into a cloud session. HANDOFF.md is the deliberate workaround, used as a two-way baton.
