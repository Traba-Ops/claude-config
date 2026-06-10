---
name: park
description: |
  Snapshot this session's working context to a durable note in
  $CLAUDE_PARK_DIR so it survives transcript cleanup and can be revived with
  /unpark. Use for /park, "park this", "save/snapshot this context",
  "I want to come back to this".
user-invocable: true
version: 1.2.0
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

One note per **session** — not one per park. A not-yet-parked session writes a new
`$PARK_DIR/YYYY-MM-DD-<slug>.md` (slug = kebab-case of the title); re-parking a
session that's already parked updates that same file in place (see *Re-parking is
idempotent* below — this is the common case, since you park, unpark, work more, and
park again). `/unpark` reads from the same `$CLAUDE_PARK_DIR` / default, so the two
always agree.

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

## Re-parking is idempotent — update, don't duplicate

A session is parked **once**, then updated. If you unpark a session, do more work,
and `/park` it again, update the existing note in place — never mint a second dated
file for the same session. The match key is the session identity in frontmatter
(`session_id`, else `short_id`) — **not** the filename, since the date prefix and
title both drift between parks.

Before writing, look for an existing note for this session:

```bash
PARK_DIR="${CLAUDE_PARK_DIR:-$HOME/.claude-park}"; mkdir -p "$PARK_DIR"
SHORT="$(basename "${CLAUDE_JOB_DIR:-}")"   # this session's short id ("" if unknown)
# Parking ANOTHER session via the unpark helper? Use the short_id it printed instead.
EXISTING=""
[ -n "$SHORT" ] && EXISTING="$(grep -rlE "^(session_id|short_id): *${SHORT}$" "$PARK_DIR"/*.md 2>/dev/null | head -1)"
echo "PARK_DIR=$PARK_DIR"; echo "SHORT=$SHORT"; echo "EXISTING=${EXISTING:-<none — new note>}"
```

- **`EXISTING` is a path → update it.** Overwrite that exact file. Keep its original
  filename and its original `parked:` date; refresh the whole body, bump `status:`,
  and set `updated:` to today.
- **`EXISTING` is empty → create.** Write a fresh `$PARK_DIR/YYYY-MM-DD-<slug>.md`.

If neither `session_id` nor `short_id` is knowable (rare), fall back to matching an
existing note with the same `<slug>` before creating one.

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
parked: <date first parked, YYYY-MM-DD — keep the original on re-park>
updated: <today's date, YYYY-MM-DD>
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

Confirm in one line: whether you **created or updated** the note, its title, its
path, and that it's findable via `/unpark <topic>`. Don't read the file back to
verify — Write errors if it failed.

## Related

- **/unpark** — the pickup side: searches these parked notes *and* live background
  sessions, then resumes or revives.
- **/recap** — in-session status dump (not saved to disk).
- **/linear-dump** — durable handoff to a Linear ticket (for ticketed work).
