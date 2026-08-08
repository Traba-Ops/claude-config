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

# Remove bundle files this version no longer ships. Two sources, both listing
# only bundle-owned paths — an operator's own files appear in neither, so they
# are never touched:
#
#   1. Paths retired by a recent version, listed here. The list is what makes
#      the cleanup work when ~/.claude has no .git (hand-copied install), a
#      stale index (hooks/ symlinked elsewhere), or a `git pull` that local
#      changes have been blocking.
#   2. The previous install's git index, which lists exactly what the bundle put
#      in ~/.claude. Anything tracked there and absent from the fresh clone is
#      retired — this catches removals nobody remembered to list.
#
# Without this, a retired hook script would survive re-install and keep firing
# (or, once the hourly `git pull` deletes it, leave its settings.json
# registration pointing at nothing). Drop entries from the list once every
# install has been through a version that removed them.
retired_paths="hooks/caveman-always-on.sh
skills/caveman/SKILL.md
skills/caveman-help/SKILL.md"

if [ -d "$CLAUDE_DIR/.git" ]; then
  retired_paths="$retired_paths
$(git -C "$CLAUDE_DIR" ls-files 2>/dev/null)"
fi

# Split on newline only, and no globbing — these are paths, not patterns.
removed_dirs=""
set -f
IFS='
'
for tracked in $retired_paths; do
  if [ -n "$tracked" ] && [ -e "$CLAUDE_DIR/$tracked" ] && [ ! -e "$TEMP_DIR/$tracked" ]; then
    rm -f "$CLAUDE_DIR/$tracked"
    echo "  Removing: $tracked (no longer part of the bundle)"
    removed_dirs="$removed_dirs$(dirname "$CLAUDE_DIR/$tracked")
"
  fi
done
unset IFS
set +f

# Clean up directories the loop above emptied — and only those. rmdir refuses any
# that still have contents; deepest first so a parent is tried after its child.
# The `|| true` matters: a refused rmdir is the normal case, and under `set -e` it
# would otherwise abort the install before anything below here runs.
if [ -n "$removed_dirs" ]; then
  printf '%s' "$removed_dirs" | sort -u -r | while IFS= read -r dir; do
    [ -z "$dir" ] || rmdir "$dir" 2>/dev/null || true
  done
fi

# The old caveman opt-in flag is untracked, so nothing above cleans it up.
rm -f "$CLAUDE_DIR/.caveman-always"

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
import json, os, pathlib, shlex, shutil, tempfile

claude_dir = os.environ["CLAUDE_DIR"]
# Resolve symlinks before anything reads, backs up, or writes this path.
# `os.replace` swaps the path it is handed, so on a settings.json symlinked into
# a dotfiles checkout — stow, chezmoi, or by hand, and a pattern this bundle
# already expects for hooks/ (see the note above about it being symlinked
# elsewhere) — the write would replace the LINK with a regular file. The
# operator's real file is silently orphaned, their dotfiles repo stops affecting
# their config, and the .bak lands in the wrong directory so it does not point
# back either. Resolving first makes the write, the backup, and the temp file all
# land next to the real file. realpath on a not-yet-existing path is a no-op, so
# a fresh install is unaffected.
settings = pathlib.Path(os.path.realpath(pathlib.Path(claude_dir) / "settings.json"))
# rstrip so a CLAUDE_CONFIG_DIR with a trailing slash still yields the same
# prefix that registrations were written with (no `//hooks/`).
hooks_dir = claude_dir.rstrip("/") + "/hooks/"
command = f"{hooks_dir}adhd-always-on.sh"
pm_detect_command = f"{hooks_dir}pm-check-detect.sh"
pm_gate_command = f"{hooks_dir}pm-check-gate.sh"
pm_reset_command = f"{hooks_dir}pm-check-reset.sh"

# Every script this bundle registers. The prune below deletes registrations whose
# script is gone from hooks/ — so a command missing from this set that is
# temporarily absent from disk would be pruned and then re-added on the next
# install, churning settings.json. Keep it in sync with what gets registered.
bundle_commands = {
    command,
    pm_detect_command,
    pm_gate_command,
    pm_reset_command,
}

# The hook events this bundle manages. Prune only ever looks at these.
managed_events = ("SessionStart", "UserPromptSubmit", "PreToolUse")


class Skip(Exception):
    """Configuration cannot proceed; explain and leave settings.json alone."""


def hook_script_path(hook):
    """The script a hook entry runs — argv[0], unquoted. "" if there isn't one.

    A command is not a path: a registration may carry arguments
    (`~/.claude/hooks/my-standup.sh --quiet`), quote a path with spaces, or name
    an interpreter (`sh ~/.claude/hooks/foo.sh`). Testing the whole string would
    classify an operator's own working hook as retired and delete it.
    """
    if not isinstance(hook, dict):
        return ""
    raw = str(hook.get("command", "")).strip()
    if not raw:
        return ""
    try:
        argv = shlex.split(raw)
    except ValueError:  # unbalanced quotes — fall back to whitespace splitting
        argv = raw.split()
    if not argv:
        return ""
    if len(argv) > 1 and os.path.basename(argv[0]) in ("sh", "bash"):
        argv = argv[1:]
    return argv[0]


