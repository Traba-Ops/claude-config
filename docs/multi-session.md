# Running More Than One Claude

You can run several Claude Code sessions at once — each on its own task. Two extra
tools make working across them easy.

## Pick up another session's work — the `park` / `unpark` skills

You run sessions in the background with `claude agents` (or `claude --bg`); that
dashboard shows everything that's running. When you want to pick up what one of
those sessions was doing inside your current session, just say so in plain English:

> "Continue from the session where I was doing the payroll flaky-test fix."

Claude (via the `unpark` skill) finds that session by **what it was working on**
(not just its name), pulls in its goal and recent progress, and keeps going from
there. The other session is left untouched. If you don't remember which one, ask
"what were my other sessions working on?" and Claude will list them with a one-line
summary of each.

**The catch with live sessions:** background transcripts are auto-deleted after
~30 days, live on only one machine, and get hard to find among dozens of cryptic
job IDs. So before you close a session you might want back later, **park it**:

> "Park this session."

That writes a durable, human-readable snapshot (goal, decisions, where it left off,
next steps) into a folder you choose — set `CLAUDE_PARK_DIR` to an Obsidian vault
folder or any synced directory, or it defaults to `~/.claude-park`. Later, the same
`unpark` request searches **both** live sessions *and* parked snapshots, so it can
**revive a dead session** from its note long after the transcript is gone — even on
another machine. One command, two sources: resume what's alive, revive what's parked.

## Agent teams — Claudes that collaborate on one task

Agent teams let several Claude sessions work on **one task together** and message
each other directly while they work. One session is the "lead" — it spins up the
others, hands out the work, and pulls the results together. They're good for
reviewing something from several angles at once, investigating a tricky bug with
competing theories, or building separate pieces in parallel. Each teammate is its
own full Claude, so teams use a lot more usage than a single session — reach for
them when the parallelism is worth it.

### Enable it

Agent teams are experimental and off by default. Open **Claude Code** and ask:

> "Add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to the `env` block of my
> settings.json to enable agent teams."

Then **restart Claude Code** — the setting is read at startup. (Requires Claude
Code v2.1.32 or later; run `claude update` if you're behind.)

### Use it

Once it's enabled and you've restarted, describe the team in plain English. The
session you're in becomes the lead:

> "Create an agent team to review this PR — one teammate on correctness, one on
> security, one on tests — and have them report back."

While it runs, press `Shift+Down` to cycle through teammates and type to message
one directly. Say **"clean up the team"** when you're done. Start with review or
research tasks first — clear boundaries, no risk of two teammates editing the same
file. It's experimental, so expect a couple of rough edges: resuming a session
doesn't restore its teammates (tell the lead to spawn new ones), and only the lead
can manage the team.
