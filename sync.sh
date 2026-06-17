#!/bin/bash
# Prometheus team-aware sync.
#
# Pulls the shared config and materializes the right skills into ~/.claude/skills/:
#   - core skills (skills/)      -> everyone, tracked in place by git
#   - your team's skills         -> symlinked in from teams/<team>/skills/
#
# Your team is read from ~/.claude/team (a single line, e.g. "customer-ops").
# Change teams by rewriting that file — just tell Claude "I moved to scaled-ops".
#
# This replaces the old `cd ~/.claude && git pull` as the launchd update command.
set -e

CLAUDE_DIR="$HOME/.claude"
cd "$CLAUDE_DIR"

# 1. Pull the latest shared config.
git pull --quiet || { echo "sync: git pull failed" >&2; exit 1; }

# 2. Which team are you on? (single team; empty = core only)
TEAM=""
[ -f "$CLAUDE_DIR/team" ] && TEAM=$(tr -d '[:space:]' < "$CLAUDE_DIR/team")

# 3. Clear any previously-materialized team skills so a team switch is clean.
#    We only remove symlinks that point into teams/ — personal and core skills
#    are never touched.
for link in "$CLAUDE_DIR"/skills/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    *"/teams/"*) rm -f "$link" ;;
  esac
done

# 4. Materialize the current team's skills into skills/.
if [ -n "$TEAM" ] && [ -d "$CLAUDE_DIR/teams/$TEAM/skills" ]; then
  count=0
  for skill in "$CLAUDE_DIR/teams/$TEAM/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    ln -sfn "../teams/$TEAM/skills/$name" "$CLAUDE_DIR/skills/$name"
    count=$((count + 1))
  done
  echo "sync: core skills + $count $TEAM skill(s) up to date"
else
  if [ -n "$TEAM" ]; then
    echo "sync: core skills up to date (team '$TEAM' has no skills folder yet)"
  else
    echo "sync: core skills up to date (no team set — write your team to ~/.claude/team)"
  fi
fi
