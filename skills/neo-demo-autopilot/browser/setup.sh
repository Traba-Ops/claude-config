#!/usr/bin/env bash
# One-time, idempotent provisioning for the autopilot playwright-cdp driver.
# Ensures (1) the playwright-cdp-drive sibling skill (which owns the bot-Chrome
# launcher) is installed, and (2) playwright-core is present in the shared bot
# cache (~/.chrome-cdp-profiles/.pw). NO browser download — the driver attaches
# over CDP to the user's existing Chrome, so only the client library is needed.
# A no-op once provisioned. Prints READY / NEEDS_DEPS and exits 0 / 12.
set -uo pipefail

PW_DIR="$HOME/.chrome-cdp-profiles/.pw"
PW_MOD="$PW_DIR/node_modules/playwright-core"
LAUNCHER="$HOME/.claude/skills/playwright-cdp-drive/launch-chrome-cdp.sh"

# 1. Sibling skill that launches the bot Chrome must be installed.
if [ ! -f "$LAUNCHER" ]; then
  echo "NEEDS_DEPS — playwright-cdp-drive skill not found at ~/.claude/skills/playwright-cdp-drive."
  echo "  It ships in the demo-skills zip — unzip ALL folders into ~/.claude/skills, then retry."
  exit 12
fi

# 2. playwright-core (client only) already installed? Then we're done.
if [ -f "$PW_MOD/package.json" ]; then
  echo "READY — deps already provisioned ($PW_DIR)"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "NEEDS_DEPS — npm not found on PATH. Install Node.js 22.22 (see the setup doc), then retry."
  exit 12
fi

echo "Installing playwright-core into $PW_DIR (one-time, ~15s)…"
mkdir -p "$PW_DIR"
( cd "$PW_DIR" && npm i --silent --no-fund --no-audit playwright-core >/dev/null 2>&1 )

if [ -f "$PW_MOD/package.json" ]; then
  echo "READY — provisioned playwright-core in $PW_DIR"
  exit 0
fi
echo "NEEDS_DEPS — failed to install playwright-core into $PW_DIR (check network / npm)."
exit 12
