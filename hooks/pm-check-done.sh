#!/usr/bin/env sh
# Records completion of the pre-build PM check — what skills/pm-check/SKILL.md
# step 6 runs. Not a hook: nothing registers it in settings.json, it is invoked
# by the skill.
#
# "Recorded" is not "a file was created". The gate (hooks/pm-check-gate.sh) keys
# off the session id in its OWN payload: it denies while
# `<state>/claude-pm-check-<sid>.pending` exists and the `.done` sibling does
# not. So the flag only counts if it lands next to the `.pending` that is armed.
#
# Two ways to name that path, and they are not equally trustworthy:
#
#   CLAUDE_PM_CHECK_DONE   exported by pm-check-reset.sh from the session id it
#                          was handed on SessionStart. Exact by construction.
#   CLAUDE_CODE_SESSION_ID the fallback, for sessions where that hook never ran
#                          (hooks installed mid-session). Documented to report
#                          the INITIAL startup id on `--continue`/`--resume`
#                          without an explicit id:
#                          https://code.claude.com/docs/en/env-vars
#
# The fallback is why this script exists rather than a bare `touch`. A
# startup-id path lifts nothing, and the failure was silent in exactly the worst
# place: the skill reported success, the next Write was denied anyway, and the
# only way out was the opt-out. So on the fallback branch the flag is verified
# against the gate's own `.pending` and a mismatch is reported loudly.
#
# The check is scoped to that branch deliberately. When CLAUDE_PM_CHECK_DONE is
# set the path cannot be wrong, and a session that ran the check proactively has
# no `.pending` at all — cross-checking there would cry wolf on the common case.
#
# Optional argument: the exact `.done` path, for the recovery case. Both the
# detector's injected context and the gate's deny message carry it literally.
#
# Pure POSIX sh — no jq, no node.

set -u

state_dir="${TMPDIR:-/tmp}"
verify=no

if [ "$#" -gt 0 ] && [ -n "$1" ]; then
  done_flag="$1"
elif [ -n "${CLAUDE_PM_CHECK_DONE:-}" ]; then
  done_flag="$CLAUDE_PM_CHECK_DONE"
elif [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  done_flag="$state_dir/claude-pm-check-$CLAUDE_CODE_SESSION_ID.done"
  verify=yes
else
  echo "pm-check: cannot tell which session to record." >&2
  echo "Neither CLAUDE_PM_CHECK_DONE nor CLAUDE_CODE_SESSION_ID is set. Re-run" >&2
  echo "with the exact .done path from the pm-check context or the blocked-write" >&2
  echo "message: $0 <path>" >&2
  exit 1
fi

if ! touch "$done_flag" 2>/dev/null; then
  echo "pm-check: could not write $done_flag" >&2
  exit 1
fi

if [ "$verify" = no ]; then
  echo "pm-check recorded: $done_flag"
  exit 0
fi

# Fallback branch. The armed `.pending` is the gate's key, so its presence next
# to what we just wrote is proof the two agree.
if [ -f "${done_flag%.done}.pending" ]; then
  echo "pm-check recorded: $done_flag"
  exit 0
fi

armed=$(find "$state_dir" -maxdepth 1 -name 'claude-pm-check-*.pending' -type f \
  2>/dev/null)

if [ -z "$armed" ]; then
  echo "pm-check recorded: $done_flag (no session is gated)."
  exit 0
fi

echo "pm-check NOT recorded for the gated session." >&2
echo "Wrote:  $done_flag" >&2
echo "Gate is armed under:" >&2
printf '%s\n' "$armed" | sed 's/^/  /' >&2
echo "CLAUDE_CODE_SESSION_ID can report the startup id on --continue/--resume," >&2
echo "so the flag went somewhere the gate never reads. Re-run with the exact" >&2
echo ".done path from the pm-check context or the blocked-write message — both" >&2
echo "carry it literally: $0 <path>" >&2
echo "(If this session was never gated and one of the above belongs to another" >&2
echo "session, nothing needed recording and this is not a problem.)" >&2
exit 1
