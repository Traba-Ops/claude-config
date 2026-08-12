#!/usr/bin/env sh
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): refuse to write code in a
# session marked build-shaped by hooks/pm-check-detect.sh until the check ran.
#
# Bash is deliberately left ungated even though `cat > file` writes: the skill
# needs Bash to record its own completion, so gating it would deadlock.
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
# Guarded HOME — see pm-check-detect.sh.
claude_dir="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"


payload=$(cat 2>/dev/null) || exit 0

# Greedy `.*`, so this anchors on the last occurrence of the field. Both fields
# read here are opaque identifiers with no escapes.
#
# The read is capped at 8KB, and the cap is the difference between a hook that
# is free and one that taxes the whole org. A PreToolUse payload embeds
# `tool_input.content`, so its size tracks the file being written: unbounded,
# this scan costs ~49ms at 200KB, ~353ms at 2MB, and ~1.4s at 8MB, on EVERY
# Write and Edit including the sessions that are never gated. Both fields sit in
# the first few hundred bytes.
json_str() {
  printf '%s' "$payload" |
    head -c 8192 |
    tr -d '\n' |
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -1
}

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

pending="$state_dir/claude-pm-check-$session_id.pending"
done_flag="$state_dir/claude-pm-check-$session_id.done"

# Checked before the agent_id scan below: the overwhelmingly common case is a
# session that never asked to build anything, and this is a stat, not a parse.
# Not a build-shaped session, or the check already ran — allow.
[ -f "$pending" ] || exit 0
[ -f "$done_flag" ] && exit 0

# Subagent writes are not gated. PreToolUse fires inside subagents carrying the
# PARENT's session_id plus an `agent_id` — present only inside a subagent call.
# Without this, delegating implementation produces a denial inside an agent that
# never saw the detector's injected context and cannot run the check
# meaningfully; its only way out is to `touch` the flag, which teaches exactly
# the bypass reflex this hook exists to prevent. The parent session stays gated
# for its own writes, and the parent is where the decision to build is made.
#
# Two consequences worth stating plainly rather than discovering later:
#   - Delegating the implementation to a subagent lands the build entirely
#     unchecked. That is routine in this org, so the gate is a prompt for
#     thought at the point the human asks, not an enforcement boundary.
#   - This is load-bearing on `agent_id` being absent in the main loop. If a
#     future Claude Code populates it there, this line disables the gate for
#     everyone, silently and with no error. The pm-check-hooks test suite pins
#     the behaviour in both directions; if it ever starts failing on the
#     main-thread case, that is this assumption breaking, not a flaky test.
[ -n "$(json_str agent_id)" ] && exit 0


# Published for recovery, not as a bypass — see the note in pm-check-detect.sh.
escaped_done=$(printf '%s' "$done_flag" | tr -d '[:cntrl:]' | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_script=$(printf '%s' "$claude_dir/hooks/pm-check-done.sh" |
  tr -d '[:cntrl:]' | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
  "Blocked: this session asked to build something and the Traba PM check has not run. Invoke the pm-check skill first — it checks whether this already exists (Traba-Ops has over 100 repos and 67 Railway projects), whether it should be a Neutron capability rather than a new app, the data path, whether the output lands back in the system, and who owns it. The skill records completion itself when it finishes. There is no bypass — run the check. If the recording fails, re-run it as: '$escaped_script' '$escaped_done'"

exit 0
