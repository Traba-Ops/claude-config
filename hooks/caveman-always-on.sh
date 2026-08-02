#!/usr/bin/env sh
# SessionStart hook: injects the full caveman ruleset when the user has opted in
# by creating $CLAUDE_CONFIG_DIR/.caveman-always (default ~/.claude).
# Optional: put an intensity level in that file (lite|full|ultra). Empty or
# unrecognized means the default (full).
# Never blocks session start: any failure exits 0.
#
# Mirrors the i-have-adhd plugin's always-on.sh.

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
flag_path="$claude_dir/.caveman-always"

[ -f "$flag_path" ] || exit 0

skill_path="$claude_dir/skills/caveman/SKILL.md"
[ -f "$skill_path" ] || exit 0

# Only the three known intensity levels are honored; anything else (typo, empty
# file, stray content) falls back to the skill default.
level=$(head -n 1 "$flag_path" 2>/dev/null | tr -d '[:space:]')
case "$level" in
  lite|full|ultra) ;;
  *) level=full ;;
esac

# Strip a leading YAML frontmatter block (--- ... --- at the very top of file).
body=$(awk '
  NR == 1 && $0 ~ /^---[[:space:]]*$/ { in_fm = 1; next }
  in_fm && $0 ~ /^---[[:space:]]*$/   { in_fm = 0; next }
  !in_fm                              { print }
' "$skill_path") || exit 0

printf 'CAVEMAN MODE ACTIVE (always-on), intensity: %s. Apply the **%s** row of the intensity table in the ruleset below to every response. This stated intensity is authoritative: it overrides any default intensity the ruleset names for itself. "stop caveman" or "normal mode" turns it off for this session; delete %s to turn always-on off for good.\n\n%s\n' \
  "$level" "$level" "$flag_path" "$body"
