# SPEC — Freshdesk Grammar Check → Slack

## Problem

Biz Support agents send customer-facing replies through Freshdesk. Typos and
grammar slips make replies look unprofessional. The team lead wants to be alerted
when a mistake goes out so it can be corrected and used as coaching signal.

## Business rules

- **What counts as a reply to check:** a Freshdesk conversation entry that is
  `incoming === false` (outbound) **and** `private === false` (a real reply to the
  customer, not an internal note). The ticket's original description (the
  customer's first message) is never checked.
- **Watermark:** each run only checks replies with `created_at` strictly after the
  newest reply seen on the previous run (persisted as `lastRunAt`). First run with
  no state looks back `LOOKBACK_HOURS` (default 24).
- **Dedupe:** a conversation id, once alerted, is never alerted again (persisted in
  `alerted[]`). This survives retries and overlapping runs.
- **Scope filters (optional):**
  - `FRESHDESK_GROUP_ID` — only tickets whose `group_id` matches.
  - `FRESHDESK_AGENT_IDS` — only replies whose author `user_id` is in the list.
- **Strictness** controls what the grammar model flags:
  - `errors` — objective spelling/grammar/punctuation only (default, lowest noise).
  - `clarity` — errors + awkward/unclear phrasing + off-tone wording.
  - `all` — errors + clarity + tone + capitalization + formatting.
- **Only flagged replies produce Slack messages.** Clean replies are silent.
- **Post-send only.** Freshdesk's API does not expose unsent drafts, so this cannot
  gate a reply before it's sent.

## Data model

No database. Two persisted artifacts:

- `data/state.json` (gitignored):
  - `lastRunAt: string | null` — ISO timestamp watermark.
  - `alerted: number[]` — conversation ids already alerted (capped at 5000, FIFO).

Transient in-memory types: `FreshdeskTicket`, `FreshdeskConversation`, `AgentReply`
(`freshdesk.ts`), `GrammarIssue` / `GrammarResult` (`grammar.ts`).

## Key workflow (one pass, `src/index.ts`)

1. Load + validate config (fails fast with a named-variable error if a secret is missing).
2. Load state; compute `since` = `lastRunAt` or `now − LOOKBACK_HOURS`.
3. `GET /tickets?updated_since={since}&order_by=updated_at&order_type=asc` (paginated
   via the `Link: rel="next"` header, capped at `MAX_TICKETS`).
4. Apply `FRESHDESK_GROUP_ID` filter in memory.
5. For each ticket: `GET /tickets/{id}/conversations` (paginated) → `selectAgentReplies`
   applies the outbound/public/watermark/agent-id/non-empty filters.
6. For each new reply not already alerted: call Claude, parse JSON issues.
7. If issues: log + (unless `--dry-run`) `POST chat.postMessage` to `SLACK_TARGET`;
   mark the conversation id alerted.
8. Persist `lastRunAt = newest reply seen` and the updated `alerted` set.
9. Exit 0 on success, exit 1 with a message on any unhandled error (so a scheduler
   surfaces failures in its log).

## Integrations

| System | Direction | Endpoint | Auth | Notes |
|--------|-----------|----------|------|-------|
| Freshdesk | read | `GET /api/v2/tickets`, `GET /api/v2/tickets/{id}/conversations` | HTTP Basic `base64(apiKey:X)` | Rate limits → 429 + `Retry-After`; client retries up to 5×. Pagination via `Link` header. |
| Anthropic | read/write | `POST /v1/messages` | `x-api-key` header, `anthropic-version: 2023-06-01` | Model from `ANTHROPIC_MODEL` (default `claude-haiku-4-5-20251001`). System prompt forces bare-JSON output. |
| Slack | write | `POST chat.postMessage` | `Authorization: Bearer <bot token>` (needs `chat:write`) | `channel` accepts a channel id **or** a user id (user id → DM). Block Kit message. |

### Provisioning checklist (engineers)

1. **Freshdesk API key** — issue/scope a key for the account. Basic-auth read access
   to tickets + conversations is sufficient. Store as `FRESHDESK_API_KEY`.
2. **Anthropic API key** — `ANTHROPIC_API_KEY`. Score 4 secret → **seal** in Railway.
3. **Slack app** — create an app in the Traba workspace with the `chat:write` bot
   scope, install it, and (for channel posts) invite the bot to the channel. Store
   the bot token as `SLACK_BOT_TOKEN`. Score 2–4 → seal.
4. **Network allowlist** — if this runs inside a proxied/sandboxed environment,
   allow outbound HTTPS to `*.freshdesk.com`, `api.anthropic.com`, and `slack.com`.
   (In the Prometheus web sandbox these are **not** currently allowlisted, which is
   why the Freshdesk/Anthropic/Slack calls cannot be exercised end-to-end there —
   run it locally or on Railway.)

## Known limitations

- **Post-send only** — cannot block a bad reply before it reaches the customer.
- **No verified live run yet** — unit tests cover the reply-selection and
  JSON-parsing logic; the three external API calls have not been exercised against
  live services from the build sandbox (network not allowlisted). First real run
  should be a `bun run dry-run` against production Freshdesk.
- **False positives** scale with `STRICTNESS`. Start at `errors`.
- **Grammar quality** depends on the model; Haiku is the cheap default and may miss
  subtle issues — bump `ANTHROPIC_MODEL` to a larger model if needed.
- **Long threads** cost more (one Claude call per new reply). `MAX_TICKETS` bounds a run.
- **`updated_since` granularity** — a ticket bumped by a non-reply event still gets
  its conversations scanned, but the watermark + dedupe prevent duplicate alerts.

## Promotion (Tier 3 → Tier 2)

When others want it: create a repo under `traba-ops`, move this directory there,
deploy to Railway as a scheduled/cron service, set the three secrets as Railway
Variables and seal them. No frontend or database needed. See `docs/pipeline.md`.
