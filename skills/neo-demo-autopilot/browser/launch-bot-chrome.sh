#!/usr/bin/env bash
# Idempotently ensure the persistent CDP bot Chrome is up on :9222 with the
# dedicated `neo-catalog` profile (survives restarts; holds the Firebase session
# after a one-time login). Reuses the playwright-cdp-drive launcher, which handles
# the Chrome 136+ non-default-user-data-dir gotcha.
set -euo pipefail
PROFILE="${1:-neo-catalog}"
URL="${2:-http://localhost:4203}"
LAUNCHER="$HOME/.claude/skills/playwright-cdp-drive/launch-chrome-cdp.sh"

if curl -sf http://localhost:9222/json/version >/dev/null 2>&1; then
  echo "bot Chrome already up on :9222"
  exit 0
fi
if [ ! -f "$LAUNCHER" ]; then
  echo "ERR: playwright-cdp-drive launcher not found at $LAUNCHER" >&2
  exit 1
fi
bash "$LAUNCHER" "$PROFILE" "$URL"
