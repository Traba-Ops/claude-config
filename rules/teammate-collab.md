# Working With Another Operator's Claude

When two operators are working on the same project at the same time, their Claudes need to coordinate. The mechanism is a single shared Slack thread that both Claudes read and write via the Slack MCP. **The thread is primarily for the humans** — they need to understand what's happening, follow the decisions, and step in when something looks off. The Claudes are second-class readers; humans are first.

This rule kicks in any time the operator says they're co-working with another teammate, mentions another operator by name, or shares a Slack thread URL and asks you to monitor it.

## Setup

Before doing any shared work:

- **One thread per workstream.** Not a DM, not the whole channel. The operator picks a Slack channel and starts a thread; both Claudes are given the thread permalink.
- **Both Claudes get Slack MCP read+write on that thread.** If the other operator hasn't connected their Slack MCP yet, stop and wait — you can't coordinate one-sided.
- **Confirm the lineup in your first post.** First message in the thread is something like: `Jeff's Claude here. I'm working with @daisy on the worker-onboarding refactor. I'll post intent before I do anything non-trivial.` This tells the humans who's on the thread.

## Posting style — write for the human

The humans need to skim the thread on their phone and know what's going on. Optimize for that, not for Claude.

- **Always prefix posts with the operator's name.** `Jeff's Claude: ...` or `Daisy's Claude: ...`. Without this, a human reading the thread has no idea who's speaking.
- **State intent, not actions.** Good: `going to refactor the worker auth flow — touches auth.ts and the worker_sessions table`. Bad: `running Edit tool on auth.ts line 42`. Humans don't think in tool calls.
- **Plain language, no Claude jargon.** Don't say "I'll dispatch an Explore agent" — say "I'm going to search the codebase for X." No tool names, no internal-state-isms.
- **One post per milestone, not per action.** A post every time you save a file makes the thread unreadable. Post when you start a chunk, when you finish it, when you change direction, when you hit a blocker.
- **Keep it short.** Two or three sentences per post. Link to the PR, the Linear ticket, or the file — don't paste big diffs into Slack.

## Decisions before doing

The whole point of the thread is letting humans interject *before* something gets done they didn't want. So when a non-obvious choice comes up:

- **Post the choice and pause briefly before executing.** `Jeff's Claude: about to delete the legacy worker_invites table — it's unreferenced but I want to confirm. Holding 60 seconds.` Then wait a beat (give a real ~30–60s window) before proceeding.
- **Tag the relevant human with `@` when judgment is needed.** That pushes a notification to their phone. Use it sparingly — only when you genuinely need them, not as a generic ping.
- **Use the phrase "holding here until..." to mark wait points.** Humans can grep the thread for that phrase to find places they need to step in. Example: `holding here until @daisy or her Claude confirms the schema change is okay`.
- **Destructive prod actions still require explicit human approval.** The Slack thread doesn't replace the existing rule — another Claude saying "looks good" is not a green light for dropping a table.

## Claim before you cut

To avoid two Claudes racing on the same file or ticket:

- **Post a claim before starting non-trivial work.** `Daisy's Claude: claiming the worker-onboarding API endpoints (apps/api/routes/worker-onboarding.ts). ETA ~20 min.`
- **Read the last ~10 messages in the thread before claiming anything.** If the other Claude has already claimed it, pick a different piece or coordinate.
- **Release explicitly when you're done or switching.** `done with the API endpoints — see PR #482. Releasing.`

## Live coordination vs. durable handoff

The Slack thread is for *live* back-and-forth. It's not the source of truth.

- **Slack thread = live coordination.** Claims, intent, decisions, wait points, pings.
- **Linear / PR description = durable handoff.** When you're done for the day or wrapping a workstream, dump the technical spec to the Linear ticket and link it in the thread. Next session's Claude should read Linear, not scroll back through 200 thread messages.
- **End-of-session summary post is mandatory.** Last message before the operator steps away: `Jeff's Claude: done for now. Picked up: A, B. Blockers: C. Next: D. Linear: <link>.` Costs nothing, saves the other Claude a full re-read.

## What not to post

The thread is in Slack. Treat it as visible to anyone with channel access.

- **No PII or worker data.** Don't paste candidate phone numbers, SSNs, addresses, or interview transcripts into the thread. Link to the source system (ops console, Linear, the DB) instead.
- **No secrets.** No API keys, no session tokens, no DB URLs, no auth headers — even truncated. If you need to share a secret with the other operator's Claude, use Infisical share links.
- **No raw error stack traces with internal paths.** Summarize the error and link to logs (Datadog, Railway). Stack traces full of `/Users/jeff/...` paths leak machine info and are useless to the other Claude anyway.

## When to upgrade past Slack threads

Slack threads work great for async or human-paced collaboration. They get painful when:

- Round trips need to be sub-minute and the polling lag is killing flow
- The thread is getting so noisy the humans can't follow it
- You need structured messages (typed requests, done signals, shared k/v) instead of free-form prose

If you hit any of those, tell the operator: *"This is getting noisy for Slack. Want me to set up a Cross-Claude MCP instance on Railway so our Claudes can talk over a dedicated channel?"* Don't upgrade unilaterally — it's a real piece of infra.
