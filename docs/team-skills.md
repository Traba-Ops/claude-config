# Team-scoped skills

## Problem

Core Prometheus skills already update for everyone automatically: the repo is the
single source of truth, and each person's launchd job pulls hourly. But skills one
person writes for their *team* (a customer-facing output format, an escalation
playbook) live only in that person's `~/.claude` — when they iterate, nobody else
gets the change. People want a "slide master": edit once, the whole team picks it up.

## Model

One repo, segmented by team — not a repo per team.

```
claude-config/
  skills/                       # core — everyone gets these (tracked in place)
  rules/                        # always-on rules — everyone
  teams/
    customer-ops/skills/...     # only customer-ops
    worker-ops/skills/...       # only worker-ops
    scaled-ops/skills/...       # only scaled-ops
  sync.sh                       # team-aware updater (replaces `git pull`)
  CODEOWNERS                    # who can approve what
```

Why one repo over one-per-team: a single install, a single launchd job, a shared
`core` set, no cross-team copy-paste drift, and promoting a team skill to org-wide is
moving a folder. Per-team *ownership* is still clean via `CODEOWNERS`.

## Routing: "what team are you on?"

A single line in `~/.claude/team` (e.g. `customer-ops`) is the only piece of state
that drives routing. It's captured once by the installer (with a conversational
fallback — Claude can write it if it's missing), is user-local, and survives every
`git pull`. Most people are on one team; switching teams is just rewriting that file
("I moved to scaled-ops" → Claude updates it).

## Sync

`sync.sh` is the new launchd update command (was `cd ~/.claude && git pull`):

1. `git pull` the shared config.
2. Read `~/.claude/team`.
3. Remove any skill in `~/.claude/skills/` that is a symlink into `teams/` (clean
   slate for team switches; personal and core skills are never touched).
4. Symlink the current team's skills from `teams/<team>/skills/` into
   `~/.claude/skills/`.

`~/.claude` is itself the git checkout, so core `skills/` and `rules/` are already in
place after a pull. Only team skills need materializing, hence the symlinks.

## Merge gating

`CODEOWNERS` + "Require review from Code Owners" branch protection on `main`:

- `skills/`, `rules/`, `docs/`, `install.sh`, `sync.sh`, `CODEOWNERS` → **engineering**
  (ships to everyone).
- `teams/<team>/` → **engineering OR that team's leads** (one approval is enough).

This keeps eng in the loop for anything org-wide and for an extra set of eyes on team
content, while letting team leads own their own folder. Authoring stays frictionless —
the publish flow opens a PR on the operator's behalf; the gate is on *merge*, not on
writing.

## To turn on (operational, not in this PR)

- Enable branch protection on `main` with "Require review from Code Owners."
- Create GitHub teams `customer-ops-leads`, `worker-ops-leads`, `scaled-ops-leads`
  (or replace those handles in `CODEOWNERS` with individual usernames).
- A `/share-skill` skill that opens the PR for non-technical teammates is the natural
  next step (not included here).
