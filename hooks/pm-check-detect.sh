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


payload=$(cat 2>/dev/null) || exit 0

# Extract a JSON string field without jq. The leading `.*` is greedy, so this
# anchors on the LAST occurrence of the field, not the first — fine for
# `session_id`, which is opaque and appears once.
#
# The read is capped at 8KB. This hook runs before every prompt against a 5s
# timeout, and an unbounded `tr`+`sed` over a pasted 8MB prompt costs ~3.3s.
# `session_id` sits in the first few hundred bytes of the payload.
json_str() {
  printf '%s' "$payload" |
    head -c 8192 |
    tr -d '\n' |
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -1
}

session_id=$(json_str session_id)
[ -n "$session_id" ] || exit 0

# `prompt` is the documented UserPromptSubmit field carrying the submitted text.
# It is read differently from `session_id`: strip everything up to the opening
# quote and keep the rest, rather than requiring a closing quote. Requiring one
# silently skips the check on two ordinary inputs — a quoted phrase, where
# `build a "shift fill" dashboard` arrives escaped and matches only as
# `build a \`, losing the noun; and any prompt long enough to be cut by the byte
# cap. Trailing JSON after the prompt is harmless: this text is only
# keyword-matched, never executed, echoed, or written anywhere.
#
# Everything that is not a letter or digit then collapses to a space. That is
# what makes the word-distance matching below survive real prompts: JSON escapes
# (`build a \"shift fill\" dashboard`), punctuation, and hyphens would otherwise
# sit between the determiner and its noun and break the match.
prompt=$(printf '%s' "$payload" |
  head -c 65536 |
  tr -d '\n' |
  sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"//p' |
  tr '[:upper:]' '[:lower:]' |
  tr -c 'a-z0-9' ' ')
[ -n "$prompt" ] || exit 0

# Build-shaped = an intent verb, then an INDEFINITE artifact phrase after it.
#
# The indefinite determiner is what carries the meaning. "build me A dashboard"
# introduces something that does not exist; "make sure THE pipeline job passes"
# and "add logging to THE job" act on something that does. Matching a bare verb
# and a bare noun anywhere in the prompt cannot tell those apart, and gated the
# edit and bug-fix requests this check explicitly excludes.
#
# Verbs are stems with an optional suffix so gerunds count. `\bbuild\b` misses
# "building an internal tool" and "creating a dashboard" — plausibly the most
# common way a build request is phrased. The leading \b still keeps "rebuild",
# "readd", and "unmake" out, and the trailing \b keeps "creature" out of
# "creat".
verb='(\b(build|creat|implement|mak|writ|scaffold|add)(e|es|ed|ing|s)?\b|\b(spin|set|stand)[a-z]* up\b|\bsetup\b)'
artifact='\b(a|an|another|some|new|your own)\b( +[a-z0-9]+){0,2} +\b(app|tool|dashboard|workflow|agent|bot|script|endpoint|page|report|integration|service|automation|pipeline|job|cron)s?\b'

# `.*` between them: the artifact has to follow the verb, not merely co-occur.
echo "$prompt" | grep -qE "$verb.*$artifact" || exit 0

pending="$state_dir/claude-pm-check-$session_id.pending"
done_flag="$state_dir/claude-pm-check-$session_id.done"

# Already checked this session — don't nag again.
[ -f "$done_flag" ] && exit 0

: > "$pending" 2>/dev/null || exit 0


printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
  "This looks like a request to build something. Before writing any code, invoke the pm-check skill — it runs Traba pre-build checks (does this already exist, should it be a Neutron capability instead, which data path, does the output land back in the system, who owns it) via Neutron. Write, Edit, MultiEdit, and NotebookEdit are BLOCKED until it has run. There is no way to skip it: run the check."

exit 0
