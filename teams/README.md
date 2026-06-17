# Team skills

Skills in here are scoped to one team. They sync to you only if your
`~/.claude/team` says you're on that team.

```
teams/
  customer-ops/skills/   # only customer-ops gets these
  worker-ops/skills/     # only worker-ops gets these
  scaled-ops/skills/     # only scaled-ops gets these
```

**Why this exists:** so a team can standardize how Claude does its work —
customer-facing output formats, escalation playbooks, naming conventions —
and have every teammate pick up changes automatically, instead of each person
keeping their own copy. Edit once, everyone on the team has it within the hour.
It's the PowerPoint slide-master idea, for Claude skills.

## How it flows

1. You author or edit a skill under your team's folder (the `/share-skill`
   skill opens the PR for you — you never touch git).
2. A reviewer merges it (eng or your team lead — see `/CODEOWNERS`).
3. Everyone on that team runs `sync.sh` hourly via launchd, which pulls the
   change and links the skill into their `~/.claude/skills/`.

Core skills in the repo's top-level `skills/` go to everyone regardless of team.

## Adding a skill

Drop a directory with a `SKILL.md` under `teams/<your-team>/skills/<skill-name>/`.
Same format as core skills. See `customer-ops/skills/customer-output-format/`
for a starter you can copy.
