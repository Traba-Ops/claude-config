#!/bin/bash
set -e

REPO="https://github.com/Traba-Ops/claude-config.git"
TEMP_DIR="$HOME/traba-claude-config"
CLAUDE_DIR="$HOME/.claude"

# Clean up temp dir on exit (success or failure)
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

echo "Installing Traba skills..."

# Ensure git is installed
if ! command -v git &> /dev/null; then
  echo "Git not found. Installing via Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null
  echo "Please re-run this script after the installation finishes."
  exit 1
fi

# Ensure git identity is configured (needed for checkpoints)
if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
  echo "Git identity not configured. Run these first:"
  echo ""
  echo "  git config --global user.name 'Your Name'"
  echo "  git config --global user.email 'your.email@traba.work'"
  echo ""
  echo "Then re-run this script."
  exit 1
fi

# Clean up any interrupted previous install
rm -rf "$TEMP_DIR"

# Clone the repo
if ! git clone --quiet "$REPO" "$TEMP_DIR"; then
  echo "Failed to clone $REPO — check your network connection." >&2
  exit 1
fi

# Copy all directories into ~/.claude
for src_dir in "$TEMP_DIR"/*/; do
  dir_name=$(basename "$src_dir")
  mkdir -p "$CLAUDE_DIR/$dir_name"

  for item in "$src_dir"*; do
    item_name=$(basename "$item")
    if [ -e "$CLAUDE_DIR/$dir_name/$item_name" ]; then
      echo "  Updating: $dir_name/$item_name"
    else
      echo "  Installing: $dir_name/$item_name"
    fi
    cp -r "$item" "$CLAUDE_DIR/$dir_name/"
  done
done

# Verify installation
if [ ! -f "$CLAUDE_DIR/skills/project-setup/SKILL.md" ]; then
  echo "Installation may be incomplete — expected files not found" >&2
  exit 1
fi

# Caveman output mode: default to the lite intensity and register the SessionStart
# hook that loads it. Both steps are idempotent — an existing choice is left alone.
chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true

if [ ! -f "$CLAUDE_DIR/.caveman-always" ]; then
  echo "lite" > "$CLAUDE_DIR/.caveman-always"
  echo "  Enabling: caveman output mode (lite)"
fi

if command -v python3 &> /dev/null; then
  CLAUDE_DIR="$CLAUDE_DIR" python3 - <<'PY'
import json, os, pathlib

claude_dir = os.environ["CLAUDE_DIR"]
settings = pathlib.Path(claude_dir) / "settings.json"
command = f"{claude_dir}/hooks/caveman-always-on.sh"

try:
    data = json.loads(settings.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

session_start = data.setdefault("hooks", {}).setdefault("SessionStart", [])
already = any(
    "caveman-always-on.sh" in hook.get("command", "")
    for entry in session_start
    for hook in entry.get("hooks", [])
)

if not already:
    session_start.append({
        "matcher": "startup|resume|clear|compact",
        "hooks": [{
            "type": "command",
            "command": command,
            "timeout": 5,
            "statusMessage": "Checking caveman always-on flag...",
        }],
    })
    settings.write_text(json.dumps(data, indent=2) + "\n")
    print("  Registering: caveman SessionStart hook")
PY
else
  echo "  Skipped: caveman hook registration (python3 not found)"
fi

# Move .git so future updates are just `git pull`
# Replace if already exists (re-install)
rm -rf "$CLAUDE_DIR/.git"
mv "$TEMP_DIR/.git" "$CLAUDE_DIR/.git"

echo ""
echo "Done. Traba skills installed to ~/.claude"
echo ""
echo "Next: open Claude and ask it to set up automatic updates:"
echo '  "Set up a launchd job that runs cd ~/.claude && git pull every hour between 9 AM and 9 PM"'
