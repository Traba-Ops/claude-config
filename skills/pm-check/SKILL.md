---
name: pm-check
version: 1.0.0
description: Run Traba's pre-build checks before writing code for anything new — an app, a dashboard, a Neutron workflow or agent, a bot, a script, an integration. Routes the request through Neutron (which owns the Oracle checks) and reports whether it already exists, whether it should be a Neutron capability instead, and what is missing. Use when starting to build something, or when the PM-check gate has blocked a Write.
---

# pm-check

Traba has over 100 repos in the Traba-Ops org and 67 Railway projects. Inside them are six
separate `daily-recap-agent` repos, three shift-readiness SMS tools, three copstab
dashboards, four NFI trackers, two offer-letter generators. Nobody did anything wrong —
they had no way to know.

This skill is the way to know. **Neutron owns the checks** (the Oracle service: evidence
search over workflows, jobs, recipes, dashboards, and the ops-console feature registry).
This skill is the client — it routes the request there and reports back.

## When this runs

- The `pm-check-detect` hook saw a build-shaped prompt and asked for this check. The
  separate `pm-check-gate` hook is what refuses the write, and it is registered only
  on machines that opted in to enforcement — run the check either way.
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

### 2. Run the check

Call `mcp__claude_ai_Neutron__verify_build_request`:

```
goalKind:    WORKFLOW_OR_JOB | DASHBOARD_OR_REPORT | RECIPE
requestText: <the outcome, in one sentence, from step 1>
```

Pick the closest `goalKind` — `WORKFLOW_OR_JOB` for an automation, agent, script or
schedule; `DASHBOARD_OR_REPORT` for a chart, dashboard, report, or an app whose point is
showing data; `RECIPE` for a data-pipeline recipe. There is no goal kind for "a standalone
app" yet, so pick the one closest to what it *does*.

It returns in a few seconds — no `runId`, no polling — with a decision (`EXISTS`, `REUSE`,
`NEW_AUTOMATION`, `INCONCLUSIVE`), the matched thing, and an `instruction` field. **Follow
the `instruction`.**

If it comes back `ran: false`, the check did not run — database down, Oracle switched off,
or an error. Say so in one line and carry on with the steps below; do not report the check
as done.

Use `ask_neutron` only if `verify_build_request` is not in your tool list — it is the older
path, costs a full metered Neutron run, and returns prose you have to interpret rather than
a verdict.

### 3. Cover what Neutron cannot see

Oracle searches Neutron's own objects — workflows, scheduled jobs, recipes, dashboards,
the ops-console feature registry — plus a committed manifest of both GitHub orgs
(`Traba-Ops` and `trabapro`) carrying Railway deployment state, Linear tickets, and the
Coda-backed knowledge base. A hit marked `(deployed: …)` is not just source: something is
running under that name.

Two gaps to cover yourself:

**The repo manifest is a periodic snapshot, not a live read.** Anything created since the
last regeneration is invisible to it. One command catches that, and it is worth running for
any app or script:

```sh
gh search repos --owner Traba-Ops --owner trabapro "<two or three keywords>" --limit 20
```

Include archived repos in what you consider — *"we built this and killed it"* is stronger
prior art than an active project, not weaker.

**Slack is not searched.** Slack's `search.messages` needs a user token that no deploy
holds yet, so the source ships switched off. If the request sounds like something a team
would have argued about — a recurring report, a metric definition, anything with an owner
dispute in its past — search Slack yourself before concluding nothing exists.

### 4. Answer what Neutron cannot infer

Neutron can find prior art and routing. It cannot know these — ask the requester, briefly:

- **Who owns this after launch?** A named human. Each of the six recap agents had an
  author; none had a steward.
- **When do we kill it?** What level of use, over what window, means this was a miss.
- **Where does the output land?** A Slack post, an email, and a PDF are delivery surfaces,
  not systems of record. If nothing persists, is that deliberate?

### 5. Check the hard rules

These are not questions — they are conditions. Say plainly if one is violated:

- **Worker-facing SMS, two-way text, or robocall goes through a sanctioned, attributed
  path — and which one depends on the line.** General worker outreach goes through the
  comms broker: `POST /v1/worker-outreach/request` with `type: OPS_SMS`, recipients by
  `workerId` or `ghostProfileId` (raw phone numbers are rejected), authenticated as the
  acting recruiter. It carries sender attribution, opt-out suppression, blocked numbers,
  dedup, geo-gating, and audit. An ad-hoc unattributed send is never acceptable.

  Sending **from** an OpenPhone/Quo line has **no mounted path today** — the broker's
  delivery is Twilio-backed and cannot send from an OpenPhone number, and
  `OPENPHONE_OUTBOUND_SMS_MOUNTED` is false, so no send tool exists to call. Say that
  plainly, report the capability gap, and offer what is actually supported: a Slack
  digest a human sends, or moving the send onto the broker from a Traba number. Naming a
  tool that is not mounted sends the requester after a next step they cannot take.

  (`POST /communication/send-direct-two-way-sms` is a **removed** endpoint, and
  `propose_send_openphone_sms` is **not mounted**; if you see either quoted anywhere,
  that doc is stale.)
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

## There is no bypass

The gate lifts when the check has actually run and `pm-check-done.sh` has recorded it.
There is no opt-out flag and no environment variable. If you think the check does not
apply to what you are doing, run it anyway — it costs a few seconds, and on a genuine
non-build it returns nothing and gets out of the way.

The one case that is not a bypass: if Neutron is unreachable, follow the section above —
say so plainly, do the GitHub search yourself, and record completion. The check having
been attempted honestly is the bar, not the check having succeeded.
