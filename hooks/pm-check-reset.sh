#!/usr/bin/env sh
# SessionStart hook: clear this session's PM-check marks, and sweep marks left
# behind by sessions that have since ended.
#
# Without the sweep, /tmp accumulates one or two empty files per build-shaped
# session forever. Without the per-session clear, a `--fork` that inherits a
# session id would start already-cleared or already-gated depending on timing.
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
# It also publishes the session's completion-flag path as an environment
# variable, which is the only way the pm-check skill can record completion — an
# agent cannot see its own session id.
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

# Sweep old marks regardless of source — cheap, and it is the only thing that
# ever cleans up after a crashed session. `-mtime +1` is "more than one whole
# 24h period", i.e. 48h and up, not 24h; the long window is deliberate, since
# the sweep is unconditional and a shorter one is likelier to lift the gate on a
# session that is still alive. Cleanup latency does not matter here.
find "$state_dir" -maxdepth 1 -name 'claude-pm-check-*' -type f -mtime +1 \
  -exec rm -f {} + 2>/dev/null || true

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

done_flag="$state_dir/claude-pm-check-$session_id.done"

# Publish the completion-flag path to the session. `CLAUDE_ENV_FILE` is a
# SessionStart-only facility: exports appended here are picked up by every
# subsequent Bash tool call, so the skill can run `touch "$CLAUDE_PM_CHECK_DONE"`
# instead of reconstructing a session id it has no way to see. Written before
# the source check below so resumed, forked, and compacted sessions get it too.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  quoted=$(printf '%s' "$done_flag" | sed "s/'/'\\\\''/g")
  printf "export CLAUDE_PM_CHECK_DONE='%s'\n" "$quoted" \
    >> "$CLAUDE_ENV_FILE" 2>/dev/null || true
fi

case "$(json_str source)" in
  resume | fork | compact) exit 0 ;;
esac

rm -f "$state_dir/claude-pm-check-$session_id.pending" \
      "$state_dir/claude-pm-check-$session_id.done" 2>/dev/null || true

exit 0
