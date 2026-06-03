# Dynamic Workflows

Claude Code can run **dynamic workflows**: instead of working a task turn by turn, Claude writes a JavaScript script that orchestrates many subagents at once (tens to hundreds), runs it in the background, and returns one synthesized answer. The plan lives in code, not in the conversation, so a workflow can fan out wider and cross-check its own findings before anything reaches the operator.

This is a powerful but **token-heavy, opt-in** tool. A single run can use far more tokens than doing the same task in conversation. The guidance below is the default policy for working with Traba operators — it sits under the constitution's principle hierarchy (security > development hygiene > simplicity > everything else) and its "Recurring Tasks and Token Cost" rule.

> **Official docs:** [Orchestrate subagents at scale with dynamic workflows](https://code.claude.com/docs/en/workflows) — the canonical reference for the feature (saved/"static" workflows are the [Save the workflow for reuse](https://code.claude.com/docs/en/workflows#save-the-workflow-for-reuse) section of that same page). When in doubt about behavior or limits, check the docs.

## Default posture: don't reach for a workflow unless it's warranted

For almost everything an operator builds, a normal conversation — or a single subagent for a noisy search — is the right tool. Workflows are not the default. Only start one when **both** are true:

1. The task genuinely needs more agents than one conversation can coordinate — a repo-wide sweep, a large migration, a research question that needs many sources cross-checked, or a hard plan worth drafting from several independent angles.
2. The operator has opted in — they said "use a workflow" / "ultracode", invoked a saved workflow command, or are in an `ultracode` session.

If a task is just multi-step but small, do it directly or with a subagent. Don't manufacture a workflow because the task "feels big." When unsure whether the scale justifies the cost, say what a workflow would do and roughly what it would cost, and let the operator decide.

## Choosing the right tool

The official docs have a fuller [subagents vs skills vs agent teams vs workflows](https://code.claude.com/docs/en/workflows#when-to-use-a-workflow) comparison. The short version:

| Use this | When |
|---|---|
| **Just do it in conversation** | Normal builds, edits, debugging, Q&A — the overwhelming majority of work |
| **A subagent** | One noisy investigation (broad grep, log trawl) where you only want the conclusion, not the file dumps |
| **A dynamic workflow** | The task needs dozens+ of coordinated agents, or you want the orchestration codified so you can rerun and trust it (adversarial verification, multi-angle planning) |

## Dynamic (one-off) vs saved ("static") workflows

Both run on the same runtime. The difference is whether the orchestration is written fresh or kept around:

- **Dynamic / one-off** — Claude writes the script for *this* task and runs it once. Right for a one-time audit, migration, or research question. Nothing is saved.
- **Saved / reusable (the "static" one)** — after a run does what you wanted, [save its script](https://code.claude.com/docs/en/workflows#save-the-workflow-for-reuse) (`/workflows` → `s`) as a `/command`. It then reruns the *same* orchestration every time. Right for a process you repeat: a review you run on every branch, a weekly research digest, a recurring triage. Saved workflows accept input through `args` (e.g. a list of files or a question), so you parameterize instead of editing the script each run.

**Rule of thumb (mirrors the constitution's token-cost rule):** if you've run the same one-off workflow more than a couple of times, save it as a command. A saved workflow is cheaper to invoke and gives a repeatable, reviewable process. A one-off you keep rewriting wastes tokens and drifts.

## Cost discipline

- **Pilot on a slice first.** Before a workflow over a whole repo or a broad question, run it on one directory or a narrow question to gauge spend. Watch token usage in `/workflows`; stop the run anytime without losing completed work.
- **Mind the model.** Every agent in a workflow uses the session's model unless a stage routes to a smaller one. Check `/model` before a large run, and ask for a cheaper model on stages that don't need the strongest one.
- **Runs count toward plan usage and rate limits** like any other session. The runtime caps concurrency (~16 agents) and total agents (1,000/run) as a runaway backstop — that's a ceiling, not a target.

## Confirm before externally-visible or destructive workflows

A workflow's subagents run with file edits auto-approved. The constitution's confirmation rules still apply to what the workflow *does*: pause and confirm before a workflow that mutates prod data, posts externally, or makes hard-to-reverse changes. PR-gated and read-only workflows (audits, research, planning) stay autonomous.

## Turning it off

Workflows are opt-in per run. To disable entirely for a machine, toggle Dynamic workflows off in `/config`, or set `"disableWorkflows": true` in `~/.claude/settings.json`. Org-wide disable lives in managed settings.
