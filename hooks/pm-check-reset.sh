#!/usr/bin/env sh
# SessionStart hook: clear this session's PM-check marks, and sweep marks left
# behind by sessions that have since ended.
#
# Without the sweep, /tmp accumulates one or two empty files per build-shaped
# session forever. Without the per-session clear, a `--fork` that inherits a
# session id would start already-cleared or already-gated depending on timing.
#
# On `resume`, the marks are deliberately KEPT: resuming a session that was
# mid-build should not silently drop the gate, and UserPromptSubmit does not
# re-fire on resume to re-apply it.
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

# Sweep marks older than a day regardless of source — cheap, and it is the only
# thing that ever cleans up after a crashed session.
find "$state_dir" -maxdepth 1 -name 'claude-pm-check-*' -type f -mtime +1 \
  -exec rm -f {} + 2>/dev/null || true

source_kind=$(json_str source)
case "$source_kind" in
  resume | fork) exit 0 ;;
esac

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

rm -f "$state_dir/claude-pm-check-$session_id.pending" \
      "$state_dir/claude-pm-check-$session_id.done" 2>/dev/null || true

exit 0
