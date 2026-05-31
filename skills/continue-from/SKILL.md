---
name: continue-from
description: |
  Pick up and continue work that another Claude Code session (a background
  agent in `claude agents`) was doing. Use when the user wants to resume,
  take over, hand off, or just look at what a different session was working
  on — e.g. "continue from the session where I was doing the payroll fix",
  "what was my other session working on", "take over the background agent
  that was researching X", "pick up where the deploy session left off".
  Reads that session's goal + where it left off + recent activity so THIS
  session can keep going. Does not message or modify the other session.
version: 1.0.0
---

# Continue From Another Session

You run several Claude Code sessions in the background (`claude agents` / `--bg`).
This skill lets the current session **pick up another one's work and keep going** —
you describe the other session in plain English and Claude pulls in what it was
doing so it can continue here.

This is a one-way "read their work and continue" — it is **not** live messaging
between sessions. The other session keeps running untouched.

## How to use it

Run the bundled helper with a hint describing the session. The hint can be words
from the session's name **or from what it was actually doing** — matching scores
against the session's goal and last status, not just its auto-generated name.

```bash
node ~/.claude/skills/continue-from/continue-from.mjs "the payroll flaky test fix"
```

(If `node` isn't installed, run it with `bun` instead — the script uses only
standard APIs both support: `bun ~/.claude/skills/continue-from/continue-from.mjs "..."`.)

- **A hint that matches one session** → the helper prints that session's goal,
  where it left off, and its recent activity.
- **No hint** (`node ~/.claude/skills/continue-from/continue-from.mjs`) → it lists
  every background session with a one-line goal so you can pick one.
- **A hint that matches several / none** → it lists the candidates so you can
  re-run with something sharper. You can always pass the 8-character short id
  (e.g. `85772167`) to pin an exact session.

## What to do with the output

1. If the helper printed a **list of candidates** (no hint, no match, or a tie),
   show the user the list and ask which session they mean — don't guess.
2. If it printed a **single session's snapshot**, tell the user in 2-3 lines what
   that session was doing and where it left off, then **continue that work here**
   from that point. If anything material is ambiguous (which files, what the next
   step is), read the relevant code/files before acting rather than assuming.
3. **Never message or modify the other session.** It runs independently; you are
   picking up its thread in this session, not controlling it.

## How it works (for the curious)

The helper reads from local Claude Code state — no network, no other tools:

- `claude agents --json` for the live list of background sessions.
- `<config>/jobs/<short-id>/state.json` for each session's **goal** (`intent`) and
  **last status** (`detail`). (`<config>` is `~/.claude`, or `$CLAUDE_CONFIG_DIR`.)
- `<config>/projects/*/<session-id>.jsonl` (the transcript) for the recent activity.

It deliberately does **not** use `claude logs`, which returns raw terminal escape
codes that aren't usable as context.

## Related

- See `docs/multi-session.md` for the bigger picture: running several Claudes at
  once, the `claude agents` view, and enabling **agent teams** (sessions that talk
  to each other directly while they work).
