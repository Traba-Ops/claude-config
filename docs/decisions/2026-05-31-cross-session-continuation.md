# Cross-Session Continuation: Read-the-Work, Not Message-Passing

## Context
Operators increasingly run several Claude Code sessions at once (`claude agents` / `--bg`). The recurring ask isn't "let my sessions chat in real time" — it's "from this session, go look at what that other session did and continue it." We needed a way to pull one background session's work into another, packaged so the whole team gets it via the skills bundle.

## Approaches Considered

### Option 1: File-based mailbox + hooks
A shared `~/.claude/mailbox/` drop-box, with `UserPromptSubmit`/`SessionStart` hooks polling it and injecting messages. Gives sessions a way to "message" each other.
- Real-time push into an idle session is impossible anyway (Claude Code has no timer/polling hook — a session only notices a message when it next acts), so it's a lazy mailbox, not a phone call.
- Solves a problem operators don't actually have: they don't want chatter between sessions, they want to absorb a session's output.

### Option 2: Native `SendMessage`
Claude Code's built-in `SendMessage` tool.
- Team-scoped: a session can only message teammates a **lead spawned** (or background agents it spawned, by id). Two independently-started sessions aren't teammates, so they can't address each other.
- There is no `claude send <id>` shell command to push into an arbitrary running session.
- Wrong primitive for "independent sessions."

### Option 3: `claude logs <id>`
Read the other session's output via the CLI.
- Returns raw ANSI/TTY screen-redraw escape codes — unusable as model context. Also only works while the process is alive.

### Option 4: Read local session state directly (chosen)
A small Node helper reads what Claude Code already persists on disk:
- `claude agents --json` → the live session roster.
- `<config>/jobs/<short-id>/state.json` → each session's **goal** (`intent`) and **last status** (`detail`) — clean, human-readable, no transcript parsing needed for the gist.
- `<config>/projects/*/<session-id>.jsonl` → the transcript, for a recent-activity trail.

It scores a free-text hint against name + goal + status, so "the payroll flaky-test fix" resolves to the right session even when its auto-name differs.

## Decision
Option 4, shipped as the **`continue-from`** skill (`skills/continue-from/`). It's a one-way "read the other session's work and continue here" — no messaging, no mutation of the other session. The skill auto-triggers on natural language ("continue from the session where I was doing X"), so operators don't memorize a command.

Rejected message-passing (Options 1–2) because the real need is absorbing output, not live chat; rejected `claude logs` (Option 3) because its output isn't usable context. For the cases where sessions genuinely should collaborate in real time, the answer is **agent teams** (documented in `docs/multi-session.md`), not a hand-rolled mailbox.

## Notes
- The helper honors `CLAUDE_CONFIG_DIR` (falls back to `~/.claude`) so it works regardless of where an operator keeps their config.
- Matching reads goal + status only, not the full transcript body, to stay fast; the goal usually captures the gist, and an operator can pass the 8-char short id to pin an exact session.
