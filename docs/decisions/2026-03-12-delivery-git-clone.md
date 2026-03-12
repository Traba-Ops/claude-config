# Delivery Mechanism: Git Clone + Copy (replaces Skillshare)

## Context
The 2026-03-10 decision chose skillshare for distributing the Prometheus skills bundle. During implementation, we discovered that skillshare cannot distribute `~/.claude/rules/` files from a tracked repo — extras (rules) source from a sibling directory (`~/.config/skillshare/rules/`), not from inside tracked repos. Bridging this requires symlinks and config editing, adding complexity for non-technical operators.

## Approaches Considered

### Option 1: Skillshare with symlink bridge
Keep skillshare for skills. Symlink `~/.config/skillshare/rules/` to the tracked repo's `rules/` directory, add extras config to `config.yaml`. Works but requires explaining symlinks and YAML editing to operators.

### Option 2: Skillshare for skills, manual copy for rules
Skillshare handles skills natively. Separate `cp` commands for rules. Two mechanisms for one bundle.

### Option 3: Claude Code native plugins
Strongest native option with auto-update and marketplace UI. But plugins cannot distribute `~/.claude/rules/` files at all. Only skills.

### Option 4: Git clone + copy
Clone the repo once, copy `skills/` and `rules/` into `~/.claude/`. Launchd job pulls and re-copies twice daily. No external tooling.

### Option 5: AI Rules Sync (`ais`)
Third-party tool that handles both skills and rules. No auto-update. npm dependency.

## Decision
Option 4: git clone + copy. Supersedes the 2026-03-10 skillshare decision.

- 3 bash commands for setup, 1 Claude prompt for launchd
- No external dependencies (git is already installed)
- Handles both skills and rules identically
- Auto-updates via launchd (`git pull && cp -r`)
- Repo: `Traba-Ops/claude-config` with `skills/` and `rules/` at root

Operators who also use Aiden's engineering skills still install those via skillshare (`trabapro/skillhub-core`). Two distribution systems, but each is simple on its own and serves a different audience.
