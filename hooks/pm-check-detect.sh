#!/usr/bin/env sh
# UserPromptSubmit hook: when a prompt looks like a request to BUILD something,
# mark the session as build-shaped and remind the agent to run the PM check
# (the `pm-check` skill) before writing code.
#
# This hook only marks and nudges. The actual gate is hooks/pm-check-gate.sh,
# which refuses Write/Edit until the check has run. Splitting them keeps the
# search cost off prompts that never write anything.
#
# Never blocks a prompt: any failure exits 0 and the turn proceeds normally.
#
# Pure POSIX sh — no jq, no node. Runs wherever Claude Code runs a command hook.

set -u

state_dir="${TMPDIR:-/tmp}"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Global opt-out, so the gate is a guardrail and not a wall. A documented,
# deliberate bypass beats people uninstalling the bundle to get work done.
[ -f "$claude_dir/.pm-check-off" ] && exit 0
[ "${CLAUDE_PM_CHECK:-}" = "off" ] && exit 0

payload=$(cat 2>/dev/null) || exit 0

# Extract a JSON string field without jq. Takes the first match; good enough for
# session_id (opaque, no escapes) and prompt_text (we only lowercase-match it).
json_str() {
  printf '%s' "$payload" |
    tr -d '\n' |
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -1
}

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

prompt=$(json_str prompt_text | tr '[:upper:]' '[:lower:]')
[ -n "$prompt" ] || exit 0

# Build-shaped = an intent verb AND an artifact noun. Requiring both keeps
# "add a comment", "create a variable", and "write a test" from tripping it.
echo "$prompt" | grep -qE '(build|create|add|implement|make|set up|setup|spin up|write) ' || exit 0
echo "$prompt" | grep -qE '\b(app|tool|dashboard|workflow|agent|bot|script|endpoint|page|report|integration|service|automation|pipeline|job|cron)\b' || exit 0

pending="$state_dir/claude-pm-check-$session_id.pending"
done_flag="$state_dir/claude-pm-check-$session_id.done"

# Already checked this session — don't nag again.
[ -f "$done_flag" ] && exit 0

: > "$pending" 2>/dev/null || exit 0

# Backslashes and double quotes would break the JSON string. Paths here are a
# temp dir plus a UUID, but escape anyway rather than emit invalid JSON.
escaped_done=$(printf '%s' "$done_flag" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
  "This looks like a request to build something. Before writing any code, invoke the pm-check skill — it runs Traba pre-build checks (does this already exist, should it be a Neutron capability instead, which data path, does the output land back in the system, who owns it) via Neutron. Write and Edit are BLOCKED until it has run. If the check genuinely does not apply, say why in one line, then run: touch '$escaped_done'"

exit 0
