#!/usr/bin/env sh
# PreToolUse hook (Write|Edit|MultiEdit): refuse to write code in a session that
# was marked build-shaped by hooks/pm-check-detect.sh until the PM check has run.
#
# Fires ONLY when the .pending mark exists and the .done mark does not, so a
# session that never asked to build anything is never gated. That narrowness is
# deliberate — a hook that blocks every edit gets uninstalled the first day.
#
# Fails OPEN by design: Claude Code treats a non-zero exit other than 2 as a
# non-blocking error and lets the tool through. So a broken hook degrades to no
# guardrail rather than to a wedged session.
#
# Pure POSIX sh — no jq, no node.

set -u

state_dir="${TMPDIR:-/tmp}"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Same opt-outs as the detector, checked again here: a session that opted out
# mid-flight should stop being gated immediately.
[ -f "$claude_dir/.pm-check-off" ] && exit 0
[ "${CLAUDE_PM_CHECK:-}" = "off" ] && exit 0

payload=$(cat 2>/dev/null) || exit 0

session_id=$(printf '%s' "$payload" |
  tr -d '\n' |
  sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
  head -1)
[ -n "$session_id" ] || exit 0

pending="$state_dir/claude-pm-check-$session_id.pending"
done_flag="$state_dir/claude-pm-check-$session_id.done"

# Not a build-shaped session, or the check already ran — allow.
[ -f "$pending" ] || exit 0
[ -f "$done_flag" ] && exit 0

escaped_done=$(printf '%s' "$done_flag" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
  "Blocked: this session asked to build something and the Traba PM check has not run. Invoke the pm-check skill first — it checks whether this already exists (Traba-Ops has 96 repos and 67 Railway projects), whether it should be a Neutron capability rather than a new app, the data path, whether the output lands back in the system, and who owns it. The skill records completion itself. To proceed without it, state why in one line and run: touch '$escaped_done'"

exit 0
