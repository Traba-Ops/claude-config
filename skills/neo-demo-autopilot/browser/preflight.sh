#!/usr/bin/env bash
# Autopilot browser preflight for unattended playwright-cdp verification.
# Verifies: (1) dev server up on :4203, (2) driver deps provisioned (installs
# them if not), (3) bot Chrome up on :9222, (4) the bot profile is past the
# /login wall. Prints one of: READY / NEEDS_SERVER / NEEDS_DEPS / NEEDS_LOGIN /
# ERROR and exits 0 / 10 / 12 / 11 / 1 respectively.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! lsof -ti :4203 >/dev/null 2>&1; then
  echo "NEEDS_SERVER — dev server not up on :4203 (run: pnpm start-dev-neo)"
  exit 10
fi

# Provision the CDP driver deps (idempotent: no-op once installed).
setup_out="$(bash "$HERE/setup.sh")"; setup_code=$?
if [ "$setup_code" -ne 0 ]; then echo "$setup_out"; exit "$setup_code"; fi

bash "$HERE/launch-bot-chrome.sh" >/dev/null 2>&1 || { echo "ERROR — could not launch bot Chrome"; exit 1; }
sleep 2

node "$HERE/login-health.js"
code=$?
case $code in
  0) echo "READY — bot profile logged in; playwright-cdp verification can run unattended"; exit 0 ;;
  3) echo "NEEDS_LOGIN — bot Chrome up but at /login; log into neo-platform once in the :9222 window"; exit 11 ;;
  *) echo "ERROR — login-health probe failed (see above)"; exit 1 ;;
esac