def warn(warnings, message):
    """Record a warning once. Several steps read the same event, and an operator
    does not need to be told three times that one key has the wrong shape."""
    line = f"  WARNING: {message}"
    if line not in warnings:
        warnings.append(line)


def event_hooks(data, event, warnings):
    """The entries for one hook event in `data`, or None if unusable.

    Returning None rather than raising is deliberate: a weird shape under one
    event must not abort the whole pass. Every settings mutation here degrades
    independently — the operator with an odd `hooks.PreToolUse` still gets the
    ADHD hook, the prune on the other events, and auto mode.
    """
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        warn(warnings, f'"hooks" in {settings} is not an object, so hook '
                       "registration and cleanup were skipped.")
        return None

    entries = hooks.get(event, [])
    if not isinstance(entries, list):
        warn(warnings, f'"hooks.{event}" in {settings} is not a list, so hooks '
                       f"for {event} were left alone.")
        return None

    return entries


def set_event_hooks(data, event, entries):
    hooks = dict(data.get("hooks", {}))
    hooks[event] = entries
    data["hooks"] = hooks


def already_registered(entries, script):
    """True if some entry in `entries` runs exactly `script`.

    Compared against argv[0], not by substring. A substring test matches things
    that are not this registration at all — an operator's own
    `hooks/other/my-pm-check-gate.sh`, a `logger --tag pm-check-detect.sh`, or the
    `~/.claude/...` spelling of a hook while the installer is writing
    `/opt/claude/...` paths. Any of those made the installer believe a hook was
    present, skip it forever, and still report success: a permanently unregistered
    write gate that never self-heals.
    """
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            continue
        for hook in entry_hooks:
            if hook_script_path(hook) == script:
                return True
    return False


def register_hook(data, event, script, entry, warnings):
    """Add one hook registration unless it is already there, or the event's
    shape is unusable. True if `data` was changed."""
    entries = event_hooks(data, event, warnings)
    if entries is None or already_registered(entries, script):
        return False
    set_event_hooks(data, event, list(entries) + [entry])
    return True


def register_adhd_hook(data, warnings):
    """Add the ADHD SessionStart hook. True if `data` was changed."""
    return register_hook(data, "SessionStart", command, {
        "matcher": "startup|resume|clear|compact",
        "hooks": [{
            "type": "command",
            "command": command,
            "timeout": 5,
            "statusMessage": "Checking ADHD always-on flag...",
        }],
    }, warnings)


def register_pm_check_hooks(data, warnings):
    """Wire the pre-build PM check: detect build-shaped prompts, gate writes
    until the check has run, and clear the marks on a fresh session.

    Three separate registrations because they are three different events. Each
    is added independently, so a partially-registered settings.json converges
    instead of being skipped wholesale.

    Returns the names of the hooks it registered, so the installer reports what
    actually landed. Saying "pre-build PM check hooks" when one of three was
    written is how a half-wired gate goes unnoticed.
    """
    # `UserPromptSubmit` takes no matcher — it always fires.
    added = []
    if register_hook(data, "UserPromptSubmit", pm_detect_command, {
        "hooks": [{
            "type": "command",
            "command": pm_detect_command,
            "timeout": 5,
            "statusMessage": "Checking for a build request...",
        }],
    }, warnings):
        added.append("detect")

    # A matcher of plain names is an exact-string list, not a regex, so `Edit`
    # does not incidentally cover `NotebookEdit` — it has to be named.
    if register_hook(data, "PreToolUse", pm_gate_command, {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [{
            "type": "command",
            "command": pm_gate_command,
            "timeout": 5,
            "statusMessage": "Checking the pre-build gate...",
        }],
    }, warnings):
        added.append("gate")

    if register_hook(data, "SessionStart", pm_reset_command, {
        "matcher": "startup|resume|clear|compact",
        "hooks": [{
            "type": "command",
            "command": pm_reset_command,
            "timeout": 5,
            "statusMessage": "Clearing pre-build marks...",
        }],
    }, warnings):
        added.append("reset")

    return added


def definitely_absent(path):
    """True only when `path` is provably not there.

    `os.path.exists` is the wrong test for a prune. It follows symlinks and it
    answers False for anything it cannot stat, so a hook symlinked into a
    dotfiles checkout, sitting on an unmounted drive, or under a directory the
    installer cannot traverse looks identical to a deleted one — and pruning it
    silently deregisters an operator's working hook across three events. `lstat`
    tests the link itself, and every error other than "no such file" is read as
    "keep it".
    """
    try:
        os.lstat(path)
    except FileNotFoundError:
        return True
    except OSError:
        return False  # unreadable parent, dead mount, anything else — assume live
    return False


