#!/usr/bin/env bash
# Idempotently ensure the persistent CDP bot Chrome is up on :9222 with the
# dedicated `neo-catalog` profile (survives restarts; holds the Firebase session
# after a one-time login). Reuses the playwright-cdp-drive launcher, which handles
# the Chrome 136+ non-default-user-data-dir gotcha.
set -euo pipefail
PROFILE="${1:-neo-catalog}"
URL="${2:-http://localhost:4203}"
PROFILE_DIR="$HOME/.chrome-cdp-profiles/$PROFILE"

# Resolve the playwright-cdp-drive launcher. The sibling skill is always beside
# this one, so resolve relative to THIS script first (cwd-independent — preflight
# may invoke us from browser/); fall back to the documented skill roots.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER=""
for cand in \
  "$SCRIPT_DIR/../../playwright-cdp-drive/launch-chrome-cdp.sh" \
  "$HOME/.claude/skills/playwright-cdp-drive/launch-chrome-cdp.sh" \
  "$HOME/.config/claude/skills/playwright-cdp-drive/launch-chrome-cdp.sh" \
  "$PWD/.claude/skills/playwright-cdp-drive/launch-chrome-cdp.sh"; do
  if [ -f "$cand" ]; then LAUNCHER="$cand"; break; fi
done

if curl -sf http://localhost:9222/json/version >/dev/null 2>&1; then
  # Reuse :9222 ONLY if it's THIS profile — a different bot Chrome on the same
  # port would silently drive the wrong session.
  if pgrep -f -- "--user-data-dir=$PROFILE_DIR" >/dev/null 2>&1; then
    echo "bot Chrome already up on :9222 (profile: $PROFILE)"
    exit 0
  fi
  echo "ERR: :9222 is in use by a DIFFERENT Chrome (not profile $PROFILE) — free the port or point CDP elsewhere." >&2
  exit 1
fi
if [ -z "$LAUNCHER" ]; then
  echo "ERR: playwright-cdp-drive launcher not found in ~/.claude, ~/.config/claude, or ./.claude skills." >&2
  exit 1
fi
bash "$LAUNCHER" "$PROFILE" "$URL"
