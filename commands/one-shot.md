---
name: one-shot
description: |
  Drive a change end to end, autonomously: plan → implement on a worktree → PR via
  courier → shepherd to green → tear down → wait for the human to merge. Use when:
  (1) you want one command to carry a scoped change from intent to a merge-ready PR
  with no babysitting, (2) the change is small and well-enough understood to land as
  a minimal diff.
argument-hint: "[what to change]"
version: 1.3.0
---

# One-Shot

Main-session orchestrator that carries one change from intent to merged-and-cleaned.
You hold the loop and every decision; subagents execute scoped operations and return.
Runs in the main session — shepherd-pr and courier can't be dispatched from a subagent.

`$ARGUMENTS` is the change to make. If empty, ask for it before starting.

**Autonomous to a merge-ready PR.** No standing approval gate — research, implement,
and open the PR without stopping for sign-off. The only interrupts are genuine
uncertainty (surface it, don't guess) and high-severity issues damascus flags. A human
merges; you never merge. Once the PR is up and green, tear down the worktree — don't hold it
through the human-merge wait; re-establish it only if shepherd needs another pass.

**Make the minimal change that ships the feature.** Smallest diff that does the job —
no refactors, no adjacent cleanup, no speculative abstraction. A tight diff is what
makes an autonomously-authored PR safe to review and merge. This discipline is against
*self- and damascus-driven* scope growth — not against the user: a human suggestion or
improvement is valid scope, never dismissed as scope creep. Fold it in.

**Ask only on genuine uncertainty.** Proceed on your own judgment by default. Stop and
ask (`AskUserQuestion`) only when uncertainty would change what you build: ambiguous
scope, multiple valid approaches with real tradeoffs, or a risky/destructive/externally-
visible choice. Don't ask to confirm work you can just do.

## Pipeline

### 1. Plan

Research the change against the actual repo and decide the minimal approach. Dispatch
**damascus** (`damascus-plan-review`) on a tight leash — time-box ~10 min, and brief it
to flag only high-severity problems (wrong approach, correctness/security/data risk, a
missed constraint), not nits or gold-plating. Fold in real findings; proceed. Surface
to the user only if the plan hit genuine uncertainty per the rule above.

### 2. Worktree

`EnterWorktree` off `origin/main` (not the current branch). Set it up per
`monorepo-worktree-gotchas` and the `worktree-agent-spawning` rule — symlink
`node_modules`/`.husky/_` when the lockfile matches the parent, else `pnpm install`.
Confirm dependency provenance gives true signal before trusting any check.

### 3. Implement

Make the minimal change in the worktree, following the repo's conventions. Before
handing off, dispatch **damascus**
(`damascus-code-review`) on the diff — same tight leash: address what's high-severity,
don't chase low-severity suggestions that grow the diff.

### 4. QA + demo (user-facing changes only)

If the change has a user-facing surface, dispatch **herzog** to verify it in a real authed app and
film a clean demo. Brief it with the feature, the acceptance criteria, the target (serve the
worktree locally, or the deployed dev env), and a `/tmp` drop location. Herzog returns QA findings
and the video path: on ❌, fix and re-dispatch before opening the PR; on 🔑 reauth, run the refresh
script with the user. Skip entirely for backend/non-visual changes.

### 5. PR

Run local checks (lint, format, typecheck — discovered per shepherd-pr). Then dispatch
**courier** for one scoped operation: push the branch and open the PR. Courier owns
title/body/label/estimate conventions — brief it with intent (what changed, the ticket,
verifications run), not formatting. If herzog produced a demo, attach it inline via the
`attach-video-to-pr` skill (mints a user-attachments URL, posts a PR comment as S. Botsal; falls back
to a cyrano Slack link).

### 6. Shepherd to green

Invoke the **shepherd-pr** skill. It owns the monitor loop, the fix-vs-ask framework,
comment resolution, and flaky-test discipline — drive the PR to green and review-ready
through it. Don't re-implement any of that here.

### 7. Clean up — once the PR is up and green

Once shepherd has the PR green and review-ready (≥10 min past the last push, no open
comments), tear down immediately. `ExitWorktree`, then clean up the local branch (`gt sync` / `git branch -D`) and kill any
orphaned `nx daemon` / plugin-worker processes, per the `worktree-agent-spawning` rule.
Verify the worktree is actually gone — a checked-out branch or live daemon blocks removal.
The remote PR branch is untouched, so the PR keeps working.

### 8. Wait for merge

The PR is review-ready and the worktree is gone. Poll merge state through **courier** —
pace it yourself with `ScheduleWakeup` (long gaps, 1200s+; a merge lands on human time, not
CI time). If new comments or CI failures appear, re-establish a worktree off `origin/<branch>`
(repull), re-enter shepherd to drive it back to green, push through courier, then tear down
again per step 7. On merge you're done — cleanup already happened.

## Boundaries

| Don't | Instead |
| --- | --- |
| Merge the PR yourself | Hand off review-ready; let the human merge |
| Stop for plan approval | Proceed autonomously; ask only on genuine uncertainty |
| Grow the diff with refactors or cleanup | Ship the minimal change for the feature |
| Chase damascus's low-severity nits | Address high-severity only; keep the leash tight |
| Re-explain the CI loop | Hand off to shepherd-pr |
| Run `gt` / `git push` / `gh` directly | Dispatch courier for every toolchain op |
| Hold the worktree through the merge wait | Tear down once green; re-establish only if shepherd needs another pass |
| Spawn courier/shepherd from a subagent | Orchestrate from the main session |