def prune_missing_bundle_hooks(data, warnings):
    """Drop hooks pointing at a bundle script that no longer exists, across every
    event this bundle manages. True if `data` was changed.

    A retired hook script disappears from ~/.claude on the next `git pull`, but
    its registration in settings.json doesn't — leaving every session start to
    fail on a missing command. Only the script a hook runs is tested, only when
    it sits under the bundle's own hooks directory, and only when that file is
    provably gone — so an operator's own hooks are never touched, arguments and
    all.

    Returns the command strings it removed, so the installer can name them. The
    single `.bak` is overwritten by the next run that changes anything, so an
    operator who does not notice a wrong prune before their next update has lost
    the only copy. Printing each removed command is what makes it noticeable.
    """
    removed = []
    for event in managed_events:
        removed.extend(prune_event(data, event, warnings))
    return removed


def prune_event(data, event, warnings):
    """Prune retired bundle hooks under one event. Returns what it removed."""
    entries = event_hooks(data, event, warnings)
    if entries is None:
        return []
    removed = []
    changed = False
    kept_entries = []

    for entry in entries:
        if not isinstance(entry, dict):
            kept_entries.append(entry)
            continue
        entry_hooks = entry.get("hooks")
        if not isinstance(entry_hooks, list):
            kept_entries.append(entry)
            continue

        kept_hooks = []
        dropped = False
        for hook in entry_hooks:
            script = hook_script_path(hook)
            if (
                script.startswith(hooks_dir)
                and script not in bundle_commands
                and definitely_absent(script)
            ):
                dropped = True
                removed.append(f"{event}: {str(hook.get('command', '')).strip()}")
                continue
            kept_hooks.append(hook)

        # Nothing removed from this entry — leave it exactly as it arrived. An
        # entry that already had no hooks is not a change we made.
        if not dropped:
            kept_entries.append(entry)
            continue

        changed = True
        if not kept_hooks:
            continue  # the prune emptied it; drop the entry too
        entry = dict(entry)
        entry["hooks"] = kept_hooks
        kept_entries.append(entry)

    if changed:
        set_event_hooks(data, event, kept_entries)
    return removed


def set_auto_permission_mode(data, warnings):
    """Default new sessions to auto mode. True if `data` was changed.

    Auto mode is what makes Claude act on a request instead of stopping for
    permission at every step — the fleet default the onboarding runbook sets up.
    An operator who has already chosen a mode keeps it.
    """
    permissions = data.get("permissions", {})
    if not isinstance(permissions, dict):
        # A cosmetic preference must never veto the hook migrations above — the
        # operator whose settings.json has an odd shape is exactly the one who
        # needs the dangling-registration cleanup. Degrade just this step.
        warnings.append(
            f'  WARNING: "permissions" in {settings} is not an object, so auto '
            "mode was left unset. Cycle to it with Shift+Tab."
        )
        return False

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
    warnings = []
    # Name every removed registration. The backup that would undo a wrong prune
    # is overwritten by the next changing run, so this line is the operator's
    # only durable notice that something of theirs was deregistered.
    for gone in prune_missing_bundle_hooks(data, warnings):
        changes.append(f"  Removing: hook for a retired bundle script — {gone}")
    if register_adhd_hook(data, warnings):
        changes.append("  Registering: ADHD SessionStart hook")
    pm_added = register_pm_check_hooks(data, warnings)
    if pm_added:
        changes.append(
            "  Registering: pre-build PM check hooks (%s)" % ", ".join(pm_added)
        )
    if set_auto_permission_mode(data, warnings):
        changes.append("  Setting: auto as the default permission mode")

    if not changes:
        for line in warnings:
            print(line)
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

    for line in changes + warnings:
        print(line)


try:
    configure()
except Skip as exc:
    print("  WARNING: the ADHD SessionStart hook, the pre-build PM check hooks,")
    print(f"           and auto mode could not be set up: {exc}.")
    print("           Nothing was changed. Fix that file and re-run this installer,")
    print('           or say "/i-have-adhd" for ADHD mode and Shift+Tab for auto')
    print("           mode. The pre-build gate stays off until the file parses.")
except Exception as exc:  # never let this step break the install
    print(f"  WARNING: settings.json setup failed ({exc}).")
    print('           Nothing was changed. The skills are installed; say "/i-have-adhd"')
    print("           for ADHD mode and cycle to auto mode with Shift+Tab. The")
    print("           pre-build PM check hooks are not registered.")
PY
else
  echo "  Skipped: ADHD hook, pre-build PM check hooks, and auto mode setup"
  echo "           (python3 not found). Nothing will inject the ruleset, so say"
  echo '           "/i-have-adhd" per session and cycle to auto mode with'
  echo "           Shift+Tab. The pre-build gate will not run at all."
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
