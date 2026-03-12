# Skills Bundle Delivery Mechanism

## Context
Need to distribute Claude skills (design system, deployment, project setup) and always-active rules (constitution) to operators, with auto-propagating updates. Can't overwrite users' existing CLAUDE.md files.

## Approaches Considered

### Option 1: Template repo only
Everything ships per-project via GitHub template. Simple but updates don't auto-propagate — operators run stale skills.

### Option 2: Plugin marketplace (Claude Code native)
Native to Claude Code, auto-updates. But can't distribute rules or CLAUDE.md, only skills. Requires `extraKnownMarketplaces` bridge in settings.json. More setup steps for users.

### Option 3: Skillshare
One binary, one `skillshare install --track` command. Handles both skills (`~/.claude/skills/traba/`) and constitution (`~/.claude/rules/traba.md` via extras). Auto-updates with `skillshare update --all`. External dependency but trivial to install.

### Option 4: Launchd git pull
Clone a repo to `~/.claude/skills/traba/`, launchd job runs `git pull` hourly. Simple but doesn't handle the rules/ copy, and launchd setup is manual per-operator.

## Decision
Option 3 (Skillshare) for everything. No template repo needed.

- Skills → `~/.claude/skills/traba/` (design system, deployment, project setup)
- Rules → `~/.claude/rules/` via skillshare extras, split into two files:
  - `traba-constitution.md` (role, principles, security, development hygiene)
  - `traba-spec.md` (README as living spec, session summaries, decision records, periodic consolidation)
- Project scaffolding files (.gitignore, .pre-commit-config.yaml) → reference files inside the project-setup skill directory. Claude reads them during scaffolding and creates the files.

One repo (`traba-ops/claude-skills`), one delivery mechanism, auto-propagating updates. Auto-propagation is the key requirement — stale skills defeat the purpose of the framework.
