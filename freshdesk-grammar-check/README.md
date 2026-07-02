# Freshdesk Grammar Check → Slack

Watches recent **agent replies in Freshdesk**, checks each for spelling/grammar
mistakes, and **pings you on Slack** when it finds any. Built for the Biz Support
team to catch typos in customer-facing replies after they go out.

> **Tier 3 prototype.** This currently lives in the `claude-config` repo on the
> `claude/freshdesk-grammar-slack-alert-s2wzhv` branch because that's where the
> session was scoped. When it graduates to a shared tool, it should move to its
> own repo under `traba-ops` (see [SPEC.md](SPEC.md) → *Promotion*).

## What it does

1. Every run, asks Freshdesk for tickets updated since the last run.
2. Pulls the **public, outbound agent replies** on those tickets (skips customer
   messages and private notes).
3. Sends each new reply to Claude for a grammar check.
4. For any reply with issues, posts a Slack message with the ticket link, the
   flagged text, and suggested corrections.
5. Remembers what it already flagged so you're never pinged twice for the same reply.

It only sees replies **after** they're sent — Freshdesk's API doesn't expose
drafts — so this is a safety net / coaching signal, not a pre-send gate.

## Who uses it

The Biz Support lead (and optionally the team, if you point alerts at a channel).
Runs unattended on a schedule.

## Setup

### 1. Fill in configuration

```bash
cp .env.example .env
```

Then edit `.env`. Every value is explained inline. The three secrets you need:

| Secret | Where it comes from | Who provisions |
|--------|--------------------|----------------|
| `FRESHDESK_API_KEY` | Freshdesk → Profile Settings → *Your API Key* | You or an admin |
| `ANTHROPIC_API_KEY` | Anthropic console | An engineer |
| `SLACK_BOT_TOKEN` | A Slack app with `chat:write` scope | An engineer |

**Where alerts go:** set `SLACK_TARGET` to your Slack **user ID** (starts with `U`)
to get a DM, or a **channel ID** (starts with `C`) to post to a channel.

**Scope (optional):** set `FRESHDESK_GROUP_ID` to your team's Freshdesk group so
it only checks your team's replies, and/or `FRESHDESK_AGENT_IDS` for specific agents.

**Strictness:** `STRICTNESS=errors` (default) flags only real mistakes. Bump to
`clarity` or `all` once you trust it — see `.env.example`.

### 2. Install and test

```bash
bun install
bun run test          # unit tests, no network
bun run dry-run       # one real pass, prints what it WOULD flag, sends no Slack
```

`dry-run` needs the Freshdesk + Anthropic keys set (it reads real tickets and
runs the grammar check) but never posts to Slack.

### 3. Go live

```bash
bun run start         # one pass, sends Slack alerts for anything flagged
```

Then schedule it — see [scheduling](#scheduling).

## Scheduling

This is a one-pass script, meant to be run on an interval by a scheduler.

- **On your Mac (simplest):** a macOS LaunchAgent running `bun run start` every
  15–30 min. Ask Claude: *"set up a LaunchAgent that runs `bun run start` in this
  folder every 20 minutes."* (See the `scheduling` skill.)
- **Shared / always-on:** deploy to Railway as a cron service. Move the repo to
  `traba-ops` first (see SPEC → Promotion), put the three secrets in Railway
  Variables, and **seal** `ANTHROPIC_API_KEY`, `FRESHDESK_API_KEY`, and
  `SLACK_BOT_TOKEN` (see the security guardrails).

State (what's been checked/alerted) lives in `data/state.json`, which is
gitignored. Deleting it makes the next run re-scan the last `LOOKBACK_HOURS`.

## Costs & safety

- Each new reply is one Claude call (Haiku by default — cheap). `MAX_TICKETS`
  caps how many tickets a single run scans.
- Secrets only ever come from environment variables — nothing is hardcoded, and
  `.env` is gitignored.

## For engineers

See [the provisioning checklist in SPEC.md](SPEC.md#provisioning-checklist-engineers)
for exactly what to set up (Freshdesk key scope, Slack app scopes, allowlisting).
