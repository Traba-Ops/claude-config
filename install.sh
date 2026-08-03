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

# Remove bundle files this version no longer ships. The previous install's git
# index lists exactly what the bundle put in ~/.claude, so anything tracked there
# and absent from the fresh clone is retired. An operator's own files are never
# tracked, so they are never touched. Without this, a retired hook script would
# survive re-install and keep firing (or, once the hourly `git pull` deletes it,
# leave its settings.json registration pointing at nothing).
if [ -d "$CLAUDE_DIR/.git" ]; then
  for tracked in $(git -C "$CLAUDE_DIR" ls-files 2>/dev/null); do
    if [ ! -e "$TEMP_DIR/$tracked" ] && [ -e "$CLAUDE_DIR/$tracked" ]; then
      rm -f "$CLAUDE_DIR/$tracked"
      echo "  Removing: $tracked (no longer part of the bundle)"
    fi
  done
  # Clean up any directory the removals left empty. rmdir skips non-empty ones.
  rmdir "$CLAUDE_DIR"/*/*/ "$CLAUDE_DIR"/*/ 2>/dev/null || true
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

# ADHD output mode: opt everyone in and register the SessionStart hook that loads
# it. The settings.json pass below also sets auto as the default permission mode.
# Every step is idempotent — an existing choice is left alone.
chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true

if [ ! -f "$CLAUDE_DIR/.i-have-adhd-always" ]; then
  : > "$CLAUDE_DIR/.i-have-adhd-always"
  echo "  Enabling: ADHD output mode"
fi

if command -v python3 &> /dev/null; then
  # `|| true` so a failure in here can never abort the installer under `set -e`
  # — the .git move that wires up hourly updates still has to run.
  CLAUDE_DIR="$CLAUDE_DIR" python3 - <<'PY' || true
import json, os, pathlib, shutil, tempfile

claude_dir = os.environ["CLAUDE_DIR"]
settings = pathlib.Path(claude_dir) / "settings.json"
hooks_dir = f"{claude_dir}/hooks/"
command = f"{hooks_dir}adhd-always-on.sh"


class Skip(Exception):
    """Configuration cannot proceed; explain and leave settings.json alone."""


def session_start_hooks(data):
    """The SessionStart entries in `data`, validated."""
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        raise Skip(f'"hooks" in {settings} is not an object')

    session_start = hooks.get("SessionStart", [])
    if not isinstance(session_start, list):
        raise Skip(f'"hooks.SessionStart" in {settings} is not a list')

    return session_start


def set_session_start_hooks(data, session_start):
    hooks = dict(data.get("hooks", {}))
    hooks["SessionStart"] = session_start
    data["hooks"] = hooks


def register_adhd_hook(data):
    """Add the ADHD SessionStart hook. True if `data` was changed."""
    session_start = session_start_hooks(data)

    for entry in session_start:
        if not isinstance(entry, dict):
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            continue
        for hook in entry_hooks:
            if not isinstance(hook, dict):
                continue
            if "adhd-always-on.sh" in str(hook.get("command", "")):
                return False  # already registered

    session_start = list(session_start) + [{
        "matcher": "startup|resume|clear|compact",
        "hooks": [{
            "type": "command",
            "command": command,
            "timeout": 5,
            "statusMessage": "Checking ADHD always-on flag...",
        }],
    }]
    set_session_start_hooks(data, session_start)
    return True


def prune_missing_bundle_hooks(data):
    """Drop SessionStart hooks pointing at a bundle script that no longer exists.

    A retired hook script disappears from ~/.claude on the next `git pull`, but
    its registration in settings.json doesn't — leaving every session start to
    fail on a missing command. Only scripts under the bundle's own hooks
    directory are considered, and only when the file is actually gone, so an
    operator's own hooks are never touched. True if `data` was changed.
    """
    session_start = session_start_hooks(data)
    changed = False
    kept_entries = []

    for entry in session_start:
        if not isinstance(entry, dict):
            kept_entries.append(entry)
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            kept_entries.append(entry)
            continue

        kept_hooks = []
        for hook in entry_hooks:
            script = ""
            if isinstance(hook, dict):
                script = str(hook.get("command", "")).strip().strip('"')
            if (
                script.startswith(hooks_dir)
                and script != command
                and not os.path.exists(script)
            ):
                changed = True
                continue
            kept_hooks.append(hook)

        if not kept_hooks:
            changed = True
            continue
        entry = dict(entry)
        entry["hooks"] = kept_hooks
        kept_entries.append(entry)

    if changed:
        set_session_start_hooks(data, kept_entries)
    return changed


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
    if prune_missing_bundle_hooks(data):
        changes.append("  Cleaning up: SessionStart hooks for retired bundle scripts")
    if register_adhd_hook(data):
        changes.append("  Registering: ADHD SessionStart hook")
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
    print("  WARNING: the ADHD SessionStart hook and auto mode could not be")
    print(f"           set up: {exc}.")
    print("           Nothing was changed. Fix that file and re-run this installer,")
    print('           or say "/i-have-adhd" for ADHD mode and Shift+Tab for auto mode.')
except Exception as exc:  # never let this step break the install
    print(f"  WARNING: settings.json setup failed ({exc}).")
    print('           Nothing was changed. The skills are installed; say "/i-have-adhd"')
    print("           for ADHD mode and cycle to auto mode with Shift+Tab.")
PY
else
  echo "  Skipped: ADHD hook + auto mode setup (python3 not found)"
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
