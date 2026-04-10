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

# Move .git so future updates are just `git pull`
# Replace if already exists (re-install)
rm -rf "$CLAUDE_DIR/.git"
mv "$TEMP_DIR/.git" "$CLAUDE_DIR/.git"

echo ""
echo "Done. Traba skills installed to ~/.claude"
echo ""
echo "Next: open Claude and ask it to set up automatic updates:"
echo '  "Set up a launchd job that runs cd ~/.claude && git pull every hour between 9 AM and 9 PM"'
