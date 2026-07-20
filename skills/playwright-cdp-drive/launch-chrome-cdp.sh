#!/usr/bin/env bash
# Launch the user's REAL Chrome with a CDP debug port on a dedicated bot profile.
# Runs alongside the normal Chrome (separate --user-data-dir => no conflict).
# Usage: bash launch-chrome-cdp.sh <profile-name> [start-url] [port]
set -euo pipefail

PROFILE="${1:?usage: launch-chrome-cdp.sh <profile-name> [start-url] [port]}"
URL="${2:-about:blank}"
PORT="${3:-9222}"
DIR="$HOME/.chrome-cdp-profiles/$PROFILE"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -x "$CHROME" ] || { echo "Chrome not found at: $CHROME" >&2; exit 1; }
mkdir -p "$DIR"

# If something already listens on the port, reuse it.
if curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
  echo "CDP already up on :$PORT — reusing it."
  curl -s "http://localhost:$PORT/json/version" | sed 's/,/\n/g' | grep -i browser || true
  exit 0
fi

"$CHROME" \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$DIR" \
  --no-first-run --no-default-browser-check \
  "$URL" >/dev/null 2>&1 &

# wait for the port
for i in $(seq 1 20); do
  if curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
    echo "CDP up on :$PORT (profile: $DIR)"
    curl -s "http://localhost:$PORT/json/version" | sed 's/,/\n/g' | grep -i browser || true
    echo ">> Log into the target site(s) in the new Chrome window (once). Then connectOverCDP."
    exit 0
  fi
  sleep 0.5
done
echo "CDP did not come up on :$PORT (Chrome 136+ ignores the flag on the DEFAULT profile — this uses a dedicated dir, so check Chrome launched)." >&2
exit 1
