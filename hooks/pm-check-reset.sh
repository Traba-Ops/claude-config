#!/usr/bin/env sh
# SessionStart hook: clear this session's PM-check marks, and sweep marks left
# behind by sessions that have since ended.
#
# Without the sweep, /tmp accumulates one or two empty files per build-shaped
# session forever. The per-session clear covers the reverse: a session id that
# comes back around — `/clear`, or a reused id after a crash — must not inherit a
# gate armed by whatever ran under it before.
#
# On `resume`, `fork`, and `compact` the marks are deliberately KEPT: those all
# continue a session that may be mid-build, and UserPromptSubmit does not re-fire
# for the past turn to re-apply the gate. `compact` matters most — it fires on
# AUTO-compaction, and long build sessions are precisely the ones that hit it.
#
# `clear` is NOT exempt. `/clear` is an explicit request to start over: the
# build request is gone from context, so a gate the agent can no longer explain
# would just get touched away. The next build-shaped prompt re-arms it.
#
# It also publishes the session's completion-flag path as `CLAUDE_PM_CHECK_DONE`,
# so the pm-check skill can record completion. The skill falls back to building
# the path from `$CLAUDE_CODE_SESSION_ID`, but this value is derived from the
# session id the hook was actually handed, so it is exact even in the cases where
# that variable can report the startup id instead (`--continue`).
#
# Never blocks session start: any failure exits 0.

set -u

state_dir="${TMPDIR:-/tmp}"

payload=$(cat 2>/dev/null) || exit 0

json_str() {
  printf '%s' "$payload" |
    tr -d '\n' |
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -1
}

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

done_flag="$state_dir/claude-pm-check-$session_id.done"

# Sweep old marks regardless of source — cheap, and it is the only thing that
# ever cleans up after a crashed session. `-mtime +1` is "more than one whole
# 24h period", i.e. 48h and up, not 24h; the long window is deliberate, since
# the sweep is unconditional and a shorter one is likelier to lift the gate on a
# session that is still alive. Cleanup latency does not matter here.
#
# THIS SESSION'S marks are excluded, and the exclusion is the whole point of
# running the sweep after `session_id` is known. SessionStart re-fires on
# auto-compaction, so without it a build session still running after 48h has its
# own `.pending` swept the moment it compacts — silently lifting the gate in
# exactly the case the `compact` exemption below exists to protect.
find "$state_dir" -maxdepth 1 -name 'claude-pm-check-*' -type f -mtime +1 \
  ! -name "claude-pm-check-$session_id.*" \
  -exec rm -f {} + 2>/dev/null || true

# Publish the completion-flag path to the session. `CLAUDE_ENV_FILE` is a
# SessionStart-only facility: exports appended here are picked up by every
# subsequent Bash tool call, so the skill can run `touch "$CLAUDE_PM_CHECK_DONE"`
# instead of reconstructing a session id it has no way to see. Written before
# the source check below so resumed, forked, and compacted sessions get it too.
#
# Appended only if it is not already there. SessionStart re-fires on every
# compaction, and a long session compacts many times, so an unconditional `>>`
# grows the env file by one duplicate export per compaction for the whole
# session. The value is identical each time, so a plain presence check is
# enough.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  quoted=$(printf '%s' "$done_flag" | sed "s/'/'\\\\''/g")
  export_line=$(printf "export CLAUDE_PM_CHECK_DONE='%s'" "$quoted")
  if ! grep -qxF "$export_line" "$CLAUDE_ENV_FILE" 2>/dev/null; then
    printf '%s\n' "$export_line" >> "$CLAUDE_ENV_FILE" 2>/dev/null || true
  fi
fi

case "$(json_str source)" in
  resume | fork | compact) exit 0 ;;
esac

rm -f "$state_dir/claude-pm-check-$session_id.pending" \
      "$state_dir/claude-pm-check-$session_id.done" 2>/dev/null || true

exit 0
