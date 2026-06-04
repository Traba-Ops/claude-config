---
name: park
description: |
  Save a session's full working context to a durable, human-readable snapshot
  in a directory you choose (set CLAUDE_PARK_DIR — e.g. an Obsidian vault folder
  or any synced dir), so it survives the 30-day transcript cleanup and can be
  revived later (even on another machine) with /unpark.
  Use when: (1) user invokes /park, (2) user is about to close/abandon a
  background session and wants to be able to pick it up weeks later,
  (3) user says "save this context", "park this", "snapshot this session",
  "I want to be able to come back to this".
  Companion to /unpark, which searches parked notes AND live sessions.
user-invocable: true
version: 1.1.0
---

# Park: snapshot a session to a durable note for later revival

Native `claude --resume` and `/unpark` can already reopen a session *while its
transcript exists* — but background-session transcripts are auto-deleted after
~30 days (`cleanupPeriodDays`), live only on one machine, and are hard to find by
topic among dozens of cryptic job IDs. **Park** fixes that: it writes a durable,
topic-named markdown handoff into a directory you pick. It's the thing you run
*before you stop caring about a session* but might want it back.

## Where parked notes go (configurable — do NOT hardcode a path)

Resolve the park directory in this order:

1. `$CLAUDE_PARK_DIR` if set — this is the user's chosen location (often an
   Obsidian vault subfolder, a Dropbox/iCloud dir, etc.).
2. Otherwise the default `~/.claude-park`.

Resolve and ensure it exists with one shell call before writing:

```bash
PARK_DIR="${CLAUDE_PARK_DIR:-$HOME/.claude-park}"; mkdir -p "$PARK_DIR"; echo "$PARK_DIR"
```

Write one note per parked session as `$PARK_DIR/YYYY-MM-DD-<slug>.md` (slug =
kebab-case of the title). `/unpark` reads from the same `$CLAUDE_PARK_DIR` /
default, so the two always agree.

> **First-time tip:** if the user wants these in their Obsidian vault (so they're
> searchable there and sync across machines), tell them to set `CLAUDE_PARK_DIR`
> to a folder inside their vault — e.g. via the `env` block in
> `~/.claude/settings.json` or their shell profile. Don't assume they use
> Obsidian; the local default works for everyone.

## Which session to park

- **No argument → park THIS session.** You already hold the full context in your
  window — synthesize directly. Don't parse your own transcript.
- **An argument describing another background session** (e.g. `/park the payroll fix`)
  → that's a different live session. Get its snapshot first via the unpark helper,
  then write the note from that output:
  ```bash
  node ~/.claude/skills/unpark/unpark.mjs "the payroll fix"
  ```
  (or `bun` if node is missing). Use the printed goal / last status / recent
  activity as your source material.

## What to capture (the note body)

Synthesis over dump. The reader is a future Claude (or the user) with **zero**
memory of this session. Give them exactly enough to continue without re-deriving.
Pull the non-obvious stuff — decisions, constraints, findings — that isn't already
in code, git, or a ticket.

Write the file with this exact frontmatter + structure:

```markdown
---
type: claude-session-park
title: <short human title — what this work IS>
parked: <today's date, YYYY-MM-DD>
session_id: <full session id if known, else "">
short_id: <8-char job id if known, else "">
cwd: <working directory>
branch: <git branch, or n/a>
prs: [<pr numbers if any>]
status: <active | blocked | done | abandoned>
tags: [claude-session]
---

# <Title>

## Goal
What this session was trying to accomplish, in product terms.

## State — where it left off
What's done, what's in flight, what's blocked. Be concrete.

## Key decisions & context
Non-obvious choices, constraints, dead-ends, and findings that a fresh session
would otherwise have to rediscover. This is the highest-value section — favor it.

## Files & artifacts
- Files/dirs touched (with paths), PRs, branches, docs, dashboards.

## Next steps
1. Concrete next action (not vague status).
2. ...

## To revive
cwd `<cwd>`, branch `<branch>`. One line on how to pick the thread back up.
```

## How to find the session metadata

For the current session, the job short-id is in `$CLAUDE_JOB_DIR` (basename) and
the cwd/branch you know. PRs you've opened this session go in `prs:`. If you don't
know a field, leave it blank rather than guessing — don't fabricate IDs.

## After writing

Confirm in one line: the note title, its path, and that it's findable via
`/unpark <topic>`. Don't read the file back to verify — Write errors if it failed.

## Related

- **/unpark** — the pickup side: searches these parked notes *and* live background
  sessions, then resumes or revives.
- **/recap** — in-session status dump (not saved to disk).
- **/linear-dump** — durable handoff to a Linear ticket (for ticketed work).
