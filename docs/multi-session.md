# Running More Than One Claude

You don't have to work with a single Claude at a time. You can have several going
at once — one fixing a bug, one writing a doc, one researching — and move between
them. This page covers the three ways to do that and when each one fits.

| You want to… | Use | Do they talk to each other? |
|---|---|---|
| Run several independent tasks and check back on each | **Background sessions** (`claude agents`) | No — you move between them |
| Pick up one session's work inside another | **`continue-from` skill** | No — one reads the other's work |
| Have several Claudes collaborate on one task in real time | **Agent teams** | Yes — directly, by name |

---

## 1. Background sessions — `claude agents`

The simplest way to run things in parallel. Each background session is a full
Claude conversation that keeps running on its own, even after you close the window.

- Open the dashboard: run `claude agents` in your terminal. You get one screen
  showing every session — what it's doing, which ones need you, which are done.
- Start a task: type a prompt and press Enter. It runs in the background.
- Send an existing session to the background: type `/bg` inside it.
- Check in: select a row and press Space to peek, or Enter to open it fully.

Reach for this when you have a few separate things you want Claude working on and
you'll check back when each needs you. Note: each session uses your usage quota
independently, so a handful at once burns through quota faster than one.

## 2. Continue one session's work in another — the `continue-from` skill

Sometimes you're in one session and want to pick up what a *different* background
session was doing — "continue the work from the session where I was fixing
payroll." That's the `continue-from` skill (installed automatically with the
Traba skills).

Just say it in plain English:

> "Continue from the session where I was doing the payroll flaky-test fix."

Claude finds that session by **what it was working on** (not just its name), pulls
in its goal and recent progress, and keeps going from where it left off. The other
session is left untouched — this is "read its work and continue," not live chat.

If you don't remember which session, just ask "what were my other sessions working
on?" and Claude will list them with a one-line summary of each.

## 3. Agent teams — Claudes that collaborate in real time

Agent teams let several Claude sessions work on **one task together** and message
each other directly while they work. One session is the "lead" — it spins up the
others (its "teammates"), hands out the work, and pulls the results together. This
is different from the options above, where sessions don't talk to each other.

It's best for work where parallel effort genuinely helps and the pieces are
independent — for example:

- **Reviewing something from several angles at once** (one teammate on correctness,
  one on security, one on tests).
- **Investigating a tricky bug** with competing theories, where teammates argue
  each other's ideas down until the real cause survives.
- **Building separate pieces in parallel** where each teammate owns different files.

Agent teams use **a lot more usage** than a single session (each teammate is its
own full Claude), so use them when the parallelism is worth it — research, review,
and multi-part features — not for routine single-track work.

### Enabling agent teams

Agent teams are an experimental feature that's **off by default**. To turn it on,
open **Claude Code** and ask:

> "Add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to the `env` block of my
> settings.json to enable agent teams."

Claude will edit `~/.claude/settings.json` for you. Then **restart Claude Code** —
the setting is read at startup, so it won't take effect in the current session.

(Requires Claude Code v2.1.32 or later. Check with `claude --version`; if you're
behind, run `claude update`.)

### Using agent teams

Once it's enabled and you've restarted, just describe the team in plain English.
The session you're in becomes the lead:

> "Create an agent team to review this PR. Spawn three reviewers — one on
> correctness, one on security, one on tests — and have them report back."

While it runs:

- **In-process mode** (the default, works in any terminal): press `Shift+Down` to
  cycle through teammates and type to message one directly.
- **Split panes** (each teammate in its own pane): requires `tmux` or iTerm2. Nice
  for watching everyone at once, optional.
- When you're done, say **"clean up the team."**

Start with a **review or research** team first — clear boundaries, no risk of two
teammates editing the same file — before trying parallel coding. If a teammate
gets stuck, you can open it (`Shift+Down`, then Enter) and give it instructions
directly, or tell the lead to spawn a replacement.

> **Heads up — it's experimental.** A few rough edges to know about: resuming a
> session doesn't restore its teammates (tell the lead to spawn new ones), task
> status can occasionally lag, and only the lead can manage the team (teammates
> can't spawn their own). None are blockers — just don't be surprised by them.
