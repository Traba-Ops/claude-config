#!/usr/bin/env bash
# Autopilot browser preflight for unattended playwright-cdp verification.
# Verifies: (1) dev server up on :4203, (2) driver deps provisioned (installs
# them if not), (3) bot Chrome up on :9222, (4) the bot profile is past the
# /login wall. Prints one of: READY / NEEDS_SERVER / NEEDS_DEPS / NEEDS_LOGIN /
# ERROR and exits 0 / 10 / 12 / 11 / 1 respectively.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Derive the dev-server port from APP_URL (same var the JS drivers honor), so a
# non-default host/port isn't falsely reported as NEEDS_SERVER.
APP="${APP_URL:-http://localhost:4203}"
_hp="${APP#*://}"; _hp="${_hp%%/*}"          # host[:port]
APP_PORT="${_hp##*:}"
[ "$APP_PORT" = "$_hp" ] && APP_PORT=4203     # no explicit port in APP_URL

if ! lsof -ti ":$APP_PORT" >/dev/null 2>&1; then
  echo "NEEDS_SERVER — dev server not up on :$APP_PORT (run: pnpm start-dev-neo)"
  exit 10
fi

# Provision the CDP driver deps (idempotent: no-op once installed).
setup_out="$(bash "$HERE/setup.sh")"; setup_code=$?
if [ "$setup_code" -ne 0 ]; then echo "$setup_out"; exit "$setup_code"; fi

# Keep the launcher's own message (e.g. ":9222 held by a different profile") so
# unattended preflight can tell fix-the-port from other failures.
launch_out="$(bash "$HERE/launch-bot-chrome.sh" 2>&1)" || { echo "ERROR — could not launch bot Chrome:"; echo "$launch_out"; exit 1; }
sleep 2

node "$HERE/login-health.js"
code=$?
case $code in
  0) echo "READY — bot profile logged in; playwright-cdp verification can run unattended"; exit 0 ;;
  3) echo "NEEDS_LOGIN — bot Chrome up but at /login; log into neo-platform once in the :9222 window"; exit 11 ;;
  *) echo "ERROR — login-health probe failed (see above)"; exit 1 ;;
esac
