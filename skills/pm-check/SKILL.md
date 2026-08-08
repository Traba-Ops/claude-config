---
name: pm-check
version: 1.0.0
description: Run Traba's pre-build checks before writing code for anything new — an app, a dashboard, a Neutron workflow or agent, a bot, a script, an integration. Routes the request through Neutron (which owns the Oracle checks) and reports whether it already exists, whether it should be a Neutron capability instead, and what is missing. Use when starting to build something, or when the PM-check gate has blocked a Write.
---

# pm-check

Traba has 96 repos in the Traba-Ops org and 67 Railway projects. Inside them are six
separate `daily-recap-agent` repos, three shift-readiness SMS tools, three copstab
dashboards, four NFI trackers, two offer-letter generators. Nobody did anything wrong —
they had no way to know.

This skill is the way to know. **Neutron owns the checks** (the Oracle service: evidence
search over workflows, jobs, recipes, dashboards, and the ops-console feature registry).
This skill is the client — it routes the request there and reports back.

## When this runs

- The `pm-check-detect` hook saw a build-shaped prompt and asked for this check. The
  separate `pm-check-gate` hook is what refuses the write.
- Or you were asked to build something and want to check first.

Do **not** run it for edits to something that already exists, bug fixes, refactors, or
questions about existing systems. It is a pre-*build* check, not a pre-edit check.

The gate covers `Write`, `Edit`, `MultiEdit`, and `NotebookEdit` in the main session.
It does not cover subagents — a delegated implementation never saw the prompt that
triggered the check and cannot run it meaningfully — nor `Bash`, since this skill
needs `Bash` to record its own completion. Both are open paths by design; the check
is a prompt for thought before building, not a sandbox.

## Steps

### 1. State what is being built, in one sentence

Written as the outcome, not the implementation. *"A daily Slack summary of a rep's sales
calls"* — not *"a Node script with a cron."* The search matches on intent, so an
implementation-flavoured description finds nothing.

### 2. Ask Neutron

Call `mcp__claude_ai_Neutron__ask_neutron` with a prompt shaped like:

```
I am about to build the following. Run the pre-build verification and report back.

WHAT: <one-sentence outcome>
KIND: <app | dashboard/report | Neutron workflow | Neutron agent | recipe | script | integration>
DATA: <what Traba data it reads or writes, or "none">
CADENCE: <one-off | on demand | hourly | daily | weekly | event-driven>

Tell me:
1. Does something already cover this? Name it with an id if so.
2. Should this be a Neutron capability (an action, a workflow, or just asking you)
   rather than a new app?
3. What is missing before it could work — connectors, tools, data?
4. What should I ask the requester before building?
```

Then poll `mcp__claude_ai_Neutron__get_neutron_result` with the returned `runId`. It holds
up to ~25s per call — call it again immediately if it says still working, do not sleep.

**Neutron runs its own Oracle check** (`verify_automation_request`) when the request is
build-shaped, so the verdict comes back inside its answer.

### 3. Cover what Neutron cannot see

Oracle's evidence sources are Neutron-internal — workflows, scheduled jobs, recipes,
dashboards, feature registry. It does **not** see the Traba-Ops GitHub org or Railway. So
for an app or script, also check those yourself:

```sh
gh search repos --owner Traba-Ops "<two or three keywords>" --limit 20
```

Include archived repos in what you consider — *"we built this and killed it"* is stronger
prior art than an active project, not weaker.

### 4. Answer what Neutron cannot infer

Neutron can find prior art and routing. It cannot know these — ask the requester, briefly:

- **Who owns this after launch?** A named human. Each of the six recap agents had an
  author; none had a steward.
- **When do we kill it?** What level of use, over what window, means this was a miss.
- **Where does the output land?** A Slack post, an email, and a PDF are delivery surfaces,
  not systems of record. If nothing persists, is that deliberate?

### 5. Check the hard rules

These are not questions — they are conditions. Say plainly if one is violated:

- **Worker-facing SMS, two-way text, or robocall goes through the comms broker**
  (`POST /communication/send-direct-two-way-sms`, as the acting recruiter). It carries
  sender attribution, opt-out suppression, dedup, geo-gating, and audit. Raw OpenPhone/Quo
  only when the broker is unreachable — and then stamp the sender's `userId`, or the
  message is silently attributed to whoever owns the phone number.
- **Traba data via sanctioned paths only** — bq-auth proxy for BigQuery, allow-listed
  service accounts for the node backend. Never ad-hoc GCP credentials.
- **No deploy without auth** — `@traba.work` enforced server-side.
- **No secrets in code.** `.env`, gitignored.
- **Traba-Ops org and the Traba Railway team**, never personal accounts.

### 6. Report, state your path, then record it

Give the human a short brief: what exists, the routing recommendation, the gaps, any
hard-rule violations. Then **state which path you are taking** — build fresh, extend a
named thing, or don't build. Then record completion so the gate lifts:

```sh
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/pm-check-done.sh"
```

Run it exactly as written — there is no placeholder to fill in. **Read its output.**
It prints `pm-check recorded: <path>` on success, and on failure it says so and tells
you what to do; do not report the check as complete on a failure.

The script resolves the flag path the gate actually checks. It prefers
`CLAUDE_PM_CHECK_DONE`, exported by the `pm-check-reset` SessionStart hook from the
session id the hook itself received, so that value is exact. It falls back to
`CLAUDE_CODE_SESSION_ID` for a session where that hook never ran — hooks installed
mid-session. The fallback normally matches, but it can [report the startup id instead
of the resumed one on `--continue` or `--resume` without an explicit
id](https://code.claude.com/docs/en/env-vars), so on that branch the script verifies
the flag landed next to the `.pending` the gate is armed on, and fails loudly if it
did not — rather than reporting success and leaving the next Write denied for a reason
nobody can see.

If it fails, pass the exact `.done` path and re-run:

```sh
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/pm-check-done.sh" <path>
```

The pm-check context you were given carries that path literally, and so does the
message on any blocked Write.

## If Neutron is unreachable

Not authed, connector missing, or it times out past a couple of minutes: **say so plainly,
do the step-3 GitHub search yourself, and proceed.** A pre-build check that strands a
session gets switched off, and a stranded session is worse than an unchecked build.

## Escape hatch

`CLAUDE_PM_CHECK=off` disables the gate entirely, as does the flag file:

```sh
touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.pm-check-off"
```

That is the path both hooks actually resolve — `~/.claude/.pm-check-off` is only correct
for operators who have not set `CLAUDE_CONFIG_DIR`. Deliberate and documented beats
people uninstalling the bundle to get work done.
