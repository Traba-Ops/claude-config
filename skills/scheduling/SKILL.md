---
name: scheduling
description: |
  Set up a recurring or scheduled task — "every morning", "on a cron",
  "remind me daily", "run this report weekly", "keep checking X". Decides
  between a Claude routine (each run needs judgment) and a macOS LaunchAgent
  (deterministic code), and sets up whichever fits.
version: 1.0.0
---

# Scheduling Recurring Tasks

When the operator wants something to run on a schedule, pick the mechanism with
one question, then set it up for them.

## Pick: does each run need Claude to *think*?

**Yes — it needs judgment** (summarizing, drafting, deciding, reading natural
language, reacting to fuzzy or changing conditions):
→ **Claude routine.** A saved Claude Code config that runs autonomously on
Anthropic's cloud on a schedule. Create it with `/schedule` (e.g. `/schedule
daily PR review at 9am`). It runs even when the operator's laptop is closed, and
each run shows up as a session at claude.ai/code.

**No — it's the same deterministic steps every time** (a sync, a backup, a
`git pull`, generating a report from a script, pinging an API):
→ **macOS LaunchAgent.** A local job that runs as the operator while they're
logged in.

### Two things that override the simple pick

- **Cost.** A Claude routine **draws down the operator's Claude subscription
  usage exactly like a normal session does** — it is *not* free cloud compute —
  and there's a daily cap on routine runs per account. A LaunchAgent running a
  plain script (no Claude call) costs nothing. So for fixed, deterministic work,
  especially anything frequent, use a LaunchAgent.
- **Cadence & locality.** Routines can't run more often than **hourly** and run
  in the cloud (no access to the operator's local files — they clone a GitHub
  repo instead). LaunchAgents go down to **every minute** and can touch anything
  on the machine. So: sub-hourly, or needs local files/apps → LaunchAgent.

### Quick examples
| Request | Use | Why |
|---|---|---|
| "Each morning, draft my standup from my calendar + Slack" | Claude routine | needs judgment, low frequency, uses connectors |
| "Every hour, pull the latest Traba skills" | LaunchAgent | fixed code, free, local |
| "Every 5 min, sync this file / poll this API into a CSV" | LaunchAgent | fixed *and* sub-hourly |
| "Weekly, summarize merged PRs and open doc-update PRs" | Claude routine | judgment, repo-centric, weekly |

> `/loop` and in-session cron run only *while a session is open* — live,
> ephemeral repetition, not durable scheduling. For "set it and forget it," use a
> routine or a LaunchAgent.

## Set up a Claude routine

Requires a Pro / Max / Team / Enterprise plan with Claude Code on the web enabled.
Run `/schedule` and describe the task and cadence — e.g. `/schedule every weekday
at 8am, summarize yesterday's merged PRs`. Claude collects the prompt, repo(s),
connectors, and schedule, then saves it. Confirm the parsed run time with the
operator and give them the claude.ai/code URL where runs appear. Keep the cadence
low — every run spends subscription usage.

## Set up a LaunchAgent

1. **Write the script** the job runs (bash/python/node) with **absolute paths** —
   launchd runs with a minimal environment, so don't rely on the operator's shell
   PATH or aliases. Make it executable (`chmod +x`).
2. **Write the plist** to `~/Library/LaunchAgents/work.traba.TASK_NAME.plist`. Start
   from `launchagent.template.plist` in this skill. Key choices:
   - `StartCalendarInterval` for specific times (like cron); `StartInterval` for
     "every N seconds".
   - Set `StandardOutPath` / `StandardErrorPath` so there's a log to debug from.
3. **Load it:**
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/work.traba.TASK_NAME.plist
   # older macOS: launchctl load ~/Library/LaunchAgents/work.traba.TASK_NAME.plist
   ```
4. **Tell the operator** what you set up, when it runs, where the log is, and how
   to stop it.

**Change or remove it:**
```bash
launchctl bootout gui/$(id -u)/work.traba.TASK_NAME     # stop it
# edit the plist, then bootstrap again to reload
rm ~/Library/LaunchAgents/work.traba.TASK_NAME.plist    # delete entirely
```

**Gotchas:**
- Run the script directly first to confirm it works — a job that errors on
  schedule is invisible unless you set a log path.
- Absolute paths everywhere, in both the plist `ProgramArguments` and the script.
- If the Mac is asleep at the scheduled time, launchd runs the job when it next
  wakes; it doesn't fire once per missed slot.

## Always tell the operator what you chose

State which mechanism you used and why — e.g. "this runs the same steps every
time and touches local files, so I set it up as a local LaunchAgent; it costs
nothing and runs every hour" — so they understand it and can manage it later.
