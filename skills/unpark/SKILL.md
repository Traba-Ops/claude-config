---
name: unpark
description: |
  Resume or revive prior work: searches live background sessions AND parked
  snapshots (from /park), ranks them, and loads the winner into this session.
  Use for /unpark, "pick up X", "what was I working on", "revive/continue
  that session about X". Replaces /continue-from.
user-invocable: true
version: 1.0.0
---

# Unpark: resume a live session OR revive a parked one

This is the **pickup** side of the park/unpark pair. It looks in two places at
once and ranks them in a single list:

- **Live background sessions** — still running / recently run, transcript on disk.
  Picking one = resume it (the old `/continue-from` behavior).
- **Parked snapshots** — durable notes written by `/park` into the user's chosen
  park directory (`$CLAUDE_PARK_DIR`, default `~/.claude-park`; often an Obsidian
  vault folder). Picking one = revive a session whose live transcript may be long
  gone (survives the 30-day cleanup, works cross-machine).

You describe what you're after in plain English; matching scores against session
names + goals + status AND parked-note titles + bodies + tags. A short-id prefix
pins an exact target.

## How to use it

```bash
node ~/.claude/skills/unpark/unpark.mjs "the payroll flaky test fix"
```

(Use `bun` if `node` is missing — the script uses only APIs both support.)

- **No hint** → lists everything: live sessions under "resume", parked notes under
  "revive", each with a one-line snippet. Show the user, ask which.
- **A hint matching one target** → prints that target's full context block.
- **A hint matching several / none** → prints candidates; re-run with something
  sharper, or pass the short-id.

## What to do with the output

1. **List of candidates** (no hint / tie / no match) → show the user the live vs
   parked split and ask which they mean. Don't guess across the split.
2. **A live session's snapshot** (`## Resume live session`) → tell the user in 2-3
   lines what it was doing and where it left off, then **continue that work here**
   from that point. Read the relevant files/code before acting if anything's
   ambiguous. Never message or modify the other session — you're picking up its
   thread here, not controlling it.
3. **A parked snapshot** (`## Revive parked session`) → the body IS the handoff:
   read its Goal / State / Key decisions / Next steps, then continue the work from
   its **Next steps**, in the cwd/branch the note names. If the note is truncated,
   open the full file at the printed path. cd to that cwd (or open a worktree
   there) before doing repo work — a parked session usually lived elsewhere.

## Revive lean

The whole point of park/unpark is that the summary replaces the old transcript —
don't undo that by re-inflating. Work from the handoff note; do NOT re-read the
files, logs, or query results the old session already digested unless a Next step
genuinely needs them. Revived sessions measured among the heaviest burners
(300K+ contexts within hours) precisely because they re-pulled everything the
note already summarized. Delegate any broad re-investigation (grep sweeps, log
trawls, transcript reads) to subagents and keep only findings here.

## Notes

- The helper reads only local state + the park dir — no network, no other tools:
  `claude agents --json`, `<config>/jobs/<short>/state.json`,
  `<config>/projects/*/<sessionId>.jsonl`, and `$CLAUDE_PARK_DIR/*.md`.
- It deliberately avoids `claude logs` (raw ANSI redraws, unusable as context).
- If a live session's transcript is missing (cleaned up), the snapshot says so —
  that's the case `/park` exists to prevent next time.

## Related

- **/park** — the save side: snapshot the current (or a named) session into the
  vault so it can be revived here later.
- **/recall** — search prior sessions by content when you don't want to resume,
  just retrieve a past finding/decision.
