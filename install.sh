#!/bin/bash
set -e

REPO="https://github.com/Traba-Ops/claude-config.git"
TEMP_DIR="$HOME/traba-claude-config"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

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
# hook that loads it. The settings.json pass below also sets auto as the default
# permission mode. Every step is idempotent — an existing choice is left alone.
chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true

if [ ! -f "$CLAUDE_DIR/.caveman-always" ]; then
  echo "lite" > "$CLAUDE_DIR/.caveman-always"
  echo "  Enabling: caveman output mode (lite)"
fi

if command -v python3 &> /dev/null; then
  # `|| true` so a failure in here can never abort the installer under `set -e`
  # — the .git move that wires up hourly updates still has to run.
  CLAUDE_DIR="$CLAUDE_DIR" python3 - <<'PY' || true
import json, os, pathlib, shutil, tempfile

claude_dir = os.environ["CLAUDE_DIR"]
settings = pathlib.Path(claude_dir) / "settings.json"
command = f"{claude_dir}/hooks/caveman-always-on.sh"


class Skip(Exception):
    """Configuration cannot proceed; explain and leave settings.json alone."""


def register_caveman_hook(data):
    """Add the caveman SessionStart hook. True if `data` was changed."""
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        raise Skip(f'"hooks" in {settings} is not an object')

    session_start = hooks.get("SessionStart", [])
    if not isinstance(session_start, list):
        raise Skip(f'"hooks.SessionStart" in {settings} is not a list')

    for entry in session_start:
        if not isinstance(entry, dict):
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            continue
        for hook in entry_hooks:
            if not isinstance(hook, dict):
                continue
            if "caveman-always-on.sh" in str(hook.get("command", "")):
                return False  # already registered

    session_start = list(session_start) + [{
        "matcher": "startup|resume|clear|compact",
        "hooks": [{
            "type": "command",
            "command": command,
            "timeout": 5,
            "statusMessage": "Checking caveman always-on flag...",
        }],
    }]
    hooks = dict(hooks)
    hooks["SessionStart"] = session_start
    data["hooks"] = hooks
    return True


def set_auto_permission_mode(data):
    """Default new sessions to auto mode. True if `data` was changed.

    Auto mode is what makes Claude act on a request instead of stopping for
    permission at every step — the fleet default the onboarding runbook sets up.
    An operator who has already chosen a mode keeps it.
    """
    permissions = data.get("permissions", {})
    if not isinstance(permissions, dict):
        raise Skip(f'"permissions" in {settings} is not an object')

    if "defaultMode" in permissions:
        return False  # operator already chose — never override

    permissions = dict(permissions)
    permissions["defaultMode"] = "auto"
    data["permissions"] = permissions
    return True


def configure():
    # Read. A missing file is fine (we create one); anything unreadable or
    # unparseable is not — we never overwrite a settings.json we can't parse.
    try:
        raw = settings.read_text()
    except FileNotFoundError:
        raw = None
    except OSError as exc:
        raise Skip(f"{settings} could not be read ({exc.strerror})")

    if raw is None:
        data = {}
    else:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise Skip(
                f"{settings} is not valid JSON "
                f"(line {exc.lineno}, column {exc.colno})"
            )
        if not isinstance(data, dict):
            raise Skip(f"{settings} is not a JSON object")

    changes = []
    if register_caveman_hook(data):
        changes.append("  Registering: caveman SessionStart hook")
    if set_auto_permission_mode(data):
        changes.append("  Setting: auto as the default permission mode")

    if not changes:
        return  # everything already in place — idempotent, nothing to write

    # Back up the previous file, then write atomically via a temp file in the
    # same directory so an interrupt can't leave a half-written settings.json.
    mode = 0o644
    if raw is not None:
        try:
            mode = settings.stat().st_mode & 0o777
            shutil.copy2(settings, settings.parent / (settings.name + ".bak"))
        except OSError as exc:
            raise Skip(f"{settings} could not be backed up ({exc.strerror})")

    settings.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(settings.parent), prefix=".settings.json.")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(json.dumps(data, indent=2) + "\n")
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, settings)
    except OSError as exc:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise Skip(f"{settings} could not be written ({exc.strerror})")

    for line in changes:
        print(line)


try:
    configure()
except Skip as exc:
    print("  WARNING: the caveman SessionStart hook and auto mode could not be")
    print(f"           set up: {exc}.")
    print("           Nothing was changed. Fix that file and re-run this installer,")
    print('           or say "/caveman" for caveman and Shift+Tab for auto mode.')
except Exception as exc:  # never let this step break the install
    print(f"  WARNING: settings.json setup failed ({exc}).")
    print("           Nothing was changed. The skills are installed; say \"/caveman\"")
    print("           for caveman and cycle to auto mode with Shift+Tab.")
PY
else
  echo "  Skipped: caveman hook + auto mode setup (python3 not found)"
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
